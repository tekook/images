FROM php:7.4.1-fpm


# Install the requirements for laravel
RUN apt-get update && \
        apt-get install -y --no-install-recommends libzip-dev zlib1g-dev sqlite3 libsqlite3-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Set Workdir
WORKDIR /app