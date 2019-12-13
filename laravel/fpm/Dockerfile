ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-fpm


# Install the requirements for laravel
RUN apt-get update && \
        apt-get install -y --no-install-recommends zip unzip git libzip-dev zlib1g-dev sqlite3 libsqlite3-dev libpng-dev gnupg \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Set Workdir
WORKDIR /app