#!/bin/bash
##这个脚本是单间一天新的DNS服务器，提供两个域名解析，每个域名对应一个IP
rpm -q bind &>/dev/null
[ $? -eq 0 ] || yum -y install bind &>/dev/null && echo "bind service installtion successful"
##该函数执行会搭建一个新的DNS服务器
bind_funcation () {
read -p "请输入视图1的名称(php)：" view1_name
read -p "请输入视图1需要解析的域名的名称如（php-f2.com）：" view1_domain
read -p "请输入视图2的名称(jsp)：" view2_name
read -p "请输入视图2需要解析的域名的名称如（jsp-f2.com）：" view2_domain
##只有两个视图 对应 单个IP
view1_ip=192.168.3.100 				   ##网站的IP www.php-f2.com --->192.168.3.100	
view2_ip=172.25.254.100   			   ##网站的IP www.php-f2.com --->172.25.254.100	
view1_clients=192.168.3.0/24			   ##视图1提供那个网段的域名解析	
view2_clients=172.25.254.0/24			   ##视图2提供那个网段的域名解析	
DNS_IP=`ifconfig  | grep  "bro" |awk '{print $2}'` ##DNS服务器的IP
##修改主配置文件添加了两个视图
cat >/etc/named.conf <<EOF
include "/etc/${view1_name}.cfg";
include "/etc/${view2_name}.cfg";
options {
        listen-on port 53 {  any; };
#       listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        allow-query     {  any; };
        recursion yes;
        dnssec-enable yes;
        dnssec-validation yes;
        bindkeys-file "/etc/named.iscdlv.key";
        managed-keys-directory "/var/named/dynamic";
        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};
view  "${view1_name}" {
   match-clients { $view1_name; };
   zone "." IN {
        type hint;
        file "named.ca";
};
   zone "$view1_domain" IN {
          type master;
          file "${view1_domain}.zone";
};
include "/etc/named.rfc1912.zones";
};
view  "$view2_name" {
   match-clients { $view2_name; };
   zone "." IN {
        type hint;
        file "named.ca";
};
   zone "$view2_domain" IN {
          type master;
          file "${view2_domain}.zone";
};
include "/etc/named.rfc1912.zones";
};
include "/etc/named.root.key";
EOF
##添加zone文件
cat >/var/named/${view1_domain}.zone <<EOF
\$TTL 1D
@       IN SOA  ns1.${view1_domain}.  rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.${view1_domain}.
ns1     A       $DNS_IP
www     A       $view1_ip
EOF

cat >/var/named/${view2_domain}.zone <<EOF
\$TTL 1D
@       IN SOA  ns1.${view2_domain}.  rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.${view2_domain}.
ns1     A       $DNS_IP
www     A       $view2_ip
EOF
##更改文件属性
cd /var/named  && chown named. ./*
##添加acl控制列表
cat >/etc/${view1_name}.cfg <<EOF
acl "$view1_name" {
	 $view1_clients;
};
EOF
cat >/etc/${view2_name}.cfg <<EOF
acl "$view2_name" {
	 $view2_clients;
};
EOF
##检测语法
named-checkconf &>/dev/null
[ $? -eq 0 ] && echo "bind的主配置文件没问题" || exit
named-checkzone $view1_domain /var/named/${view1_domain}.zone &>/dev/null
[ $? -eq 0 ] && echo "view1配置文件没问题" || exit
named-checkzone $view2_domain /var/named/${view2_domain}.zone &>/dev/null
[ $? -eq 0 ] && echo "view2配置文件没问题" || exit
##启动服务
systemctl restart named &>/dev/null && systemctl enable named &>/dev/null
ss -ntupl |grep :53 &>/dev/null
[ $? -eq 0 ] || echo "服务启动失败"
}
##该函数执行会在原有的基础上搭建bind的主从服务器
bind_cs_funcation() {
read -p "请输入你从服务器的IP地址：" sip
rpm -q bind &>/dev/null
[ $? -eq 0 ] || yum -y install bind &>/dev/null && echo "bind service installtion successful"
rpm -q rsync &>/dev/null
[ $? -eq 0 ] || yum -y install rsync  &>/dev/null && echo "rsync service installtion successful"
##利用rsync把配置问同步过去 实现先生成密钥对
ssh root@$sip "yum -y install rsync"
rsync /etc/named.conf $sip:/etc/
rsync /var/named/     $sip:/var/
ssh root@$sip "sed -i 's/master/slave/pg' /etc/named.conf "
ssh root@$sip "chow named. /var/named/ -R"
}
a[1]=bind_funcation
a[2]=bind_cs_funcation
a[3]=exit

select i in ${a[*]}
   do
	$i
done	
