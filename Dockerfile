# syntax=docker/dockerfile:1.7
ARG PHP_VERSION=8.4
ARG VARIANT=fpm

FROM php:${PHP_VERSION}-${VARIANT}-alpine AS base

COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
        bcmath \
        intl \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        redis \
        sockets \
        zip \
    && apk add --no-cache fcgi

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY rootfs/ /
# Writable socket directory for FPM_LISTEN=/run/php/fpm.sock setups (nginx in the same pod).
RUN mkdir -p /run/php && chown www-data:www-data /run/php

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_MEMORY_LIMIT=256M \
    FPM_LISTEN=9000 \
    FPM_SLOWLOG_TIMEOUT=0 \
    FPM_REQUEST_TERMINATE_TIMEOUT=60s \
    FPM_PM_MAX_REQUESTS=500 \
    FPM_REQUEST_TERMINATE_TIMEOUT=60s \
    FPM_PM_MAX_REQUESTS=500 \
    FPM_PM_MAX_SPARE_SERVERS=3 \
    FPM_PM_MIN_SPARE_SERVERS=1 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MAX_CHILDREN=10 \
    FPM_PM=dynamic \
    PHP_MAX_INPUT_VARS=1000 \
    PHP_DATE_TIMEZONE=UTC \
    PHP_MAX_EXECUTION_TIME=30 \
    PHP_POST_MAX_SIZE=32M \
    PHP_UPLOAD_MAX_FILESIZE=32M

WORKDIR /app

FROM base AS prod
USER www-data

FROM base AS dev
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    XDEBUG_MODE=off
RUN install-php-extensions xdebug \
    && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
