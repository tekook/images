FROM php:8.0.18-fpm-alpine


# Install the requirements for laravel
RUN apk update && \
        apk add zlib-dev libzip-dev sqlite sqlite-dev \
        && apk add libpng-dev freetype-dev libjpeg-turbo-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath \
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        && docker-php-ext-install gd


# Set Workdir
WORKDIR /app

#Set EntryPoint
COPY docker-laravel-entrypoint /usr/local/bin/
ENTRYPOINT [ "docker-laravel-entrypoint" ]
CMD ["php-fpm"]
