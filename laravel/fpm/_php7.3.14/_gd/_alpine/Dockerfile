FROM php:7.3.14-fpm-alpine


# Install the requirements for laravel
RUN apk update && \
        apk add zlib-dev libzip-dev sqlite sqlite-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Install GD
RUN apk update && \
        apk add libpng-dev freetype-dev libjpeg-turbo-dev \
        && docker-php-ext-configure gd --with-freetype-dir=/usr/include --with-jpeg-dir=/usr/include \
        && docker-php-ext-install gd

# Set Workdir
WORKDIR /app