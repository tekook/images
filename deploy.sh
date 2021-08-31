#!/usr/bin/env bash

export PUBLISHER=tekook
export IMAGES=("laravel-fpm")
export IMAGE_VERSION=1.0.0
export INDENT=0

while [ "$1" != "" ]; do
    case $1 in
        -p | --push )           PUSH_TO_REGISTRY=1
                                ;;
        -i | --images )         IMAGES=($2)
                                ;;
        --publisher )           PUBLISHER=$2
                                ;;
        --skip-build )          SKIP_BUILD=1
                                ;;
        --push-latest)          PUSH_LATEST=1
                                ;;
        --pause )               PAUSE_ON_END=1
                                ;;
    esac
    shift
done

function buildImage {
    local dockerFile=$1
    local imageName=$2
    
    if [ -z "$SKIP_BUILD" ]
    then
        echo Building ${dockerFile} as ${imageName}
        docker build . -q -f ${dockerFile} -t ${imageName}
    else
        echo Skipped building ${dockerFile} as ${imageName}
    fi
}

function tagAndPushImage {
    local imageName=$1
    local imageVersion=$2
    local suffixVersion=$3

    echo Tagging: ${imageName} with version: ${imageVersion}${suffixVersion}
    docker tag ${imageName} ${imageName}:${imageVersion}${suffixVersion}
    if [[ $? -ne 0 ]]; then return 1;fi;
    docker tag ${imageName} ${imageName}:${imageVersion%.*}${suffixVersion}
    if [[ $? -ne 0 ]]; then return 1;fi;
    if [ ! -z "$PUSH_TO_REGISTRY" ]
    then
        echo Pushing: ${imageName}:${imageVersion}${suffixVersion}
        docker push ${imageName}:${imageVersion}${suffixVersion}
        if [[ $? -ne 0 ]]; then return 1;fi;
        docker push ${imageName}:${imageVersion%.*}${suffixVersion}
        if [[ $? -ne 0 ]]; then return 1;fi;
    else
        echo Skipped pushing: ${imageName}
    fi
    return 0
}

function pushLasted {
    local imageName=$1
    if [ ! -z "$PUSH_LATEST" ]
    then
        echo Pushing: ${imageName}:latest
        docker push ${imageName}:latest
    else
        echo Skipped pushing: ${imageName}:latest
    fi
}

function handleDockerfile {
    local dockerFile=$1
    local imageName=$2
    local imageVersion=$3
    local subVersion=$4
    if [ ! -z "$subVersion" ]
    then
        subVersion=-$subVersion
    fi;

    echo Using Dockerfile: ${dockerFile} as $imageName:$imageVersion$subVersion

    buildImage ${dockerFile} ${imageName}
    if [ $? -eq 0 ]
    then
        tagAndPushImage ${imageName} ${imageVersion} ${subVersion}
        if [[ $? -ne 0 ]]
        then
            echo
            echo "#######################"
            echo
            echo "Push or tag failed"
            echo
            echo "#######################"
            echo
        fi
    else
        echo
        echo "#######################"
        echo
        echo "Build failed cannot push or tag"
        echo
        echo "#######################"
        echo
    fi;
}

function handleImageSubFoldersRecursive {
    local folder=$1
    local imageName=$2
    local imageVersion=$3
    local subVersion=$4


    echo Handling sub-images in ${folder} with subVersion \"${subVersion}\"
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
    pushLasted ${imageName}
    echo
    echo "#####################"
    echo
}



for image in ${IMAGES[@]}; do
    handleImage ${image}
done

if [ ! -z "$PAUSE_ON_END" ]
then
    read -n1 -r -p "Press any key to continue..." key
fi