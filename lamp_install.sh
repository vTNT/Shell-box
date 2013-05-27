#!/bin/sh

# Usage
if [ $# -lt 1 ];then                                                                  
    echo "USAGE: $0 [apache|php|mysql] ..."
    exit 1;                                                                          
fi

# app PATH config
HTTPD_PATH=/usr/local/apache2
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

# Install dependency
install_deps () {
    yum -y install gcc gcc-c++ cmake autoconf automake libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel glibc glibc-devel libstdc++-devel glib2 glib2-devel bzip2 bzip2-devel ncurses curl curl-devel e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel libtiff libtiff-devel gettext gettext-devel pam pam-devel fontconfig-devel libXpm-devel libtool ncurses-devel flex bison libevent libevent-devel
}

# Install apache
install_apache () {
    # add www user
    groupadd www && useradd -g www -s /sbin/nologin www
    # pcre
    tar -xjf $PWD_PATH/tarballs/pcre-8.32.tar.bz2 -C /usr/local/src
    cd /usr/local/src/pcre-8.32
    ./configure --prefix=/usr/local/pcre
    make -j $CORE_NUM && make install
    # zlib
    tar -xzf $PWD_PATH/tarballs/zlib-1.2.7.tar.gz -C /usr/local/src
    cd /usr/local/src/zlib-1.2.7
    ./configure --prefix=/usr/local/zlib
    make -j $CORE_NUM && make install
    # apache with apr
    tar -xjf $PWD_PATH/tarballs/httpd-2.4.4.tar.bz2 -C /usr/local/src
    tar -xjf $PWD_PATH/tarballs/apr-1.4.6.tar.bz2 -C /usr/local/src/httpd-2.4.4/srclib
    mv /usr/local/src/httpd-2.4.4/srclib/apr-1.4.6 /usr/local/src/httpd-2.4.4/srclib/apr
    tar -xjf $PWD_PATH/tarballs/apr-util-1.5.2.tar.bz2 -C /usr/local/src/httpd-2.4.4/srclib
    mv /usr/local/src/httpd-2.4.4/srclib/apr-util-1.5.2 /usr/local/src/httpd-2.4.4/srclib/apr-util
    cd /usr/local/src/httpd-2.4.4
    ./configure --prefix=$HTTPD_PATH --enable-ssl --enable-rewrite --enable-expires --with-included-apr --with-pcre=/usr/local/pcre/bin/pcre-config --with-z=/usr/local/zlib --with-mpm=prefork
    # other mpm
    # --enable-mpms-shared=all 
    make -j $CORE_NUM -s && make install
    sed -i "s/^User .*/User www/" $HTTPD_PATH/conf/httpd.conf
    sed -i "s/^Group .*/Group www/" $HTTPD_PATH/conf/httpd.conf
    echo -e "application/x-httpd-php\t\t\t\tphp" >> $HTTPD_PATH/conf/mime.types
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
}

# Install php ext
install_ext () {
    # memcache ext
    # redis ext
    # imagick ext
    mkdir -p $PHP_PATH/etc/php.d
    echo "no ext..."
}

# Install php
install_php () {
    # install libs for php
    install_libs
    # install php
    tar -xjf $PWD_PATH/tarballs/php-5.4.4.tar.bz2 -C /usr/local/src
    cd /usr/local/src/php-5.4.4
    ./configure --prefix=$PHP_PATH --with-config-file-path=$PHP_PATH/etc --with-config-file-scan-dir=$PHP_PATH/etc/php.d --with-apxs2=$HTTPD_PATH/bin/apxs --with-iconv-dir=/usr/local --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --with-curlwrappers --enable-mbregex --enable-mbstring --with-mcrypt --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --enable-gd-native-ttf --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --enable-mysqlnd --with-pdo-mysql=mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-zlib 
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
    # install ext
    install_ext
    # symbolic link
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
    $MYSQL_PATH/scripts/mysql_install_db --user=mysql --basedir=$MYSQL_PATH --datadir=$MYSQL_DATA_PATH --defaults-file=/etc/my.cnf
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

# Install mysql5.5
install_mysql () {
    prepare_mysql
    tar -xzf $PWD_PATH/tarballs/Percona-Server-5.5.30-rel30.1.tar.gz -C /usr/local/src
    cd /usr/local/src/Percona-Server-5.5.30-rel30.1
    cmake . -DMYSQL_DATADIR=$MYSQL_DATA_PATH -DCMAKE_INSTALL_PREFIX=$MYSQL_PATH -DDEFAULT_CHARSET=utf8 -DWITH_EXTRA_CHARSETS=complex -DWITH_SSL=yes -DDEFAULT_COLLATION=utf8_general_ci
    make -j $CORE_NUM && make install
    finish_mysql
}

# Start LAMP...
install_deps
for app in $@; do
    install_$app
done

# src
chown -R root:root /usr/local/src

# Congratulation
echo "Congratulation! all done."
