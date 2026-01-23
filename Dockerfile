# Build arguments for versioning
ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-alpine

# Re-declare ARG after FROM to use it in labels
ARG PHP_VERSION

LABEL maintainer="Abdelilah EZZOUINI <abdelilah.ezzouini@gmail.com>"
LABEL description="Optimized PHP Laravel Base Image for Multi-Project Use"
LABEL php.version="${PHP_VERSION}"

# ==========================================
# ENVIRONMENT VARIABLES
# ==========================================
ENV COMPOSER_HOME=/root/.composer \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=20000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=256 \
    PHP_OPCACHE_JIT_BUFFER_SIZE=128M

# ==========================================
# RUNTIME DEPENDENCIES
# ==========================================
RUN apk add --no-cache \
    # Core utilities
    bash \
    curl \
    wget \
    git \
    unzip \
    zip \
    # Database clients
    mysql-client \
    postgresql-client \
    # Libraries
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    oniguruma \
    icu-libs \
    libxml2 \
    libxslt \
    imagemagick \
    # Process management
    supervisor \
    # Web server
    caddy \
    # Node.js (for asset compilation if needed)
    nodejs \
    npm \
    && rm -rf /var/cache/apk/*

# ==========================================
# PHP EXTENSIONS (Single optimized layer)
# ==========================================
RUN apk add --no-cache --virtual .build-deps \
    # Build essentials
    $PHPIZE_DEPS \
    autoconf \
    g++ \
    make \
    # Extension dependencies
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    icu-dev \
    libxml2-dev \
    libxslt-dev \
    imagemagick-dev \
    postgresql-dev \
    linux-headers \
    # Configure and install GD with freetype/jpeg support
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    # Install core PHP extensions
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        mysqli \
        mbstring \
        pcntl \
        bcmath \
        zip \
        intl \
        opcache \
        gd \
        exif \
        soap \
        xsl \
        sockets \
    # Install PECL extensions
    && pecl install redis \
    && pecl install imagick \
    && docker-php-ext-enable redis imagick \
    # Cleanup
    && apk del .build-deps \
    && rm -rf /tmp/* /var/cache/apk/* /usr/src/*

# ==========================================
# PHP CONFIGURATION (Optimized for Laravel)
# ==========================================
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.enable_cli=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=\${PHP_OPCACHE_MEMORY_CONSUMPTION}" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=\${PHP_OPCACHE_MAX_ACCELERATED_FILES}" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=\${PHP_OPCACHE_VALIDATE_TIMESTAMPS}" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.jit=1255" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.jit_buffer_size=\${PHP_OPCACHE_JIT_BUFFER_SIZE}" >> /usr/local/etc/php/conf.d/opcache.ini

# PHP settings for Laravel
RUN echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/laravel.ini \
    && echo "upload_max_filesize=100M" >> /usr/local/etc/php/conf.d/laravel.ini \
    && echo "post_max_size=100M" >> /usr/local/etc/php/conf.d/laravel.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/laravel.ini \
    && echo "max_input_vars=5000" >> /usr/local/etc/php/conf.d/laravel.ini \
    && echo "realpath_cache_size=4096K" >> /usr/local/etc/php/conf.d/laravel.ini \
    && echo "realpath_cache_ttl=600" >> /usr/local/etc/php/conf.d/laravel.ini

# ==========================================
# COMPOSER (Latest stable)
# ==========================================
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Verify composer installation
RUN composer --version

# ==========================================
# GLOBAL COMPOSER PACKAGES
# ==========================================
RUN composer global config allow-plugins.pestphp/pest-plugin true \
    && composer global require \
    laravel/installer \
    laravel/envoy \
    phpunit/phpunit \
    squizlabs/php_codesniffer \
    friendsofphp/php-cs-fixer \
    pestphp/pest \
    && composer global clear-cache

# Add composer global bin to PATH
ENV PATH="${COMPOSER_HOME}/vendor/bin:${PATH}"

# ==========================================
# WORKING DIRECTORY & PERMISSIONS
# ==========================================
WORKDIR /var/www/html

# Create app user for non-root operations (optional use)
RUN addgroup -g 1000 -S appgroup \
    && adduser -u 1000 -S appuser -G appgroup \
    && mkdir -p /var/www/html \
    && chown -R appuser:appgroup /var/www/html

# ==========================================
# HEALTHCHECK
# ==========================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD php-fpm -t || exit 1

# ==========================================
# DEFAULT COMMAND
# ==========================================
EXPOSE 9000

CMD ["php-fpm"]