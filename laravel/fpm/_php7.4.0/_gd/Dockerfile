FROM php:7.4.0-fpm


# Install the requirements for laravel
RUN apt-get update && \
        apt-get install -y --no-install-recommends libzip-dev zlib1g-dev sqlite3 libsqlite3-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Install GD

RUN apt-get update \
        && apt-get install -y --no-install-recommends libpng-dev libfreetype6-dev libjpeg62-turbo-dev \
        && docker-php-ext-configure gd --with-freetype=/usr/include --with-jpeg=/usr/include \
        && docker-php-ext-install gd

# Set Workdir
WORKDIR /app