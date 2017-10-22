#!/bin/bash
##源码编译安装zabbix3.2
dbhost=172.25.2.13
dbname=zabbix
dbuser=zabbix
dbpasswd=123456
zabbix_ip=`ifconfig | grep 'bro' |awk '{print $2}'`
##配置环境 -->配置时间时区
for i in {10..13}
   do
	ssh root@172.25.2.$i "
timedatectl set-timezone Asia/Shanghai;
rpm -q ntpdate  &>/dev/null || yum -y install ntpdate &>/dev/null;
ntpdate 172.25.2.112 &>/dev/null;
"			 
done
yum -y install lftp &>/dev/null
##server安装
lftp 172.25.2.112/project/zabbix  <<eof
mirror zabbix3.2
get simkai.ttf
eof
for i in {11..12}
 do 
	scp -r /root/zabbix3.2  root@172.25.2.$i:/root
	scp  /root/simkai.ttf   root@172.25.2.$i:/root
done
cd /root/zabbix3.2/
tar xf zabbix-3.2.7.tar.gz -C /usr/local/src/
yum -y install gcc gcc-c++ mariadb-devel libxml2-devel net-snmp-devel libcurl-devel &>/dev/null && echo "依赖包安装成功"
 cd /usr/local/src/zabbix-3.2.7/
./configure --prefix=/usr/local/zabbix --enable-server --with-mysql --with-net-snmp --with-libcurl --with-libxml2 --enable-agent --enable-ipv6 &>/dev/null && echo "配置成功" || exit
make &>/dev/null && make install &>/dev/null && echo "make 成功" || exit
useradd zabbix
sed -i  "77 s/# DBHost=localhost/DBHost=$dbhost/"  /usr/local/zabbix/etc/zabbix_server.conf
sed -i "87 s/ DBName=zabbix/ DBName=$dbname/" /usr/local/zabbix/etc/zabbix_server.conf
sed -i "103 s/DBUser=zabbix/DBUser=$dbuser/"/usr/local/zabbix/etc/zabbix_server.conf
sed -i "111 s/# DBPassword=/DBPassword=$dbpasswd/"  /usr/local/zabbix/etc/zabbix_server.conf
##cp sql 文件
scp -r /usr/local/src/zabbix-3.2.7/database/mysql/*  172.25.2.13:/root
##数据库安装初始化
ssh root@$dbhost "
yum -y install mariadb-server mariadb &>/dev/null ||exit;
systemctl start mariadb && systemctl enable mariadb &>/dev/null;
mysql <<EOF
delete from mysql.user where user='';
update mysql.user set password=password('redhat') where user='root';
create database $dbname default charset utf8;
drop database test;
grant  all on $dbname.* to $dbuser@'%' identified by '$dbpasswd';
flush privileges;
EOF
mysql -uroot -predhat $dbname < /root/schema.sql
mysql -uroot -predhat $dbname < /root/images.sql 
mysql -uroot -predhat $dbname < /root/data.sql 
"
#web监控页面 lnmp
ssh root@172.25.2.12 "
cd  /root/zabbix3.2/;
yum -y install httpd php php-mysql &>/dev/null ||exit;
yum -y localinstall php-mbstring-5.4.16-23.el7_0.3.x86_64.rpm php-bcmath-5.4.16-23.el7_0.3.x86_64.rpm &>/dev/null || exit;
yum -y localinstall zabbix-web-3.2.7-1.el7.noarch.rpm zabbix-web-mysql-3.2.7-1.el7.noarch.rpm  &>/dev/null || exit;
sed -i -e '19 s/#//' -e 's#Europe/Riga#Asia/Shanghai#' /etc/httpd/conf.d/zabbix.conf;
yum -y install wqy-microhei-fonts &>/dev/null
cp /root/simkai.ttf /usr/share/zabbix/fonts/
sed -i '35 s/graphfont/simkai/'  /usr/share/zabbix/include/defines.inc.php
sed -i '93 s/graphfont/simkai/'  /usr/share/zabbix/include/defines.inc.php
systemctl restart httpd && systemctl enable httpd;
"
##启动zabbix服务
/usr/local/zabbix/sbin/zabbix_server   
ss -ntupl |grep :10051 &>/dev/null || exit;
##添加一台被监控端
ssh root@172.25.2.11 "
cd /root/zabbix3.2;
rpm -ivh zabbix-agent-3.2.7-1.el7.x86_64.rpm &>/dev/null;
yum -y install net-snmp net-snmp-utils &>/dev/null;
sed -i '95 s/127.0.0.1/$zabbix_ip/' /etc/zabbix/zabbix_agentd.conf 
sed -i '136 s/127.0.0.1/$zabbix_ip/' /etc/zabbix/zabbix_agentd.conf 
sed -i  -e '284 s/#//' -e s'/0/1/' /etc/zabbix/zabbix_agentd.conf
systemctl start zabbix-agent && systemctl enable zabbix-agent 
"
