# -------------------------
# 1) Builder stage: install PHP dependencies via Composer
# -------------------------
FROM composer:2 AS builder

WORKDIR /app

# Copy only what’s needed for composer install
# COPY composer.json composer.lock ./
COPY composer.json ./

# Install PHP deps, optimize autoloader
RUN composer install --no-dev --optimize-autoloader

# -------------------------
# 2) Production stage: light PHP/Apache image
# -------------------------
FROM php:7.4-apache

# Install system libs & PHP extensions
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libonig-dev \
      libzip-dev \
      zip \
      unzip \
 && docker-php-ext-install \
      mbstring \
      pdo_mysql \
      mysqli \
      zip \
 && a2enmod rewrite \
 && rm -rf /var/lib/apt/lists/*

 # allow .htaccess files to work
RUN sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Enable and configure OPcache for faster PHP exec
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Copy app code
WORKDIR /var/www/html
COPY . .

# Copy optimized vendor directory from builder
COPY --from=builder /app/vendor ./vendor

# Ensure Apache runs as www-data and adjust perms
RUN chown -R www-data:www-data /var/www/html \
 && find /var/www/html -type f -exec chmod 644 {} \; \
 && find /var/www/html -type d -exec chmod 755 {} \;

# Expose HTTP port and launch Apache
EXPOSE 80
CMD ["apache2-foreground"]
