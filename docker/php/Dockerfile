FROM php:8.5-cli-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    unzip \
    libpq-dev \
    libmagickwand-dev \
    libicu-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install \
    pdo_pgsql \
    bcmath \
    intl \
    zip \
    && pecl install redis \
    && docker-php-ext-enable redis

COPY --from=composer:2.10.3 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

RUN usermod -u 1000 www-data

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
