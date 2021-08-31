FROM php:8.0.10-fpm-alpine
RUN apk add --update --no-cache zlib-dev libzip-dev sqlite sqlite-dev libpng-dev freetype-dev libjpeg-turbo-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath \
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        && docker-php-ext-install gd