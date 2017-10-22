#!/bin/bash
##搭建cacti监控脚本；图像化
##搭建lamp+cacti+snmp
dbname=cacti
dbuser=cactidb
dbpasswd=123456
dbhost=localhost
##初始化环境
setenforce 0 $>/dev/null
iptables -F && iptables -t nat -F
yum -y install  net-snmp httpd php php-mysql mariadb mariadb-server  &>/dev/null && echo "success" || exit
yum -y localinstall cacti-0.8.8b-7.el7.noarch.rpm   php-snmp-5.4.16-23.el7_0.3.x86_64.rpm  &>/dev/null && echo "success" ||exit
##配置--->mysql初始化
systemctl restart mariadb 
mysql <<EOF
create database $dbname;
grant all on ${dbname}.* to ${dbuser}@'${dbhost}' identified by '${dbpasswd}';
flush privileges;
EOF
sed -i "29 s/cactiuser/$dbuser/" /etc/cacti/db.php
sed -i "30 s/cactiuser/$dbpasswd/" /etc/cacti/db.php
mysql -u${dbuser} -p${dbpasswd} cacti < /usr/share/doc/cacti-0.8.8b/cacti.sql
##配置cacti
sed -i " 17c Require all granted" /etc/httpd/conf.d/cacti.conf 
##配置时区
sed -i "878c date.timezone = 'Asia/Shanghai'"  /etc/php.ini
##设置计划任务
#echo -n  "*/5 * * * *     cacti   /usr/bin/php /usr/share/cacti/poller.php > /dev/null 2>&1" >/etc/cron.d/cacti
sed -i "s/#//" /etc/cron.d/cacti 
systemctl restart httpd && systemctl enable httpd &>/dev/null
systemctl restart snmpd && systemctl enable snmpd &>/dev/null
