#!/bin/sh
set -eu
php artisan config:cache
php artisan route:cache
php artisan view:cache
case "${SERVICE_ROLE:-api}" in
  worker) exec php artisan queue:work redis --sleep=3 --tries=3 --timeout=60 --max-time=3600 ;;
  scheduler) exec php artisan schedule:work ;;
  api)
    sed "s/__PORT__/${PORT:-8080}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
    php-fpm -D
    exec nginx -g 'daemon off;'
    ;;
  *) echo 'Unknown SERVICE_ROLE' >&2; exit 1 ;;
esac
