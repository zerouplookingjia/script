#!/bin/bash

read -p "请输入网站的域名如（www.jsp.com）:" domain
host=`echo $domain | awk -F. '{print $2"."$3}'`
dbuser=runjisp
dbpasswd=123456
dbname=jsp
dbip=192.168.3.34
##装包
cd /root/UP200_tomcat-master/pkg/
##搭建java环境，安装jdk包
tar xf jdk-7u15-linux-x64.tar.gz -C /opt/ &&  mv /opt/jdk1.7.0_15/ /opt/java
tar xf mysql-connector-java-5.1.36.tar.gz  -C /tmp
##安装tomact
mkdir -p /usr/local/tomcat && tar -xf apache-tomcat-8.0.24.tar.gz  -C /usr/local/tomcat
##jsvc方式启动：采用root+tomcat用户的方式启动服务
 groupadd -g 888 tomcat &&  useradd -g 888 -u 888 tomcat -s /sbin/nologin
##进入tomcat命令所在位置（包含状态控制脚本）
cd /usr/local/tomcat/apache-tomcat-8.0.24/bin/
tar -xf commons-daemon-native.tar.gz &&  cd commons-daemon-1.0.15-native-src/unix/
#编译安装jsvc文件，并将jsvc文件存放至tomcat服务主目录下的bin目录下
yum -y install gcc &>/dev/null ##解决依赖
./configure  --with-java=/opt/java &>/dev/null || exit && echo "配置成功"
make &>/dev/null || exit && echo "make 成功"
cp -a jsvc  /usr/local/tomcat/apache-tomcat-8.0.24/bin/
##优化tomcat命令，jsvc的方式启动实际执行的脚本为bin目录下的daemon.sh
cp  /usr/local/tomcat/apache-tomcat-8.0.24/bin/daemon.sh  /etc/init.d/tomcat
##修改启动脚本
sed -i "1a # chkconfig: 2345 30 20" /etc/init.d/tomcat
sed -i "22a CATALINA_HOME=/usr/local/tomcat/apache-tomcat-8.0.24" /etc/init.d/tomcat
sed -i "23a CATALINA_BASE=/usr/local/tomcat/apache-tomcat-8.0.24" /etc/init.d/tomcat
sed -i "24a JAVA_HOME=/opt/java/" /etc/init.d/tomcat
chmod +x /etc/init.d/tomcat
chkconfig --add tomcat
chown tomcat.tomcat -R /usr/local/tomcat/apache-tomcat-8.0.24/
service tomcat start 
ss -ntupl |grep  80 &>/dev/null || exit
sed -i -e "123 s/localhost/$domain/" -e "s/webapps/$host/" /usr/local/tomcat/apache-tomcat-8.0.24/conf/server.xml 
sed -i "136 s/localhost_access_log/${host}_access_log/" /usr/local/tomcat/apache-tomcat-8.0.24/conf/server.xml

mkdir -p /usr/local/tomcat/apache-tomcat-8.0.24/$host/ROOT
cp /tmp/mysql-connector-java-5.1.36/mysql-connector-java-5.1.36-bin.jar  /usr/local/tomcat/apache-tomcat-8.0.24/lib/
cd /root/UP200_tomcat-master/other
yum -y install unzip &>/dev/null
unzip ejforum-2.3.zip  -d /tmp/
cp  -r /tmp/ejforum-2.3/ejforum/* /usr/local/tomcat/apache-tomcat-8.0.24/$host/ROOT/
sed -i '3 s/-->//'/usr/local/tomcat/apache-tomcat-8.0.24/jsp.com/ROOT/WEB-INF/conf/config.xml
sed -i '10 s#<!--  DB Connection Pool - Mysql#DB Connection Pool - Mysql -->#' config.xml 
sed -i '16 s/-->//'/usr/local/tomcat/apache-tomcat-8.0.24/jsp.com/ROOT/WEB-INF/conf/config.xml
sed -i  -e "12 s/{USERNAME}/$dbuser/" -e "s/{PASSWORD}/$dbpasswd/"/usr/local/tomcat/apache-tomcat-8.0.24/jsp.com/ROOT/WEB-INF/conf/config.xml
sed -i  -e "14 s/localhost/$dbip/"  -e "s/{DATABASE}/$dbname/"/usr/local/tomcat/apache-tomcat-8.0.24/jsp.com/ROOT/WEB-INF/conf/config.xml
##配置数据库
yum -y install mariadb mariadb-server &>/dev/null || exit
systemctl start mariadb && systemctl enable mariadb &>/dev/null
mysqladmin create $dbname || exit
cd /tmp/ejforum-2.3/install/script/
mysql $dbname < easyjforum_mysql.sql  || exit
mysql <<EOF
delete from mysql.user where user='';
delete from mysql.db where user='';
grant all on $dbname.* to $dbuser@'%' identified by '$dbpasswd';
flush privileges;
EOF
chown tomcat. -R  /usr/local/tomcat/apache-tomcat-8.0.24/
service tomcat stop 
service tomcat start







