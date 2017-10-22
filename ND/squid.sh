#!/bin/bash
##搭建一台代理缓存服务器 nginx(80)-->tomcat(8080)
read -p "请输入你要代理的域名如（www.abc.com）:" domain
read -p "请输入你要代理的域名的IP:" ip

rpm -q squid &>/dev/null || yum -y install squid && echo "success"
##配置
sed -i "7a  http_access allow  all" /etc/squid/squid.conf
sed -i "s/^http_port.*/http_port 3128 accel vhost vport/" /etc/squid/squid.conf   #支持反向代理 开启代理跳转80--->8080
sed -i "s/^cache_dir.*/cache_dir ufs /var/spool/squid 100 16 256/" /etc/squid/squid.conf
sed -i "s/^coredump_dir.*/coredump_dir /var/spool/squid" /etc/squid/squid.conf
sed -i "67a cache_peer $ip  parent 8080 0 no-query originserver name=web" /etc/squid/squid.conf
sed -i "68a cache_peer_domain web $domain" /etc/squid/squid.conf
sed -i "69c cache_peer_domain web $ip" /etc/squid/squid.conf
systemctl start squid && systemctl enable squid &>/dev/null
ss -ntupl | grep :3128 &>/dev/null
[ $? -eq 0 ] || echo "service error"
