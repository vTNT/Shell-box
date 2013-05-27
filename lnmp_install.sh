#!/bin/sh

# Usage
if [ $# -lt 1 ];then                                                                  
    echo "USAGE: $0 [nginx|php|mysql51|mysql55] ..."
    exit 1;                                                                          
fi

# app PATH config
NGINX_PATH=/usr/local/nginx
MYSQL_PATH=/usr/local/mysql
MYSQL_DATA_PATH=/data/mysql
MYSQL_LOG_PATH=/var/log/mysql
PHP_PATH=/usr/local/php

# install variables
PWD_PATH=$(cd $(dirname "$0") > /dev/null; pwd)
CORE_NUM=`cat /proc/cpuinfo | grep "model name" | wc -l`
MEM_SIZE=`free -m | awk 'NR==2 {print $2}'`

# set umask 0022
umask 0022

# disable selinux
selinux=`grep "SELINUX=enforcing" /etc/sysconfig/selinux | wc -l`                    
if [ $selinux -eq 1 ]; then                                                          
    echo "Disable SELinux..."                                                        
    setenforce 0                                                                     
    sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux           
fi

# generate nginx worker_cpu_affinity
nginx_cpu () {
    ZERO=`for((i=1;i<=$CORE_NUM;i++));do echo -n "0";done;`
    for (( i = $CORE_NUM; i > 0; i-- )); do
        echo -n ${ZERO:0:$i-1}"1"${ZERO:$i}" "
    done
}

# Install dependency
install_deps () {
    yum -y install gcc gcc-c++ cmake autoconf automake libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel glibc glibc-devel libstdc++-devel glib2 glib2-devel bzip2 bzip2-devel ncurses curl curl-devel e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel libtiff libtiff-devel gettext gettext-devel pam pam-devel fontconfig-devel libXpm-devel libtool ncurses-devel flex bison libevent libevent-devel
}

# Install nginx
install_nginx () {
    # add www user
    groupadd www && useradd -g www -s /sbin/nologin www
    # pcre sources
    tar -xjf $PWD_PATH/tarballs/pcre-8.32.tar.bz2 -C /usr/local/src
    # nginx sources
    tar -xzf $PWD_PATH/tarballs/nginx-1.2.1.tar.gz -C /usr/local/src
    cd /usr/local/src/nginx-1.2.1
    ./configure --prefix=$NGINX_PATH --with-http_stub_status_module --with-http_ssl_module --with-pcre=/usr/local/src/pcre-8.32
    make -j $CORE_NUM --silent && make install
    cp -f $PWD_PATH/scripts/nginxd /etc/init.d
	chmod +x /etc/init.d/nginxd
    [ ! -f $NGINX_PATH/conf/nginx.conf.origin ] && cp $NGINX_PATH/conf/nginx.conf{,.origin} 
    cp -f $PWD_PATH/configs/nginx.conf $NGINX_PATH/conf/nginx.conf
    if [ $CORE_NUM -ge 2 ]; then
        sed -i "s/worker_processes.*/worker_processes $CORE_NUM;/" $NGINX_PATH/conf/nginx.conf
        sed -i "/^worker_processes/a worker_cpu_affinity $(nginx_cpu)" $NGINX_PATH/conf/nginx.conf
        sed -i "/^worker_cpu_affinity/s/ *$/;/1" $NGINX_PATH/conf/nginx.conf
    fi
    chkconfig --add nginxd
    chkconfig nginxd on
    service nginxd start
}

# Install libs for php
install_libs () {
    # include libiconv
    echo "Install php..."
    echo "/usr/local/lib" >> /etc/ld.so.conf
    # libiconv
    tar -xzf $PWD_PATH/tarballs/libiconv-1.14.tar.gz -C /usr/local/src
    cd /usr/local/src/libiconv-1.14
    ./configure
    make -j $CORE_NUM --silent && make install
    # mhash
    tar -xjf $PWD_PATH/tarballs/mhash-0.9.9.9.tar.bz2 -C /usr/local/src
    cd /usr/local/src/mhash-0.9.9.9
    ./configure
    make -j $CORE_NUM -s && make install
    /sbin/ldconfig
    # libmcrypt
    tar -xzf $PWD_PATH/tarballs/libmcrypt-2.5.7.tar.gz -C /usr/local/src
    cd /usr/local/src/libmcrypt-2.5.7
    ./configure
    make -j $CORE_NUM --silent && make install
    cd libltdl
    ./configure --enable-ltdl-install
    make -s && make install
    /sbin/ldconfig
    # mcrypt
    tar -xzf $PWD_PATH/tarballs/mcrypt-2.6.4.tar.gz -C /usr/local/src
    cd /usr/local/src/mcrypt-2.6.4
    ./configure --with-libmcrypt-prefix=/usr/local
    make -j $CORE_NUM -s && make install
    # ImageMagick
    tar -xjf $PWD_PATH/tarballs/ImageMagick-6.7.9-3.tar.bz2 -C /usr/local/src
    cd /usr/local/src/ImageMagick-6.7.9-3
    ./configure --prefix=/usr/local/ImageMagick
    make -j $CORE_NUM -s && make install
    export PKG_CONFIG_PATH=/usr/local/ImageMagick/lib/pkgconfig/
    /sbin/ldconfig
}

# Install php ext
install_ext () {
    # memcache ext
    tar -xzf $PWD_PATH/tarballs/memcache-2.2.5.tgz -C /usr/local/src
    cd /usr/local/src/memcache-2.2.5
    $PHP_PATH/bin/phpize
    ./configure --with-php-config=$PHP_PATH/bin/php-config
    make -j $CORE_NUM && make install
    # redis ext
    tar -xjf $PWD_PATH/tarballs/phpredis-2.2.3.tar.bz2 -C /usr/local/src
    cd /usr/local/src/phpredis-2.2.3
    $PHP_PATH/bin/phpize
    ./configure --with-php-config=$PHP_PATH/bin/php-config
    make -j $CORE_NUM && make install
    # imagick ext
    tar -xzf $PWD_PATH/tarballs/imagick-3.1.0RC2.tgz -C /usr/local/src
    cd /usr/local/src/imagick-3.1.0RC2
    $PHP_PATH/bin/phpize
    ./configure --with-php-config=$PHP_PATH/bin/php-config --with-imagick=/usr/local/ImageMagick
    make -j $CORE_NUM && make install
    mkdir -p $PHP_PATH/etc/php.d
    cp -rf $PWD_PATH/configs/*.ini /usr/local/php/etc/php.d
}

# Install php
install_php () {
    # add www user
    groupadd www && useradd -g www -s /sbin/nologin www
    # install libs for php
    install_libs
    # install php
    tar -xjf $PWD_PATH/tarballs/php-5.4.4.tar.bz2 -C /usr/local/src
    cd /usr/local/src/php-5.4.4
    ./configure --prefix=$PHP_PATH --with-config-file-path=$PHP_PATH/etc --with-config-file-scan-dir=$PHP_PATH/etc/php.d --with-iconv-dir=/usr/local --enable-fpm --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --with-curlwrappers --enable-mbregex --enable-mbstring --with-mcrypt --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --enable-gd-native-ttf --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --enable-mysqlnd --with-pdo-mysql=mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-zlib
    make ZEND_EXTRA_LIBS='-liconv' -j $CORE_NUM -s && make install
    # php.ini
    cp -f php.ini-production $PHP_PATH/etc/php.ini
    sed -i "s#^;date.timezone.*#date.timezone = Asia/Shanghai#" $PHP_PATH/etc/php.ini
    sed -i "s/^display_errors.*/display_errors = Off/" $PHP_PATH/etc/php.ini
    sed -i "s/^expose_php.*/expose_php = Off/" $PHP_PATH/etc/php.ini 
    sed -i 's#output_buffering = Off#output_buffering = On#' $PHP_PATH/etc/php.ini
    sed -i "s#; always_populate_raw_post_data = On#always_populate_raw_post_data = On#g" $PHP_PATH/etc/php.ini
    sed -i "s#; cgi.fix_pathinfo=0#cgi.fix_pathinfo=0#g" $PHP_PATH/etc/php.ini
    sed -i 's#output_buffering = Off#output_buffering = On#' $PHP_PATH/etc/php.ini
    sed -i "s#; always_populate_raw_post_data = On#always_populate_raw_post_data = On#g" $PHP_PATH/etc/php.ini
    sed -i "s#; cgi.fix_pathinfo=0#cgi.fix_pathinfo=0#g" $PHP_PATH/etc/php.ini
    # php-fpm.conf
    cp -f $PHP_PATH/etc/php-fpm.conf.default $PHP_PATH/etc/php-fpm.conf
    sed -i "s/user =.*/user = www/" $PHP_PATH/etc/php-fpm.conf
    sed -i "s/group =.*/group = www/" $PHP_PATH/etc/php-fpm.conf
    sed -i "s#;pid = run/php-fpm.pid#pid = run/php-fpm.pid#" $PHP_PATH/etc/php-fpm.conf
    sed -i '/^;error_log/s/;//1' $PHP_PATH/etc/php-fpm.conf
    sed -i "s/^pm.max_children.*/pm.max_children = $(($MEM_SIZE/64))/" $PHP_PATH/etc/php-fpm.conf
    sed -i "s/^pm.start_servers.*/pm.start_servers = $(($MEM_SIZE/64/2 + $MEM_SIZE/64/4))/" $PHP_PATH/etc/php-fpm.conf
    sed -i "s/^pm.min_spare_servers.*/pm.min_spare_servers = $(($MEM_SIZE/64/2))/" $PHP_PATH/etc/php-fpm.conf
    sed -i "s/^pm.max_spare_servers.*/pm.max_spare_servers = $(($MEM_SIZE/64))/" $PHP_PATH/etc/php-fpm.conf
    sed -i '/^;slowlog/s/;//1' $PHP_PATH/etc/php-fpm.conf
    sed -i "s#^;php_admin_value[error_log].* #php_admin_value[error_log] = $PHP_PATH_log/fpm-php.www.log#" $PHP_PATH/etc/php-fpm.conf
    sed -i "s/^;php_admin_flag[log_errors].*/php_admin_flag[log_errors] = on/" $PHP_PATH/etc/php-fpm.conf
    sed -i 's/listen = 127.0.0.1:.*/;&\nlisten = \/dev\/shm\/php.socket/' $PHP_PATH/etc/php-fpm.conf
    # install ext
    install_ext
    # service php-fpm
    cp -f $PWD_PATH/scripts/php-fpm /etc/init.d
	chmod +x /etc/init.d/php-fpm
    chkconfig --add php-fpm
    chkconfig php-fpm on
    service php-fpm start
    ln -sf /usr/local/php/bin/php /usr/local/bin/php
}

# Prepare mysql
prepare_mysql() {
    groupadd mysql
    useradd -g mysql -r -s /sbin/nologin mysql
    mkdir -p $MYSQL_LOG_PATH
    chown mysql $MYSQL_LOG_PATH
    mkdir -p $MYSQL_DATA_PATH
    chown mysql $MYSQL_DATA_PATH
}

# fix permission and install db
finish_mysql() {
    if [ -f /etc/my.cnf ] && [ ! -f /etc/my.cnf.bak ]; then
        cp /etc/my.cnf{,.bak}
    fi
    if [ $MEM_SIZE -lt 2048 ]; then
        cp -f support-files/my-medium.cnf /etc/my.cnf
    else
        cp -f support-files/my-huge.cnf /etc/my.cnf
    fi
    # my.cnf optimize
    sed -i "/^\[mysqld\]/a pid-file\t= $MYSQL_DATA_PATH\/mysql.pid" /etc/my.cnf
    sed -i "/^myisam_sort_buffer_size/a datadir = $MYSQL_DATA_PATH" /etc/my.cnf
    sed -i "/^myisam_sort_buffer_size/a basedir = $MYSQL_PATH" /etc/my.cnf
    sed -i "/^myisam_sort_buffer_size/a max_connections = 2000" /etc/my.cnf
    sed -i "/^#skip-networking/a skip-name-resolve" /etc/my.cnf
    sed -i "/^log-bin/i log-error = $MYSQL_LOG_PATH/mysql_error.log" /etc/my.cnf
    sed -i "s#log-bin=mysql-bin#log-bin = $MYSQL_LOG_PATH/binlog#" /etc/my.cnf
    sed -i "/^log-bin/a expire_logs_days = 7" /etc/my.cnf
    sed -i "/^datadir = /a slow_query_log = 1\nlong_query_time = 1\nslow_query_log_file = $MYSQL_LOG_PATH/slowquery.log" /etc/my.cnf
    $MYSQL_PATH/bin/mysql_install_db --user=mysql --basedir=$MYSQL_PATH --datadir=$MYSQL_DATA_PATH --defaults-file=/etc/my.cnf
    sleep 3
    # init script
    cp support-files/mysql.server /etc/init.d/mysqld -f
    chmod +x /etc/init.d/mysqld
    chown -R root:mysql $MYSQL_PATH
    chown -R mysql:mysql $MYSQL_LOG_PATH
    chown -R mysql:mysql $MYSQL_DATA_PATH
    chkconfig --add mysqld
    chkconfig mysqld on
    service mysqld start
    ln -sf /usr/local/mysql/bin/mysql /usr/local/bin/mysql
}

# Install mysql5.1
install_mysql51 () {
    prepare_mysql
    tar -xzf $PWD_PATH/tarballs/Percona-Server-5.1.58.tar.gz -C /usr/local/src
    cd /usr/local/src/Percona-Server-5.1.58
    ./configure --prefix=$MYSQL_PATH --localstatedir=$MYSQL_DATA_PATH --with-charset=utf8 --with-extra-charsets=complex --with-pthread --enable-thread-safe-client --with-ssl --with-client-ldflags=-all-static --with-mysqld-ldflags=-all-static --with-plugins=partition,federated,innobase,csv,myisam,innodb_plugin --enable-shared --enable-assembler
    make -j $CORE_NUM -s && make install
    finish_mysql
}

# Install mysql5.5
install_mysql55 () {
    prepare_mysql
    tar -xzf $PWD_PATH/tarballs/Percona-Server-5.5.30-rel30.1.tar.gz -C /usr/local/src
    cd /usr/local/src/Percona-Server-5.5.30-rel30.1
    cmake . -DMYSQL_DATADIR=$MYSQL_DATA_PATH -DCMAKE_INSTALL_PREFIX=$MYSQL_PATH -DDEFAULT_CHARSET=utf8 -DWITH_EXTRA_CHARSETS=complex -DWITH_SSL=yes -DDEFAULT_COLLATION=utf8_general_ci
    make -j $CORE_NUM && make install
    ln -s $MYSQL_PATH/scripts/mysql_install_db $MYSQL_PATH/bin/mysql_install_db
    finish_mysql
}

# Start LNMP...
install_deps
for app in $@; do
    install_$app
done

# src
chown -R root:root /usr/local/src

# Congratulation
echo "Congratulation! all done."
