#!/usr/bin/env bash

export PUBLISHER=tekook
export IMAGES=("laravel-fpm" "laravel-fpm-sqlsrv")
export IMAGE_VERSION=1.0.0

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
    if [ ! -z "${suffixVersion}" ]
    then
        suffixVersion="_${suffixVersion}"

    fi;
    echo Tagging: ${imageName} with version: ${imageVersion}${suffixVersion}
    docker tag ${imageName} ${imageName}:${imageVersion}${suffixVersion}
    docker tag ${imageName} ${imageName}:${imageVersion%.*}${suffixVersion}

    if [ ! -z "$PUSH_TO_REGISTRY" ]
    then
        echo Pushing: ${imageName}:${imageVersion}${suffixVersion}
        docker push ${imageName}:${imageVersion}${suffixVersion}
        docker push ${imageName}:${imageVersion%.*}${suffixVersion}
    else
        echo Skipped pushing: ${imageName}
    fi

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
    local folder=$2
    local imageName=$3
    local imageVersion=$4

    echo Using Dockerfile: ${dockerFile}
    local repl=$folder/
    local version=${dockerFile/$repl}
    version=${version/.Dockerfile}
    echo PHP-Version: ${version}

    buildImage ${dockerFile} ${imageName}
    tagAndPushImage ${imageName} ${imageVersion} ${version}
}

function handleImage {
    local image=$1
    local folder=./${image//-//}
    local imageName=${PUBLISHER}/${image}
    local imageVersion=$(cat $folder/VERSION)
    local imageVersionShort=${imageVersion%.*}

    echo Image: ${image} v${imageVersion}

    local dockerFile=${folder}/Dockerfile
    if [ -f "${dockerFile}" ]
    then
        handleDockerfile ${dockerFile} ${folder} ${imageName} ${imageVersion}
    fi

    for dockerFile in ${folder}/*.Dockerfile; do
        handleDockerfile ${dockerFile} ${folder} ${imageName} ${imageVersion}
    done;
    pushLasted ${imageName}
}



for image in ${IMAGES[@]}; do
    handleImage ${image}
done

if [ ! -z "$PAUSE_ON_END" ]
then
    read -n1 -r -p "Press any key to continue..." key
fi