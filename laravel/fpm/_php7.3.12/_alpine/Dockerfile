FROM php:7.3.12-fpm-alpine


# Install the requirements for laravel
RUN apk update && \
        apk add zlib-dev libzip-dev sqlite sqlite-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Set Workdir
WORKDIR /app