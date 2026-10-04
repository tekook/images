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
#   ./deploy.sh -- <args>         pass further arguments to "docker buildx bake",
#                                 e.g. --print
cd "$(dirname "$0")" || exit 1

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
        -l | --list )           docker buildx bake --progress quiet --list targets
                                exit $?
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

# TAG_PREFIX may also come from the environment, so always announce it
if [ ! -z "$TAG_PREFIX" ]; then
    if ! [[ "$TAG_PREFIX" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,99}$ ]]; then
        echo "Invalid tag prefix '$TAG_PREFIX' (allowed: letters, digits, '_', '.', '-'; max. 100 chars)" >&2
        exit 1
    fi
    echo "Tag prefix active: only ${TAG_PREFIX}-<php version>[-alpine] tags, no release tags" >&2
fi

if [ ! -z "$PUSH_TO_REGISTRY" ]; then
    BAKE_ARGS=(--push "${BAKE_ARGS[@]}")
else
    # --load only works for a single platform, so build the native one
    case $(uname -m) in
        x86_64)        platform="linux/amd64" ;;
        arm64|aarch64) platform="linux/arm64" ;;
        *)             platform="linux/$(uname -m)" ;;
    esac
    echo "Local build detected. Overriding platforms to native: $platform" >&2
    BAKE_ARGS=(--load --set "*.platform=${platform}" "${BAKE_ARGS[@]}")
fi

docker buildx bake --progress auto "${BAKE_ARGS[@]}" "${TARGETS[@]}"
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
