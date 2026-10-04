#!/usr/bin/env bash

export PUBLISHER=tekook
export IMAGES=("laravel-fpm")
export PLATFORMS="linux/amd64,linux/arm64"
FAILED_BUILDS=()

while [ "$1" != "" ]; do
    case $1 in
        -p | --push )           PUSH_TO_REGISTRY=1
                                ;;
        -i | --images )         IMAGES=($2)
                                ;;
        --publisher )           PUBLISHER=$2
                                ;;
        --push-latest)          PUSH_LATEST=1
                                ;;
        --pause )               PAUSE_ON_END=1
                                ;;
    esac
    shift
done
if [ ! -z "$PUSH_LATEST" ]
then
    echo "Support for pushing latest has been dropped! Aborting."
    exit 1
fi

function buildImage {
    local dockerFile=$1
    local imageName=$2
    local tags=$3
    
    # Determine which platforms to build
    local targetPlatforms=$PLATFORMS
    local buildAction="--load"

    if [ ! -z "$PUSH_TO_REGISTRY" ]; then
        buildAction="--push"
    else
        # If not pushing, we MUST build only for the local architecture to use --load
        # Map uname -m to docker platform naming
        local arch=$(uname -m)
        case $arch in
            x86_64)  targetPlatforms="linux/amd64" ;;
            arm64|aarch64) targetPlatforms="linux/arm64" ;;
            *)       targetPlatforms="linux/$arch" ;;
        esac
        echo "Local build detected. Overriding platforms to native: $targetPlatforms"
    fi
        
    local tagArgs=""
    for tag in $tags; do
        tagArgs="$tagArgs -t $tag"
    done

    echo "-------------------------------------------------------"
    echo " Building: $imageName"
    echo " File:     $dockerFile"
    echo " Platform: $targetPlatforms"
    echo " Tags:     $tags"
    echo "-------------------------------------------------------"

    docker buildx build \
        -f "${dockerFile}" \
        --platform "${targetPlatforms}" \
        ${tagArgs} \
        ${buildAction} \
        --pull \
        --progress auto \
        .
    local status=$?
    echo
    return $status
}

function handleDockerfile {
    local dockerFile=$1
    local imageName=$2
    local imageVersion=$3
    local subVersion=$4
    local suffix=""

    if [ ! -z "$subVersion" ]; then
        suffix=-$subVersion
    fi

    # Prepare all tags for this specific build:
    # full (1.1.0-x), minor (1.1-x) and major (1-x) image version, plus the
    # bare sub version (x). Duplicates are skipped, e.g. VERSION=1.1 yields no
    # separate minor tag.
    local majorVersion=${imageVersion%%.*}
    local minorVersion=$(cut -d. -f1,2 <<< "${imageVersion}")

    local fullTag="${imageName}:${imageVersion}${suffix}"
    local allTags="$fullTag"
    if [ "$minorVersion" != "$imageVersion" ]; then
        allTags="$allTags ${imageName}:${minorVersion}${suffix}"
    fi
    if [ "$majorVersion" != "$minorVersion" ]; then
        allTags="$allTags ${imageName}:${majorVersion}${suffix}"
    fi
    if [ ! -z "$subVersion" ]; then
        allTags="$allTags ${imageName}:${subVersion}"
    fi

    echo "Using Dockerfile: ${dockerFile} with tags: ${allTags}"

    if ! buildImage "${dockerFile}" "${imageName}" "${allTags}"; then
        echo "#######################"
        echo "Buildx failed"
        echo "#######################"
        FAILED_BUILDS+=("${fullTag} (${dockerFile})")
    fi
}

function handleImageSubFoldersRecursive {
    local folder=$1
    local imageName=$2
    local imageVersion=$3
    local subVersion=$4

    echo
    echo Handling sub-images in ${folder} with subVersion \"${subVersion}\"
    echo
    # Handle sub-images in "_*/" Folders

    local subImage
    local version
    local dockerFile
    for subImage in ${folder}/_*; do
        if [[ -d "${subImage}" && ! -L "${subImage}" ]]
        then
            version=${subImage##*/}
            version=${version:1}
            if [ ! -z "${subVersion}" ]
            then
                version=${subVersion}-${version}
            fi;
            echo $subImage -- $version
            handleImageSubFoldersRecursive ${subImage} ${imageName} ${imageVersion} ${version}

            dockerFile=$subImage/Dockerfile
            if [ -f "$dockerFile" ]
            then
                handleDockerfile $dockerFile $imageName $imageVersion $version
            fi;
        fi
    done;
}

function handleImage {
    local image=$1
    local folder=./${image//-//}
    local imageName=${PUBLISHER}/${image}
    local imageVersion=$(cat $folder/VERSION || echo "0.0")

    echo
    echo "#####################"
    echo
    echo Image: ${image} v${imageVersion}

    handleImageSubFoldersRecursive ${folder} ${imageName} ${imageVersion}

    echo
    echo "#####################"
    echo
    # Handle "Dockerfile" of Main Image
    
    local dockerFile=${folder}/Dockerfile
    if [ -f "${dockerFile}" ]
    then
        handleDockerfile ${dockerFile} ${imageName} ${imageVersion}
    else
        echo No Main Dockerfile found, skipping.
    fi
    echo
    echo "#####################"
    echo
}



for image in ${IMAGES[@]}; do
    handleImage ${image}
done

if [ ${#FAILED_BUILDS[@]} -ne 0 ]
then
    echo "#######################"
    echo "${#FAILED_BUILDS[@]} build(s) failed:"
    printf ' - %s\n' "${FAILED_BUILDS[@]}"
    echo "#######################"
fi

if [ ! -z "$PAUSE_ON_END" ]
then
    read -n1 -r -p "Press any key to continue..." key
fi

[ ${#FAILED_BUILDS[@]} -eq 0 ]