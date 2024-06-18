FROM php:8.1.29-fpm


# Install the requirements for laravel
RUN apt-get update && \
        apt-get install -y --no-install-recommends libzip-dev zlib1g-dev sqlite3 libsqlite3-dev \
        && apt-get install -y --no-install-recommends libpng-dev libfreetype6-dev libjpeg62-turbo-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath \
        && docker-php-ext-configure gd --with-freetype=/usr/include --with-jpeg=/usr/include \
        && docker-php-ext-install gd

# Set Workdir
WORKDIR /app

#Set EntryPoint
COPY docker-laravel-entrypoint /usr/local/bin/
ENTRYPOINT [ "docker-laravel-entrypoint" ]
CMD ["php-fpm"]
