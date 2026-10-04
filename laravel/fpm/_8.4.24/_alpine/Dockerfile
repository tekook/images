FROM php:8.4.24-fpm-alpine

# Install the requirements for laravel. Build dependencies are removed again,
# only the shared libraries the compiled extensions link against are kept.
# pdo_sqlite and opcache are part of the official image. icu-data-full: all
# locales for intl (icu-libs alone only has English).
RUN set -eux; \
    apk add --no-cache icu-data-full sqlite su-exec; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS pax-utils \
        freetype-dev icu-dev libjpeg-turbo-dev libpng-dev libzip-dev zlib-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" bcmath exif gd intl pcntl pdo_mysql zip; \
    pecl install redis-6.3.0; \
    docker-php-ext-enable redis; \
    rm -rf /tmp/pear; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .laravel-rundeps $runDeps; \
    apk del --no-network .build-deps; \
    for ext in bcmath exif gd intl pcntl pdo_mysql pdo_sqlite redis zip "Zend OPcache"; do \
        php -m | grep -qixF "$ext"; \
    done

# Set Workdir
WORKDIR /app

#Set EntryPoint
COPY --chmod=755 docker-laravel-entrypoint /usr/local/bin/
ENTRYPOINT [ "docker-laravel-entrypoint" ]
CMD ["php-fpm"]
