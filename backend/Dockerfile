FROM php:8.4-fpm-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends nginx libpq-dev libzip-dev libonig-dev libxml2-dev unzip git \
    && docker-php-ext-install pdo_pgsql mbstring zip pcntl opcache dom xml \
    && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist
COPY . .
RUN composer dump-autoload --optimize --no-dev && chown -R www-data:www-data storage bootstrap/cache
COPY deploy/nginx.conf /etc/nginx/nginx.conf.template
RUN chmod +x deploy/start.sh
CMD ["sh", "deploy/start.sh"]
