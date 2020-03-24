FROM php:7.4.2-fpm-alpine


# Install the requirements for laravel
RUN apk update && \
        apk add zlib-dev libzip-dev sqlite sqlite-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Install GD
RUN apk update && apk add libpng-dev freetype-dev libjpeg-turbo-dev \
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        && docker-php-ext-install gd


# Set Workdir
WORKDIR /app