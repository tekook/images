#!/usr/bin/env bash


while [ "$1" != "" ]; do
    case $1 in
        -p | --push )           PUSH_TO_REGISTRY=1
                                ;;
    esac
    shift
done

export PUBLISHER=tekook
export IMAGES=("laravel-fpm")
export PHP_VERSION=("7.3.12" "7.4.0")

for image in ${IMAGES[@]}; do
    dockerFile=./${image//-//}/Dockerfile
    imageName=${PUBLISHER}/${image}
    echo Building ${imageName} from ${dockerFile}
    for version in ${PHP_VERSION[@]}; do
        echo Building php-version: $version
        short_version=${version%.*}

        docker build . -f ${dockerFile} -t ${imageName} --build-arg PHP_VERSION=${version}

        docker tag ${imageName} ${imageName}:${version}
        docker tag ${imageName} ${imageName}:${short_version}


        if [ ! -z "$PUSH_TO_REGISTRY" ]
        then
            echo pushing: ${imageName}:${version} 
            docker push ${imageName}:${version}
            echo pushing: ${imageName}:${short_version} 
            docker push ${imageName}:${short_version}
        fi
    done
done


read -n1 -r -p "Press any key to continue..." key