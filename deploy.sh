#!/usr/bin/env bash

export PUBLISHER=tekook
export IMAGES=("laravel-fpm")
export IMAGE_VERSION=1.0.0
export PHP_VERSION=("7.3.12" "7.4.0")

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
    esac
    shift
done

for image in ${IMAGES[@]}; do
    dockerFile=./${image//-//}/Dockerfile
    imageName=${PUBLISHER}/${image}
    echo Building ${imageName} from ${dockerFile}
    for version in ${PHP_VERSION[@]}; do
        echo Building php-version: $version
        short_version=${version%.*}

        if [ -z "$SKIP_BUILD" ]
        then
           docker build . -f ${dockerFile} -t ${imageName} --build-arg PHP_VERSION=${version}
        fi

        docker tag ${imageName} ${imageName}:${IMAGE_VERSION}_${version}
        docker tag ${imageName} ${imageName}:${IMAGE_VERSION}_${short_version}


        if [ ! -z "$PUSH_TO_REGISTRY" ]
        then
            echo pushing: ${imageName}:${IMAGE_VERSION}_${version} 
            docker push ${imageName}:${IMAGE_VERSION}_${version}
            echo pushing: ${imageName}:${IMAGE_VERSION}_${short_version} 
            docker push ${imageName}:${IMAGE_VERSION}_${short_version}
        fi
    done
    if [ ! -z "$PUSH_LATEST" ]
    then
        echo pushing: ${imageName}:latest
        docker push ${imageName}:latest
    fi
done


read -n1 -r -p "Press any key to continue..." key