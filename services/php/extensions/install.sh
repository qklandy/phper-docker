#!/bin/sh

# other unix
export MC="-j$(nproc)"
# mac osx
# export MC="-j1024"

echo
echo "============================================"
echo "Install extensions from   : install.sh"
echo "PHP version               : ${PHP_VERSION}"
echo "Extra Extensions          : ${PHP_EXTENSIONS}"
echo "Multicore Compilation     : ${MC}"
echo "Container package url     : ${CONTAINER_PACKAGE_URL}"
echo "Work directory            : ${PWD}"
echo "============================================"
echo


if [ "${PHP_EXTENSIONS}" != "" ]; then
    # global install
    apk add openssl openssl-dev pcre-dev pcre curl-dev gettext-dev \
    libevent-dev libuv-dev libev-dev \
    librdkafka librdkafka-dev \
    ncurses libaio bison  libxml2-dev libffi libxml2 \
    libxslt libxslt-dev libffi-dev re2c 

    # virtual depends install
    apk --update add --no-cache --virtual .build-deps \
    automake autoconf g++ libtool make cmake linux-headers musl-dev
fi

export EXTENSIONS=",${PHP_EXTENSIONS},"

#
# Check if current php version is greater than or equal to
# specific version.
#
# For example, to check if current php is greater than or
# equal to PHP 7.0:
#
# isPhpVersionGreaterOrEqual 7 0
#
# Param 1: Specific PHP Major version
# Param 2: Specific PHP Minor version
# Return : 1 if greater than or equal to, 0 if less than
#
isPhpVersionGreaterOrEqual()
 {
    local PHP_MAJOR_VERSION=$(php -r "echo PHP_MAJOR_VERSION;")
    local PHP_MINOR_VERSION=$(php -r "echo PHP_MINOR_VERSION;")

    if [[ "$PHP_MAJOR_VERSION" -gt "$1" || "$PHP_MAJOR_VERSION" -eq "$1" && "$PHP_MINOR_VERSION" -ge "$2" ]]; then
        echo "isPhpVersionGreaterOrEqual ${1} ${2} ${3} is RESULT = 1\n"
        return 1;
    else
        echo "isPhpVersionGreaterOrEqual ${1} ${2} ${3} is RESULT = 0\n"
        return 0;
    fi
}


#
# Install extension from package file(.tgz),
# For example:
#
# installExtensionFromTgz redis-5.0.2
#
# Param 1: Package name with version
# Param 2: enable options
#
installExtensionFromTgz()
{
    cd /tmp/extensions
    tgzName=$1
    extensionName="${tgzName%%-*}"

    echo $*

    echo "---------- installExtensionFromTgz Install ${extensionName} start----------" 
    mkdir ${extensionName}
    tar -xf ${tgzName}.tgz -C ${extensionName} --strip-components=1

    local configureParams="${2}"
    local extPhpEnableParams="${3}"

    echo ${configureParams}

    echo "-- cd ${extensionName} && phpize && ./configure ${configureParams} && make ${MC} && make install --"
    cd ${extensionName} && phpize && ./configure ${configureParams} && make ${MC} && make install

    echo "-- docker-php-ext-enable ${extensionName} ${extPhpEnableParams} --"
    docker-php-ext-enable ${extensionName} ${extPhpEnableParams}
    echo "---------- installExtensionFromTgz Install ${extensionName} end----------"
    cd /tmp/extensions
}

installExtensionFromTgzForUv()
{
    cd /tmp/extensions
    mkdir libuv-1.x && tar -xf libuv-1.x.tgz -C libuv-1.x
    cd libuv-1.x/libuv-1.x && ./autogen.sh && ./configure make && make install

    if [[ "$?" = "1" ]]; then
        cd /tmp/extensions
        echo "-- pecl install uv-0.2.4 && docker-php-ext-enable uv  --"
        pecl install uv-0.2.4.tgz && docker-php-ext-enable uv
        echo "---------- installExtensionFromTgz Install uv end----------"
    else
        echo "-- jump install uv  --"
    fi
    cd /tmp/extensions
}

installBasicFromTgz()
{
    cd /tmp/extensions
    tgzName=$1
    dirName="${tgzName%.*}"

    mkdir ${dirName}
    tar -xf ${tgzName} -C ${PWD}/${dirName} --strip-components=1
    cd ${PWD}/${dirName} &&  ./configure && make && make install
    cd /tmp/extensions
}

installBasicCmakeFromTgz()
{
    cd /tmp/extensions
    tgzName=$1
    dirName="${tgzName%.*}"

    mkdir ${dirName}
    tar -xf ${tgzName} -C ${PWD}/${dirName} --strip-components=1
    cd ${PWD}/${dirName} && mkdir build && cd build && cmake $2 .. && cmake --build . --target install
    cd /tmp/extensions
}

installExtensionFromTgzWithPecl()
{
    cd /tmp/extensions
    tgzFile=$1
    extensionName="${tgzFile%%-*}"

    echo $* >> /tmp/installExtensionFromTgzWithPecl.log

    echo "---------- installExtensionFromTgzWithPecl Install ${extensionName} start----------"  >> /tmp/installExtensionFromTgzWithPecl.log

    echo "---------- pecl install ${tgzFile} && docker-php-ext-enable ${extensionName} $2 ----------"  >> /tmp/installExtensionFromTgzWithPecl.log
    pecl install ${tgzFile} && docker-php-ext-enable ${extensionName} $2

    echo "---------- installExtensionFromTgzWithPecl Install ${extensionName} end----------"  >> /tmp/installExtensionFromTgzWithPecl.log
    cd /tmp/extensions
}

# re2c update or apk add rec-1.0.2
#echo "---------- Update re2c-1.3 ----------"
#installBasicFromTgz re2c-1.3.tgz

if [[ -z "${EXTENSIONS##*,pdo_mysql,*}" ]]; then
    echo "---------- Install pdo_mysql ----------"
    docker-php-ext-install ${MC} pdo_mysql
fi

if [[ -z "${EXTENSIONS##*,pcntl,*}" ]]; then
    echo "---------- Install pcntl ----------"
	docker-php-ext-install ${MC} pcntl
fi

if [[ -z "${EXTENSIONS##*,mysqli,*}" ]]; then
    echo "---------- Install mysqli ----------"
	docker-php-ext-install ${MC} mysqli
fi

if [[ -z "${EXTENSIONS##*,mcrypt,*}" ]]; then
    isPhpVersionGreaterOrEqual 7 2 mcrypt
    if [[ "$?" = "1" ]]; then
        echo "---------- mcrypt was REMOVED from PHP 7.2.0 ----------"
    else
        echo "---------- Install mcrypt ----------"
        apk add --no-cache libmcrypt-dev \
        && docker-php-ext-install ${MC} mcrypt
    fi
fi

if [[ -z "${EXTENSIONS##*,mbstring,*}" ]]; then
    echo "---------- mbstring is installed ----------"
fi

if [[ -z "${EXTENSIONS##*,exif,*}" ]]; then
    echo "---------- Install exif ----------"
	docker-php-ext-install ${MC} exif
fi

if [[ -z "${EXTENSIONS##*,bcmath,*}" ]]; then
    echo "---------- Install bcmath ----------"
	docker-php-ext-install ${MC} bcmath
fi

if [[ -z "${EXTENSIONS##*,calendar,*}" ]]; then
    echo "---------- Install calendar ----------"
	docker-php-ext-install ${MC} calendar
fi

if [[ -z "${EXTENSIONS##*,zend_test,*}" ]]; then
    echo "---------- Install zend_test ----------"
	docker-php-ext-install ${MC} zend_test
fi

if [[ -z "${EXTENSIONS##*,opcache,*}" ]]; then
    echo "---------- Install opcache ----------"
    docker-php-ext-install opcache
fi

if [[ -z "${EXTENSIONS##*,pthreads,*}" ]]; then
    echo "---------- Install pthreads ----------"
    installExtensionFromTgzWithPecl pthreads-3.1.6.tgz
fi

if [[ -z "${EXTENSIONS##*,pht,*}" ]]; then
    # https://github.com/tpunt/pht#installation
    echo "---------- TODO: Install pht ----------"
    # installExtensionFromTgzWithPecl pht-0.0.1.tgz
fi

if [[ -z "${EXTENSIONS##*,parallel,*}" ]]; then
    # https://github.com/krakjoe/parallel/blob/develop/INSTALL.md
    echo "---------- TODO: Install parallel ----------"
    # installExtensionFromTgzWithPecl parallel-1.1.3.tgz
fi

if [[ -z "${EXTENSIONS##*,gettext,*}" ]]; then
    echo "---------- Install gettext ----------"
	docker-php-ext-install ${MC} gettext
fi

if [[ -z "${EXTENSIONS##*,shmop,*}" ]]; then
    echo "---------- Install shmop ----------"
	docker-php-ext-install ${MC} shmop
fi

if [[ -z "${EXTENSIONS##*,sysvmsg,*}" ]]; then
    echo "---------- Install sysvmsg ----------"
	docker-php-ext-install ${MC} sysvmsg
fi

if [[ -z "${EXTENSIONS##*,sysvsem,*}" ]]; then
    echo "---------- Install sysvsem ----------"
	docker-php-ext-install ${MC} sysvsem
fi

if [[ -z "${EXTENSIONS##*,sysvshm,*}" ]]; then
    echo "---------- Install sysvshm ----------"
	docker-php-ext-install ${MC} sysvshm
fi

if [[ -z "${EXTENSIONS##*,pdo_firebird,*}" ]]; then
    echo "---------- Install pdo_firebird ----------"
	docker-php-ext-install ${MC} pdo_firebird
fi

if [[ -z "${EXTENSIONS##*,pdo_dblib,*}" ]]; then
    echo "---------- Install pdo_dblib ----------"
	docker-php-ext-install ${MC} pdo_dblib
fi

if [[ -z "${EXTENSIONS##*,pdo_oci,*}" ]]; then
    echo "---------- Install pdo_oci ----------"
	docker-php-ext-install ${MC} pdo_oci
fi

if [[ -z "${EXTENSIONS##*,pdo_odbc,*}" ]]; then
    echo "---------- Install pdo_odbc ----------"
	docker-php-ext-install ${MC} pdo_odbc
fi

if [[ -z "${EXTENSIONS##*,pdo_pgsql,*}" ]]; then
    echo "---------- Install pdo_pgsql ----------"
    apk --no-cache add postgresql-dev \
    && docker-php-ext-install ${MC} pdo_pgsql
fi

if [[ -z "${EXTENSIONS##*,pgsql,*}" ]]; then
    echo "---------- Install pgsql ----------"
    apk --no-cache add postgresql-dev \
    && docker-php-ext-install ${MC} pgsql
fi

if [[ -z "${EXTENSIONS##*,oci8,*}" ]]; then
    echo "---------- Install oci8 ----------"
	docker-php-ext-install ${MC} oci8
fi

if [[ -z "${EXTENSIONS##*,odbc,*}" ]]; then
    echo "---------- Install odbc ----------"
	docker-php-ext-install ${MC} odbc
fi

if [[ -z "${EXTENSIONS##*,dba,*}" ]]; then
    echo "---------- Install dba ----------"
	docker-php-ext-install ${MC} dba
fi

if [[ -z "${EXTENSIONS##*,interbase,*}" ]]; then
    echo "---------- Install interbase ----------"
    echo "Alpine linux do not support interbase/firebird!!!"
	#docker-php-ext-install ${MC} interbase
fi

if [[ -z "${EXTENSIONS##*,gd,*}" ]]; then
    echo "---------- Install gd ----------"
    isPhpVersionGreaterOrEqual 7 4 gd

    if [[ "$?" = "1" ]]; then
        # "--with-xxx-dir" was removed from php 7.4,
        # issue: https://github.com/docker-library/php/issues/912
        options="--with-freetype --with-jpeg"
    else
        options="--with-gd --with-freetype-dir=/usr/include/ --with-png-dir=/usr/include/ --with-jpeg-dir=/usr/include/"
    fi

    apk add --no-cache \
        freetype \
        freetype-dev \
        libpng \
        libpng-dev \
        libjpeg-turbo \
        libjpeg-turbo-dev \
    && docker-php-ext-configure gd ${options} \
    && docker-php-ext-install ${MC} gd \
    && apk del \
        freetype-dev \
        libpng-dev \
        libjpeg-turbo-dev
fi

if [[ -z "${EXTENSIONS##*,intl,*}" ]]; then
    echo "---------- Install intl ----------"
    apk add --no-cache icu-dev
    docker-php-ext-install ${MC} intl
fi

if [[ -z "${EXTENSIONS##*,bz2,*}" ]]; then
    echo "---------- Install bz2 ----------"
    apk add --no-cache bzip2-dev
    docker-php-ext-install ${MC} bz2
fi

if [[ -z "${EXTENSIONS##*,soap,*}" ]]; then
    echo "---------- Install soap ----------"
    apk add --no-cache libxml2-dev
	docker-php-ext-install ${MC} soap
fi

if [[ -z "${EXTENSIONS##*,xsl,*}" ]]; then
    echo "---------- Install xsl ----------"
	apk add --no-cache libxml2-dev libxslt-dev
	docker-php-ext-install ${MC} xsl
fi

if [[ -z "${EXTENSIONS##*,xmlrpc,*}" ]]; then
    echo "---------- Install xmlrpc ----------"
	apk add --no-cache libxml2-dev libxslt-dev
	docker-php-ext-install ${MC} xmlrpc
fi

if [[ -z "${EXTENSIONS##*,wddx,*}" ]]; then
    echo "---------- Install wddx ----------"
	apk add --no-cache libxml2-dev libxslt-dev
	docker-php-ext-install ${MC} wddx
fi

if [[ -z "${EXTENSIONS##*,curl,*}" ]]; then
    echo "---------- curl is installed ----------"
fi

if [[ -z "${EXTENSIONS##*,readline,*}" ]]; then
    echo "---------- Install readline ----------"
	apk add --no-cache readline-dev
	apk add --no-cache libedit-dev
	docker-php-ext-install ${MC} readline
fi

if [[ -z "${EXTENSIONS##*,snmp,*}" ]]; then
    echo "---------- Install snmp ----------"
	apk add --no-cache net-snmp-dev
	docker-php-ext-install ${MC} snmp
fi

if [[ -z "${EXTENSIONS##*,pspell,*}" ]]; then
    echo "---------- Install pspell ----------"
	apk add --no-cache aspell-dev
	apk add --no-cache aspell-en
	docker-php-ext-install ${MC} pspell
fi

if [[ -z "${EXTENSIONS##*,recode,*}" ]]; then
    echo "---------- Install recode ----------"
	apk add --no-cache recode-dev
	docker-php-ext-install ${MC} recode
fi

if [[ -z "${EXTENSIONS##*,tidy,*}" ]]; then
    echo "---------- Install tidy ----------"
	apk add --no-cache tidyhtml-dev

	# Fix: https://github.com/htacg/tidy-html5/issues/235
	ln -s /usr/include/tidybuffio.h /usr/include/buffio.h

	docker-php-ext-install ${MC} tidy
fi

if [[ -z "${EXTENSIONS##*,gmp,*}" ]]; then
    echo "---------- Install gmp ----------"
	apk add --no-cache gmp-dev
	docker-php-ext-install ${MC} gmp
fi

if [[ -z "${EXTENSIONS##*,imap,*}" ]]; then
    echo "---------- Install imap ----------"
	apk add --no-cache imap-dev
    docker-php-ext-configure imap --with-imap --with-imap-ssl
	docker-php-ext-install ${MC} imap
fi

if [[ -z "${EXTENSIONS##*,ldap,*}" ]]; then
    echo "---------- Install ldap ----------"
	apk add --no-cache ldb-dev
	apk add --no-cache openldap-dev
	docker-php-ext-install ${MC} ldap
fi

if [[ -z "${EXTENSIONS##*,imagick,*}" ]]; then
    echo "---------- Install imagick ----------"
	apk add --no-cache file-dev
	apk add --no-cache imagemagick-dev
    installExtensionFromTgzWithPecl imagick-3.4.4.tgz
fi

if [[ -z "${EXTENSIONS##*,rar,*}" ]]; then
    echo "---------- Install rar ----------"
    installExtensionFromTgzWithPecl rar-4.0.0.tgz
fi

if [[ -z "${EXTENSIONS##*,ast,*}" ]]; then
    echo "---------- Install ast ----------"
    installExtensionFromTgzWithPecl ast-1.0.5.tgz
fi

if [[ -z "${EXTENSIONS##*,msgpack,*}" ]]; then
    echo "---------- Install msgpack ----------"
    installExtensionFromTgzWithPecl msgpack-2.0.3.tgz
fi

if [[ -z "${EXTENSIONS##*,igbinary,*}" ]]; then
    echo "---------- Install igbinary ----------"
    installExtensionFromTgzWithPecl igbinary-3.1.2.tgz
fi

if [[ -z "${EXTENSIONS##*,libevent,*}" ]]; then
    echo "---------- Install libevent ----------"
    isPhpVersionGreaterOrEqual 6 0 libevent
    if [[ "$?" = "1" ]]; then
        echo "---------- libevent require PHP version <= 6.0.0 ----------"
    else
        installExtensionFromTgzWithPecl libevent-0.1.0.tgz
    fi
fi

if [[ -z "${EXTENSIONS##*,yac,*}" ]]; then
    echo "---------- Install yac ----------"
    printf "\n" | pecl install yac-2.0.2
    docker-php-ext-enable yac
fi

if [[ -z "${EXTENSIONS##*,yar,*}" ]]; then
    isPhpVersionGreaterOrEqual 7 0 yar
    if [[ "$?" = "1" ]]; then
        echo "---------- Install yar ----------"
        printf "\n" | pecl install yar
        docker-php-ext-enable yar
    else
        echo "yar requires PHP >= 7.0.0, installed version is ${PHP_VERSION}"
    fi

fi

if [[ -z "${EXTENSIONS##*,yaconf,*}" ]]; then
    echo "---------- Install yaconf ----------"
    printf "\n" | pecl install yaconf
    docker-php-ext-enable yaconf
fi

if [[ -z "${EXTENSIONS##*,seaslog,*}" ]]; then
    echo "---------- Install seaslog ----------"
    printf "\n" | pecl install seaslog
    docker-php-ext-enable seaslog
fi

if [[ -z "${EXTENSIONS##*,varnish,*}" ]]; then
    echo "---------- Install varnish ----------"
	apk add --no-cache varnish-dev
    printf "\n" | pecl install varnish
    docker-php-ext-enable varnish
fi

if [[ -z "${EXTENSIONS##*,pdo_sqlsrv,*}" ]]; then
    isPhpVersionGreaterOrEqual 7 1 pdo_sqlsrv
    if [[ "$?" = "1" ]]; then
        echo "---------- Install pdo_sqlsrv ----------"
        apk add --no-cache unixodbc-dev
        printf "\n" | pecl install pdo_sqlsrv
        docker-php-ext-enable pdo_sqlsrv
    else
        echo "pdo_sqlsrv requires PHP >= 7.1.0, installed version is ${PHP_VERSION}"
    fi
fi

if [[ -z "${EXTENSIONS##*,sqlsrv,*}" ]]; then
    isPhpVersionGreaterOrEqual 7 1 sqlsrv
    if [[ "$?" = "1" ]]; then
        echo "---------- Install sqlsrv ----------"
        apk add --no-cache unixodbc-dev
        printf "\n" | pecl install sqlsrv
        docker-php-ext-enable sqlsrv
    else
        echo "pdo_sqlsrv requires PHP >= 7.1.0, installed version is ${PHP_VERSION}"
    fi
fi

if [[ -z "${EXTENSIONS##*,mysql,*}" ]]; then
    isPhpVersionGreaterOrEqual 7 0 mysql

    if [[ "$?" = "1" ]]; then
        echo "---------- mysql was REMOVED from PHP 7.0.0 ----------"
    else
        echo "---------- Install mysql ----------"
        docker-php-ext-install ${MC} mysql
    fi
fi

if [[ -z "${EXTENSIONS##*,sodium,*}" ]]; then
    isPhpVersionGreaterOrEqual 7 2
    if [[ "$?" = "1" ]]; then
        echo
        echo "Sodium is bundled with PHP from PHP 7.2.0"
        echo
    else
        echo "---------- Install sodium ----------"
        apk add --no-cache libsodium-dev
        docker-php-ext-install ${MC} sodium
	fi
fi

if [[ -z "${EXTENSIONS##*,amqp,*}" ]]; then
    echo "---------- Install rabbitmq-c ----------"
    installBasicCmakeFromTgz rabbitmq-c-0.10.0.tgz -DCMAKE_INSTALL_PREFIX=/usr/local/rabbitmq-c-0.10.0
    echo "---------- link rabbitmq.lib64->lib ----------"
    ln -s /usr/local/rabbitmq-c-0.10.0/lib64/ /usr/local/rabbitmq-c-0.10.0/lib
    echo "---------- Install amqp 1.10.2 ----------"
    installExtensionFromTgz amqp-1.10.2 "--with-amqp --with-librabbitmq-dir=/usr/local/rabbitmq-c-0.10.0"
fi

if [[ -z "${EXTENSIONS##*,redis,*}" ]]; then
    echo "---------- Install redis ----------"
    isPhpVersionGreaterOrEqual 7 0 redis
    if [[ "$?" = "1" ]]; then
        installExtensionFromTgz redis-5.3.1
    else
        installExtensionFromTgz redis-5.0.2
    fi
fi

if [[ -z "${EXTENSIONS##*,apcu,*}" ]]; then
    echo "---------- Install apcu ----------"
    installExtensionFromTgz apcu-5.1.17
fi

if [[ -z "${EXTENSIONS##*,memcached,*}" ]]; then
    echo "---------- Install memcached ----------"
    apk add --no-cache libmemcached-dev zlib-dev
    isPhpVersionGreaterOrEqual 7 0 memcached

    if [[ "$?" = "1" ]]; then
        installExtensionFromTgz memcached-3.1.5
    else
        installExtensionFromTgz memcached-2.2.0
    fi

    docker-php-ext-enable memcached
fi

if [[ -z "${EXTENSIONS##*,memcache,*}" ]]; then
    echo "---------- Install memcache ----------"
    isPhpVersionGreaterOrEqual 7 0 memcache
    if [[ "$?" = "1" ]]; then
        installExtensionFromTgz memcache-4.0.5.2
    else
        installExtensionFromTgz memcache-2.2.6
    fi
fi

if [[ -z "${EXTENSIONS##*,xdebug,*}" ]]; then
    echo "---------- Install xdebug ----------"
    isPhpVersionGreaterOrEqual 7 0 xdebug

    if [[ "$?" = "1" ]]; then
        isPhpVersionGreaterOrEqual 7 4 xdebug
        if [[ "$?" = "1" ]]; then
            installExtensionFromTgz xdebug-2.9.2
        else
            installExtensionFromTgz xdebug-2.6.1
        fi
    else
        installExtensionFromTgz xdebug-2.5.5
    fi
fi

if [[ -z "${EXTENSIONS##*,event,*}" ]]; then
    echo "---------- Install event ----------"
    apk add --no-cache libevent-dev
    export is_sockets_installed=$(php -r "echo extension_loaded('sockets');")

    if [[ "${is_sockets_installed}" = "" ]]; then
        echo "---------- event is depend on sockets, install sockets first ----------"
        docker-php-ext-install sockets
    fi

    echo "---------- Install event again ----------"
    installExtensionFromTgz event-2.5.3  "--ini-name event.ini"
fi

if [[ -z "${EXTENSIONS##*,mongodb,*}" ]]; then
    echo "---------- Install mongodb ----------"
    isPhpVersionGreaterOrEqual 7 0 mongodb

    if [[ "$?" = "1" ]]; then
        installExtensionFromTgzWithPecl mongodb-1.6.1.tgz
    else
        installExtensionFromTgzWithPecl mongodb-1.6.1.tgz
    fi
    
fi

if [[ -z "${EXTENSIONS##*,zip,*}" ]]; then
    echo "---------- Install zip ----------"
    # Fix: https://github.com/docker-library/php/issues/797
    apk add --no-cache libzip-dev

    isPhpVersionGreaterOrEqual 7 4 zip
    if [[ "$?" != "1" ]]; then
        docker-php-ext-configure zip --with-libzip=/usr/include
    fi

	docker-php-ext-install ${MC} zip
fi

if [[ -z "${EXTENSIONS##*,xhprof,*}" ]]; then
    echo "---------- Install XHProf ----------"

    isPhpVersionGreaterOrEqual 7 0 xhprof

    if [[ "$?" = "1" ]]; then
        mkdir xhprof
        tar -xf xhprof-2.1.0.tgz -C xhprof --strip-components=1
        cd xhprof/extension/ && phpize && ./configure  && make ${MC} && make install
        docker-php-ext-enable xhprof
    else
       echo "---------- PHP Version>= 7.0----------"
    fi

fi

if [[ -z "${EXTENSIONS##*,xlswriter,*}" ]]; then
    echo "---------- Install xlswriter ----------"
    isPhpVersionGreaterOrEqual 7 0 xlswriter

    if [[ "$?" = "1" ]]; then
        installExtensionFromTgzWithPecl xlswriter-1.3.3.2.tgz
    else
        echo "---------- PHP Version>= 7.0----------"
    fi
fi

if [[ -z "${EXTENSIONS##*,yaf,*}" ]]; then
    echo "---------- Install yaf ----------"
    # PHP 5.4.X-5.6.X should intall yaf version 2.3.4~5
    # PHP 7.0+ 
    isPhpVersionGreaterOrEqual 7 0 yaf

    if [[ "$?" = "1" ]]; then
        installExtensionFromTgz yaf-3.2.5
    else
        installExtensionFromTgz yaf-2.3.5
    fi
fi

if [[ -z "${EXTENSIONS##*,sockets,*}" ]]; then
    echo "---------- Install sockets ----------"
	docker-php-ext-install ${MC} sockets
fi

if [[ -z "${EXTENSIONS##*,event,*}" ]]; then
    echo "---------- Install event ----------"
    installExtensionFromTgzWithPecl event-2.5.7.tgz
fi

if [[ -z "${EXTENSIONS##*,rdkafka,*}" ]]; then
    echo "---------- Install rdkafka ----------"
    installExtensionFromTgzWithPecl rdkafka-4.0.3.tgz
fi

if [[ -z "${EXTENSIONS##*,ev,*}" ]]; then
    echo "---------- Install ev ----------"
    installExtensionFromTgzWithPecl ev-1.0.8.tgz
fi

if [[ -z "${EXTENSIONS##*,uv,*}" ]]; then
    echo "---------- Install uv ----------"
    echo "---------- Install uv cannt succcess REMOVE Wait for solution ----------"
    installExtensionFromTgzForUv
fi

if [[ -z "${EXTENSIONS##*,swoole,*}" ]]; then
    # https://wiki.swoole.com/wiki/page/7.html
    # Swoole-1.x需要 PHP-5.3.10 或更高版本
    # Swoole-4.x需要 PHP-7.0.0 或更高版本

    # 来自网络
    # Swoole-1.x需要 PHP-5.3.10 或更高版本
    # Swoole-2.x需要 PHP-7.0.0 或更高版本
    # Swoole-4.x需要 PHP-7.1.0 或更高版本

    # 经测试
    # Swoole-4.4.x PHP-7.1， 7.0无法安装
    echo "---------- Install swoole ----------"
    isPhpVersionGreaterOrEqual 7 1 swoole
    if [[ "$?" = "1" ]]; then
        echo "---------- Install swoole 4.5.3 ----------"
        installExtensionFromTgz swoole-4.5.3
    else
        isPhpVersionGreaterOrEqual 7 0 swoole
        if [[ "$?" = "1" ]]; then
            echo "---------- Install swoole 2.2.0 ----------"
            installExtensionFromTgz swoole-2.2.0
        else
            echo "---------- Install swoole 1.10.6 ----------"
            installExtensionFromTgz swoole-1.10.6
        fi
    fi
fi

if [ "${PHP_EXTENSIONS}" != "" ]; then
    apk del .build-deps \
    && docker-php-source delete
fi
