FROM php:8.3.33-fpm

# Install the requirements for laravel. Build dependencies are removed again,
# only the packages providing libraries the compiled extensions link against
# are kept. pdo_sqlite and opcache are part of the official image.
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends gosu sqlite3 \
        libfreetype-dev libicu-dev libjpeg62-turbo-dev libpng-dev libzip-dev zlib1g-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" bcmath exif gd intl pcntl pdo_mysql zip; \
    pecl install redis-6.3.0; \
    docker-php-ext-enable redis; \
    rm -rf /tmp/pear; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark gosu sqlite3 > /dev/null; \
    find /usr/local/lib/php/extensions -type f -name '*.so' -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | cut -d: -f1 \
        | sort -u \
        | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
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

# Set Workdir
WORKDIR /app

#Set EntryPoint
COPY --chmod=755 docker-laravel-entrypoint /usr/local/bin/
ENTRYPOINT [ "docker-laravel-entrypoint" ]
CMD ["php-fpm"]
