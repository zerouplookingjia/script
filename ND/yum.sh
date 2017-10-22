#!/bin/bash
##快速配置yum源
iso_IP=172.25.2.112
ping -c 3 $iso_IP &>/dev/null && rm -rf /etc/yum.repos.d/*
ping -c 3 8.8.8.8 &>/dev/null 
if [ $? -eq 0 ];then
cat >/etc/yum.repos.d/network.repo <<EOF
[aly]
baseurl=https://mirrors.aliyun.com/centos/7/os/x86_64
gpgcheck=0
[epel]
baseurl=https://mirrors.aliyun.com/epel/7Server/x86_64/
gpgcheck=0
EOF
echo "nameserver 223.5.5.5" >> /etc/resolv.conf 
fi

cat >/etc/yum.repos.d/network.repo <<EOF
[rhel7u2]
baseurl=http://$iso_IP/rhel7u2
gpgcheck=0
[rhel6u5]
baseurl=http://$iso_IP/rhel6u5
gpgcheck=0
[rhel7u1]
baseurl=http://$iso_IP/rhel7u1
gpgcheck=0
EOF

yum clean all &>/dev/null && yum repolist >/dev/null && echo "yum源配置成功"
