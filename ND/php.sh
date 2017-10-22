#!/bin/bash
##快速搭建一个php的论坛 LNMP
fastcgi_script_name=fastcgi_script_name
read -p "请输入你论坛的名字如（bbs.com）" name 
read -p "请输入你数据库的密码如 : " mypasswd 
read -p "请输入数据库的授权用户：" user
read -p "请输入数据库的授权用户：" passwd

##装包
rpm -ivh nginx-1.8.1-1.el7.ngx.x86_64.rpm &>/dev/null && echo "success"
rpm -ivh spawn-fcgi-1.6.3-5.el7.x86_64.rpm &>/dev/null && echo "success"
yum -y install php php-mysql mariadb-server &>/dev/null && echo "success"
##配置
cat >/etc/nginx/conf.d/$name <<EOF
server {
       listen 80;
       server_name www.$name;
       root /usr/share/nginx/$name;
       index index.php index.html index.htm;
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;   
 	    fastcgi_index index.php;
	    fastcgi_param SCRIPT_FILENAME /usr/share/nginx/bbs.com\$$fastcgi_script_name;
	    include fastcgi_params;
     }
}
EOF
mkdir -p /usr/share/nginx/$name
ulimt 65536
systemctl restart nginx
##配置spawn-fcgi
sed -i '8a OPTIONS="-u nginx -g nginx -p 9000 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"' /etc/sysconfig/spawn-fcgi
systemctl start spawn-fcgi && systemctl enable spawn-fcgi
##数据库初始化
systemctl start mariadb.service && systemctl enable mariadb.service 
mysqladmin -u root password "$mypasswd"
rpm -q unzip &>/dev/null || yum -y install unzip &>/dev/null
unzip Discuz_X3.2_SC_UTF8.zip -d /tmp
cp -r  /tmp/upload/* /usr/share/nginx/$name
chown  -R  nginx. /usr/share/ngninx/$name 
##数据库授权
mysql -uroot -p$mypasswd <<eof
delete from mysql.user where user='';
delete from mysql.db where user='';
create database bbs;
grant all on bbs.* to $user@'%' identified by '$passwd';
flush privileges;
eof

