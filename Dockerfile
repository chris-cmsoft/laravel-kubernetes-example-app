# We need a reusable list of PHP extensions to install for all the targets
ARG PHP_EXTS="bcmath ctype fileinfo mbstring pdo pdo_mysql dom intl"

# We need a reusable list of PHP extensions installable through pecl for all the targets
ARG PHP_PECL_EXTS="redis"

FROM php:8.0-alpine as code_base

# We need to declare that we want to use the args in this build step
ARG PHP_EXTS
ARG PHP_PECL_EXTS

WORKDIR /opt/apps/laravel-in-kubernetes

RUN wget https://raw.githubusercontent.com/composer/getcomposer.org/76a7060ccb93902cd7576b67264ad91c8a2700e2/web/installer -O - -q | php -- --quiet \
    && mv composer.phar /usr/local/bin/composer \
    && mkdir -p /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes/bin \
    && addgroup -S composer \
    && adduser -S composer -G composer \
    && chown -R composer /opt/apps/laravel-in-kubernetes \
    && apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} openssl ca-certificates libxml2-dev oniguruma-dev icu-dev \
    && docker-php-ext-install -j$(nproc) ${PHP_EXTS} \
    && pecl install ${PHP_PECL_EXTS} \
    && docker-php-ext-enable ${PHP_PECL_EXTS} \
    && apk del build-dependencies

# Next we want to switch over to the composer user before running installs.
USER composer

# Copy in our dependency files
COPY --chown=composer composer.json composer.lock ./

# Install all the dependencies without running any installation scripts.
# The reason we skip scripts, is the code base hasn't been copied in yet and script will likely fail,
# as artisan isn't in yet.
# This also helps us to cache previous runs and layers.
# As long as comoser.json and composer.lock doesn't change the install will be cached.
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# Copy in our actual source code so we can run the installation scripts we need
COPY --chown=composer . .

# Install all the dependencies running installation scripts as well
RUN composer install --no-dev --prefer-dist

FROM php:8.0-alpine as cli

# We need to declare that we want to use the args in this build step
ARG PHP_EXTS
ARG PHP_PECL_EXTS

WORKDIR /opt/apps/laravel-in-kubernetes

# We need to install some requirements into our image, used to compile our PHP extensions, as well as install all the extensions themselves.
# You can see a list of required extensions here: https://laravel.com/docs/8.x/deployment#server-requirements
RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} openssl ca-certificates libxml2-dev oniguruma-dev && \
    docker-php-ext-install -j$(nproc) ${PHP_EXTS} && \
    pecl install ${PHP_PECL_EXTS} && \
    docker-php-ext-enable ${PHP_PECL_EXTS} && \
    apk del build-dependencies

# Next we have to copy in our code base from our initial build which we installed in the previous stage
COPY --from=code_base /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes

FROM php:8.0-fpm-alpine as fpm_server

# We need to declare that we want to use the args in this build step
ARG PHP_EXTS
ARG PHP_PECL_EXTS

WORKDIR /opt/apps/laravel-in-kubernetes

# We need to install some requirements into our image, used to compile our PHP extensions, as well as install all the extensions themselves.
# You can see a list of required extensions here: https://laravel.com/docs/8.x/deployment#server-requirements
RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} openssl ca-certificates libxml2-dev oniguruma-dev && \
    docker-php-ext-install -j$(nproc) ${PHP_EXTS} && \
    pecl install ${PHP_PECL_EXTS} && \
    docker-php-ext-enable ${PHP_PECL_EXTS} && \
    apk del build-dependencies

# Next we have to copy in our code base from our initial build which we installed in the previous stage
COPY --from=code_base /opt/apps/laravel-in-kubernetes /opt/apps/laravel-in-kubernetes

# Next we want to cache the event, routes, and views so we don't try to write them when we are in Kubernetes
RUN php artisan event:cache && \
    php artisan route:cache && \
    php artisan view:cache

FROM nginx:1.20-alpine as web_server

# Set the working directory, same as previously
WORKDIR /opt/apps/laravel-in-kubernetes

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy in ONLY the public directory of our project.
# This is where all the static assets will live, which nginx will serve for us.
# Any PHP requests will be passed down to FPM
COPY --from=code_base /opt/apps/laravel-in-kubernetes/public /opt/apps/laravel-in-kubernetes/public

FROM cli as cron

# Set the working directory, same as previously
WORKDIR /opt/apps/laravel-in-kubernetes

# We want to create a laravel.cron file with Laravel cron settings, which we can import into crontab,
# and run crond as the primary command in the forground
RUN touch laravel.cron && \
    echo "* * * * * cd /opt/apps/laravel-in-kubernetes && php artisan schedule:run" >> laravel.cron && \
    crontab laravel.cron

CMD ["crond", "-l", "2", "-f"]

FROM code_base as tests

# Set the working directory, same as previously
WORKDIR /opt/apps/laravel-in-kubernetes

# We want to create a laravel.cron file with Laravel cron settings, which we can import into crontab,
# and run crond as the primary command in the forground
RUN composer install --prefer-dist

FROM cli
