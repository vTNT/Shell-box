#!/bin/bash
#install cacti scripts
#linyd 2012.11.13
path=`pwd`
#web安装存放数据的具体位置
apachepath='/usr/local/nginx/html'
#主机IP，如果是双网卡，则请写上具体IP
host=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
cacti () {
yum install gcc gcc-c++ make automake autoconf -y 
yum install libpcap libpcap-devel libpng gdbm gdbm-devel glib libxml2-devel pango pango-devel gd -y
yum install net-snmp net-snmp-libs net-snmp-utils -y 
cd $path/rpm
rpm -ivh rrdtool-php-1.2.27-3.el5.x86_64.rpm --force --nodeps
cd ..
yum localinstall -y --nogpgcheck rrdtool-*
chkconfig --add snmpd 
chkconfig snmpd on
tar -zxvf cacti-0.8.8a.tar.gz  -C /usr/local/nginx/html
mv $apachepath/cacti-0.8.8a/ /usr/local/nginx/html/cacti
read -p "请输入本地mysql的密码: " mysqlpwd
read -p "请输入cacti用户在mysql中想设置的密码:" cactipwd
mysql -uroot -p$mysqlpwd -e "create database cacti;"
mysql -uroot -p$mysqlpwd -e "grant all on cacti.* to 'cacti'@'localhost' identified by '$cactipwd';"
mysql -uroot -p$mysqlpwd -e "flush privileges;"
cd $apachepath/cacti
useradd -r cacti -s /bin/nologin
mysql -ucacti -p$cactipwd cacti < cacti.sql
chown -R cacti $apachepath/cacti/rra
chown -R cacti $apachepath/cacti/log
sed -i 's#\$database_username = .*#\$database_username = "cacti";#' $apachepath/cacti/include/config.php
sed -i 's/\$database_password = .*/\$database_password = "'$cactipwd'";/' $apachepath/cacti/include/config.php
echo "请将下列相关信息输入到各自的文件中："
echo "*/1 * * * * /usr/local/php/bin/php $apachepath/cacti/poller.php > /dev/null 2>&1" > $path/cron
cat $path/cron
echo "请调整在snmpd.conf中 at 42,62,85的设置"
}
plugins () {
cd $path
cd $apachepath/cacti
read -p "请输入cacti用户在mysql中的密码:" cactipwd
sed -i 's#\$database_port = .*#&\n\$plugins = array();#' $apachepath/cacti/include/config.php
sed -i 's#\$database_port = .*#&\n\$url_path = "/cacti/";#' $apachepath/cacti/include/config.php
cd $path
yum -y install net-snmp-devel 
tar -zxvf cacti-spine-0.8.8a.tar.gz
cd cacti-spine-0.8.8a
./configure --prefix=/usr/local/spine
make
make install
cd /usr/local/spine/etc
cp spine.conf.dist spine.conf
sed -i 's/DB_User.*/DB_User         cacti/' /usr/local/spine/etc/spine.conf
sed -i 's/DB_Pass.*/DB_Pass        '$cactipwd'/' /usr/local/spine/etc/spine.conf
cp /usr/local/spine/etc/spine.conf /etc
echo "#######################"
echo "下列显示spine的状态："
/usr/local/spine/bin/spine
} 
addplugins () {
cd $path
tar -zxvf thold-v0.4.9-3.tgz
tar -zxvf monitor-v1.3-1.tgz
tar -zxvf settings-v0.71-1.tgz
mv monitor $apachepath/cacti/plugins
mv settings $apachepath/cacti/plugins
mv thold $apachepath/cacti/plugins
unzip php-weathermap-0.97a.zip
mv weathermap $apachepath/cacti/plugins
cd $apachepath/cacti/plugins/weathermap/
sed -i 's/^\$ENABLED.*/\$ENABLED=true;/' $apachepath/cacti/plugins/weathermap/editor.php
chown cacti $apachepath/cacti/plugins/weathermap/configs
chmod 777 $apachepath/cacti/plugins/weathermap/configs
cd $apachepath/cacti/plugins/weathermap
cp editor-config.php-dist editor-config.php
sed -i "s#^\$cacti_base.*#\$cacti_base = '$apachepath/cacti';#" $apachepath/cacti/plugins/weathermap/editor-config.php
sed -i "s#^\$cacti_url.*#\$cacti_url = \"http:\/\/$host\/cacti\/\";#" $apachepath/cacti/plugins/weathermap/editor-config.php
sed -i "s#^\$mapdir.*#\$mapdir='$apachepath\/cacti\/plugins\/weathermap\/configs';#" $apachepath/cacti/plugins/weathermap/editor-config.php

}

read_number ()
{
echo -e "请输入下列选项：\n###1:安装cacti环境\n###2:安装插件支持与spine\n###3:安装基本插件\n"
read number
case $number in 1)
cacti;;
2)
plugins;;
3)
addplugins;;
*)
echo "请重新输入："
read_number;;
esac
 }
read_number
