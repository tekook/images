FROM php:8.1.34-fpm-alpine

# Install the requirements for laravel. Build dependencies are removed again,
# only the shared libraries the compiled extensions link against are kept.
# pdo_sqlite and opcache are part of the official image. icu-data-full: all
# locales for intl (icu-libs alone only has English).
RUN set -eux; \
    apk add --no-cache fcgi icu-data-full sqlite su-exec; \
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

# php.ini-production as base; Laravel related overrides read the PHP_*
# variables below, which can be changed per container
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY laravel/fpm/conf/php.ini $PHP_INI_DIR/conf.d/zz-laravel.ini
ENV PHP_DISPLAY_ERRORS=Off \
    PHP_MEMORY_LIMIT=256M \
    PHP_MAX_EXECUTION_TIME=30 \
    PHP_UPLOAD_MAX_FILESIZE=64M \
    PHP_POST_MAX_SIZE=64M \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1

# pool sizing from the PHP_FPM_* variables below, ping/status paths for the
# healthcheck
COPY laravel/fpm/conf/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-laravel.conf
ENV PHP_FPM_PM=dynamic \
    PHP_FPM_PM_MAX_CHILDREN=10 \
    PHP_FPM_PM_START_SERVERS=3 \
    PHP_FPM_PM_MIN_SPARE_SERVERS=2 \
    PHP_FPM_PM_MAX_SPARE_SERVERS=5 \
    PHP_FPM_PM_MAX_REQUESTS=500

# Set Workdir
WORKDIR /app

#Set EntryPoint
COPY --chmod=755 docker-laravel-entrypoint /usr/local/bin/
COPY --chmod=755 docker-laravel-healthcheck /usr/local/bin/
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["docker-laravel-healthcheck"]
ENTRYPOINT [ "docker-laravel-entrypoint" ]
CMD ["php-fpm"]
