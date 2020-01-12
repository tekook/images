FROM php:7.4.0-fpm-alpine


# Install the requirements for laravel
RUN apk add --update --no-cache sqlite && \
    apk add --update --no-cache --virtual=.docker-php-global-dependancies \
        zlib-dev libzip-dev sqlite-dev && \
    docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath && \
    apk del .docker-php-global-dependancies && \
    rm -rf /var/cache/apk/* && \
    docker-php-source delete

# Install GD
RUN apk add --update --no-cache --virtual=.docker-php-gd-dependancies \
        libpng-dev freetype-dev libjpeg-turbo-dev  && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd && \
    apk del .docker-php-gd-dependancies && \
    rm -rf /var/cache/apk/* && \
    docker-php-source delete

# Set Workdir
WORKDIR /app