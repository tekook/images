FROM php:7.3.12-fpm-alpine


# Install the requirements for laravel
RUN apk add --update --no-cache sqlite && \
    apk add --update --no-cache --virtual=.docker-php-global-dependancies \
        zlib-dev libzip-dev sqlite-dev && \
    docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath && \
    apk del .docker-php-global-dependancies && \
    rm -rf /var/cache/apk/* && \
    docker-php-source delete

# Set Workdir
WORKDIR /app