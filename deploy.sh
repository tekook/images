#!/usr/bin/env bash
# Builds the images defined in docker-bake.hcl.
#
#   ./deploy.sh                   build for the native platform, load into docker
#   ./deploy.sh -p                build for all platforms and push
#   ./deploy.sh --publisher foo   tag as foo/<image> instead of tekook/<image>
#                                 (may include a registry: registry.example.com/foo)
#   ./deploy.sh --tag-prefix dev-2.0-abc123
#                                 only tag <prefix>-<php version>[-alpine], no
#                                 release tags (test/dev builds)
#   ./deploy.sh -i <target>       only build the given bake target or group
#   ./deploy.sh -l                list the available targets and groups
#   ./deploy.sh --setup-qemu      register QEMU emulation for the non-native
#                                 platforms (runs a privileged container; not
#                                 persistent across host reboots), then continue
#   ./deploy.sh -- <args>         pass further arguments to "docker buildx bake",
#                                 e.g. --print
cd "$(dirname "$0")" || exit 1

# Build environment. deploy.sh always builds with its own builder running a
# pinned BuildKit version, independent of the builder selected globally via
# "docker buildx use" and of the Docker Engine's bundled BuildKit.
BUILDER_NAME=tekook-images
BUILDKIT_IMAGE=moby/buildkit:v0.33.1
BINFMT_IMAGE=tonistiigi/binfmt:qemu-v10.2.3
# bake --list needs 0.20.0
MIN_BUILDX_VERSION=0.20.0

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

native_platform() {
    case $(uname -m) in
        x86_64)        echo "linux/amd64" ;;
        arm64|aarch64) echo "linux/arm64" ;;
        *)             echo "linux/$(uname -m)" ;;
    esac
}

check_buildx_version() {
    local version
    version=$(docker buildx version 2>/dev/null | awk '{print $2}' | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    [ -n "$version" ] || fail "docker buildx is not available"
    if [ "$(printf '%s\n%s\n' "$MIN_BUILDX_VERSION" "$version" | sort -V | head -n1)" != "$MIN_BUILDX_VERSION" ]; then
        fail "docker buildx $version is too old, $MIN_BUILDX_VERSION or newer is required"
    fi
}

# create the builder if missing; refuse one that runs something else
ensure_builder() {
    local info
    if info=$(docker buildx inspect "$BUILDER_NAME" 2>/dev/null); then
        if ! grep -qE '^Driver: +docker-container$' <<< "$info" \
            || ! grep -qF "image=\"${BUILDKIT_IMAGE}\"" <<< "$info"; then
            fail "builder '$BUILDER_NAME' exists, but is not a docker-container builder running $BUILDKIT_IMAGE.
       Remove it with 'docker buildx rm $BUILDER_NAME', deploy.sh creates it again."
        fi
    else
        echo "Creating builder '$BUILDER_NAME' ($BUILDKIT_IMAGE)" >&2
        docker buildx create --name "$BUILDER_NAME" --driver docker-container \
            --driver-opt "image=${BUILDKIT_IMAGE}" >/dev/null \
            || fail "could not create builder '$BUILDER_NAME'"
    fi
}

# platforms the bake definition builds when pushing
required_platforms() {
    docker buildx bake --progress quiet --print "${TARGETS[@]}" 2>/dev/null \
        | grep -oE '"linux/[^"]+"' | tr -d '"' | sort -u
}

# fail if the builder can't build every platform needed for the push
check_platforms() {
    local available missing=() p
    available=$(docker buildx inspect --bootstrap "$BUILDER_NAME" 2>/dev/null \
        | grep '^Platforms:' | sed -E 's/^Platforms: *//; s/\*//g; s/, */\n/g')
    for p in $(required_platforms); do
        grep -qxF "$p" <<< "$available" || missing+=("$p")
    done
    if [ ${#missing[@]} -ne 0 ]; then
        fail "builder '$BUILDER_NAME' can't build: ${missing[*]}
       Register QEMU emulation with './deploy.sh --setup-qemu' (privileged container)."
    fi
}

# register QEMU binfmt handlers for every required non-native architecture
setup_qemu() {
    local native archs=() list p
    native=$(native_platform)
    for p in $(required_platforms); do
        [ "$p" = "$native" ] && continue
        p=${p#linux/}
        archs+=("${p%%/*}")
    done
    if [ ${#archs[@]} -eq 0 ]; then
        echo "No emulation needed, all platforms are native" >&2
        return
    fi
    list=$(printf '%s\n' "${archs[@]}" | sort -u | paste -sd, -)
    echo "Registering QEMU emulation for: $list ($BINFMT_IMAGE, privileged)" >&2
    docker run --privileged --rm "$BINFMT_IMAGE" --install "$list" >/dev/null \
        || fail "could not register QEMU emulation"
    # buildkitd detects the available emulators when it starts
    docker buildx stop "$BUILDER_NAME" >/dev/null 2>&1
}

BAKE_ARGS=()
TARGETS=()
while [ "$1" != "" ]; do
    case $1 in
        -p | --push )           PUSH_TO_REGISTRY=1
                                ;;
        -i | --images )         TARGETS+=($2)
                                shift
                                ;;
        --publisher )           export PUBLISHER=$2
                                shift
                                ;;
        --tag-prefix )          export TAG_PREFIX=$2
                                shift
                                ;;
        --push-latest)          echo "Support for pushing latest has been dropped! Aborting."
                                exit 1
                                ;;
        --pause )               PAUSE_ON_END=1
                                ;;
        -l | --list )           LIST_TARGETS=1
                                ;;
        --setup-qemu )          SETUP_QEMU=1
                                ;;
        -- )                    shift
                                BAKE_ARGS+=("$@")
                                break
                                ;;
        * )                     echo "Unknown option: $1" >&2
                                exit 1
                                ;;
    esac
    shift
done

check_buildx_version

if [ ! -z "$LIST_TARGETS" ]; then
    docker buildx bake --progress quiet --list targets
    exit $?
fi

# TAG_PREFIX may also come from the environment, so always announce it
if [ ! -z "$TAG_PREFIX" ]; then
    if ! [[ "$TAG_PREFIX" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,99}$ ]]; then
        fail "invalid tag prefix '$TAG_PREFIX' (allowed: letters, digits, '_', '.', '-'; max. 100 chars)"
    fi
    echo "Tag prefix active: only ${TAG_PREFIX}-<php version>[-alpine] tags, no release tags" >&2
fi

ensure_builder

if [ ! -z "$SETUP_QEMU" ]; then
    setup_qemu
fi

if [ ! -z "$PUSH_TO_REGISTRY" ]; then
    check_platforms
    BAKE_ARGS=(--push "${BAKE_ARGS[@]}")
else
    # --load only works for a single platform, so build the native one
    platform=$(native_platform)
    echo "Local build detected. Overriding platforms to native: $platform" >&2
    BAKE_ARGS=(--load --set "*.platform=${platform}" "${BAKE_ARGS[@]}")
fi

docker buildx bake --builder "$BUILDER_NAME" --progress auto "${BAKE_ARGS[@]}" "${TARGETS[@]}"
status=$?

if [ $status -ne 0 ]; then
    echo "#######################"
    echo "Build failed"
    echo "#######################"
fi

if [ ! -z "$PAUSE_ON_END" ]; then
    read -n1 -r -p "Press any key to continue..." key
fi

exit $status
