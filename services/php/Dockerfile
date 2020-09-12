ARG PHP_VERSION
FROM ${PHP_VERSION}

ARG TZ
ARG PHP_EXTENSIONS
ARG CONTAINER_PACKAGE_URL


RUN sed -i "s/dl-cdn.alpinelinux.org/${CONTAINER_PACKAGE_URL}/g" /etc/apk/repositories


COPY ./extensions /tmp/extensions
WORKDIR /tmp/extensions
RUN apk update \
    && chmod +x install.sh \
    && sh install.sh \
    && rm -rf /tmp/extensions


RUN apk --no-cache add tzdata \
    && cp "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone


# Fix: https://github.com/docker-library/php/issues/240
RUN apk add gnu-libiconv libstdc++ --no-cache --repository http://${CONTAINER_PACKAGE_URL}/alpine/edge/community/ --allow-untrusted
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php


# Install composer and change it's cache home
# RUN curl -o /usr/bin/composer https://mirrors.aliyun.com/composer/composer.phar \
#    && chmod +x /usr/bin/composer
COPY ./composer.phar_1.10.10 /usr/bin/composer
COPY ./install-php-extensions /usr/bin/install-php-extensions
RUN chmod a+x /usr/bin/composer
RUN chmod a+x /usr/bin/install-php-extensions
ENV COMPOSER_HOME=/tmp/composer


# php image's www-data user uid & gid are 82, change them to 1000 (primary user)
# RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

# RUN chown -R www-data:www-data /www

WORKDIR /www
