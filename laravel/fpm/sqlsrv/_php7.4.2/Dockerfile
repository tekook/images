FROM php:7.4.2-fpm


# Install the requirements for laravel
RUN apt-get update && \
        apt-get install -y --no-install-recommends zip unzip git libzip-dev zlib1g-dev sqlite3 libsqlite3-dev libpng-dev gnupg libonig-dev \
        && docker-php-ext-install pdo pdo_mysql zip pdo_sqlite bcmath

# Install GD
RUN apt-get update && \
        apt-get install -y --no-install-recommends libpng-dev libfreetype6-dev libjpeg62-turbo-dev \
        && docker-php-ext-configure gd --with-freetype=/usr/include --with-jpeg=/usr/include \
        && docker-php-ext-install gd

# Set Workdir
WORKDIR /app

# Install SQLSRV Requirements

# Microsoft SQL Server Prerequisites
ENV ACCEPT_EULA=Y
RUN apt-get update \
    && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/10/prod.list \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get install -y --no-install-recommends \
        locales \
        apt-transport-https \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        unixodbc-dev \
        msodbcsql17

RUN docker-php-ext-install mbstring pdo pdo_mysql \
    && pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv
