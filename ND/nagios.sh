#!/bin/bash
#安装包
#先进入rpm包的目录
nagios_passwd=123456
cd /root/pkg
yum -y localinstall *.rpm
htpasswd -cmb /etc/nagios/passwd  nagiosadmin $nagios_passwd &>/dev/null
###监控本机
sed -i "s/localhost/$HOSTNAME/" /etc/nagios/objects/localhost.cfg 
nagios -v /etc/nagios/nagios.cfg &>/dev/null || exit
