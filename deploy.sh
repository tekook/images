#!/usr/bin/env bash

export PHP_VERSION=("7.3.12" "7.4.0")
export IMAGE=tekook/laravel-fpm

for version in ${PHP_VERSION[@]}; do
    echo Building php-version: $version
    short_version=${version%.*}

    docker build . -f ./laravel/fpm/Dockerfile -t ${IMAGE} --build-arg PHP_VERSION=${version}

    docker tag ${IMAGE} ${IMAGE}:${version}
    docker tag ${IMAGE} ${IMAGE}:${short_version}


    echo pushing: ${IMAGE}:${version} 
    docker push ${IMAGE}:${version}
    echo pushing: ${IMAGE}:${short_version} 
    docker push ${IMAGE}:${short_version}
done


read -n1 -r -p "Press any key to continue..." key