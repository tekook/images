#!/usr/bin/env bash

export PUBLISHER=tekook
export IMAGES=("laravel-fpm")
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
        --no-pause )            NO_PAUSE_ON_END=1
                                ;;
    esac
    shift
done

function buildImage {
    local dockerFile=$1
    local imageName=$2

    if [ -z "$SKIP_BUILD" ]
    then
        docker build . -f ${dockerFile} -t ${imageName}
    fi
}

function tagImage {
    local imageName=$1
    local imageVersion=$2
    local suffixVersion=$3
    if [ -z ${suffixVersion} ]
    then
        suffixVersion=_$suffixVersion
    fi;

    docker tag ${imageName} ${imageName}:${imageVersion}${suffixVersion}
    docker tag ${imageName} ${imageName}:${imageVersion%.*}${suffixVersion}

}



for image in ${IMAGES[@]}; do
    folder=./${image//-//}
    imageName=${PUBLISHER}/${image}
    imageVersion=$(cat $folder/VERSION)
    imageVersionShort=${imageVersion%.*}

    echo Image: ${image} (${imageVersion})


    for dockerFile in ${folder}/*.Dockerfile; do
        echo Using Dockerfile: ${dockerFile}
        repl=$folder/
        version=${dockerFile/$repl}
        version=${version/.Dockerfile}
        echo PHP-Version: ${version}

        buildImage ${dockerFile} ${imageName}

        docker tag ${imageName} ${imageName}:${imageVersion}_${version}
        docker tag ${imageName} ${imageName}:${imageVersionShort}_${version}

        if [ ! -z "$PUSH_TO_REGISTRY" ]
        then
            echo pushing: ${imageName}:${imageVersion}_${version} 
            docker push ${imageName}:${imageVersion}_${version}
            echo pushing: ${imageName}:${imageVersionShort}_${version}
            docker push ${imageName}:${imageVersionShort}_${version}
        fi

    done;

    if [ ! -z "$PUSH_LATEST" ]
    then
        echo pushing: ${imageName}:latest
        docker push ${imageName}:latest
    fi
done

if [ ! -z "$NO_PAUSE_ON_END" ]
then
    read -n1 -r -p "Press any key to continue..." key
fi