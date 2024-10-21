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

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_MEMORY_LIMIT=256M

WORKDIR /app

FROM base AS prod
USER www-data

FROM base AS dev
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    XDEBUG_MODE=off
RUN install-php-extensions xdebug \
    && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
