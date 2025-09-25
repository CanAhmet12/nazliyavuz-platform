FROM php:8.3-cli

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libonig-dev \
    libzip-dev \
    zip \
    unzip \
&& docker-php-ext-configure mbstring \
&& docker-php-ext-install pdo pdo_mysql mbstring zip

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

COPY composer.json composer.lock ./
RUN composer install --optimize-autoloader --no-dev --no-scripts --ignore-platform-reqs

COPY . .

RUN php artisan config:clear || true \
&& php artisan cache:clear || true \
&& php artisan route:clear || true \
&& php artisan view:clear || true \
&& rm -rf bootstrap/cache/*

EXPOSE 8000
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]