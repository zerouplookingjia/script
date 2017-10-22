#!/bin/bash
echo "nameserver 172.25.2.200">>/etc/resolv.conf
cat >/etc/sysconfig/network-scripts/ifcfg-eno16777736 <<EOF
TYPE=Ethernet
BOOTPROTO=none
NAME=eno16777736
DEVICE=eno16777736
ONBOOT=yes
IPADDR=192.168.3.19
PREFIX=24
GATEWAY=192.168.3.1
EOF
systemctl stop  network && systemctl start network
ping -c 3 8.8.8.8 &>/dev/null;[ $? -eq 0 ] || exit
cobip=`ifconfig |grep  "bro" |awk '{print $2}'`
DNS=`cat /etc/resolv.conf |grep '^nameserver' |awk '{print $2}'`
NETWORK=$(echo $cobip |awk -F"." '{print $1"."$2"."$3"."0}')
MASK=`ifconfig |  grep 'bro' |awk '{print $4}'`		
GATEWAY=$(echo $cobip |awk -F"." '{print $1"."$2"."$3"."254}')
read -p "请输入你要分配的地址段($(echo 你的cobbler服务器的地址是$cobip)):" segment  ###分配的地址段
##第一步：搭建环境
setenforce 0 &>/dev/null
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
systemctl stop firewalld && systemctl disable firewalld &>/dev/null
rpm -q httpd &>/dev/null
   [ $? -eq 0 ] || yum -y install httpd &>/dev/null
rpm -q tftp-server &>/dev/null
   [ $? -eq 0 ] || yum -y install tftp-server &>/dev/null && echo "tftp service installtion successful"
rpm -q xinetd  &>/dev/null
   [ $? -eq 0 ] || yum -y install xinetd  &>/dev/null && echo "xinetd service installtion successful"
##第二步安装cobbler软件包
rpm -q wget &>/dev/null;[ $? -eq 0 ]|| yum -y install wget &>/dev/null
#wget -r -c  ftp://192.168.3.112/cobbler_rhel7/  &>/dev/null && echo "cobbler 包下载完成"
#mv /root/192.168.3.112/cobbler_rhel7 /cobbler
###cat支持追加 （cat >>1.txt <<EOF ）###
cat >/etc/yum.repos.d/server.repo <<EOF   
[server]
name=server.repo
baseurl=file:///mnt
gpgcheck=0
[aly]
baseurl=https://mirrors.aliyun.com/centos/7/os/x86_64
gpgcheck=0
[epel]
baseurl=https://mirrors.aliyun.com/epel/7Server/x86_64/
gpgcheck=0
EOF
yum clean all &>/dev/null && yum repolist &>/dev/null  
cd /cobbler
rpm -ivh python2-simplejson-3.10.0-1.el7.x86_64.rpm 
rpm -ivh python-django-1.6.11.6-1.el7.noarch.rpm python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm
yum -y localinstall cobbler-2.8.1-2.el7.x86_64.rpm cobbler-web-2.8.1-2.el7.noarch.rpm ##需要用到aly 或 epel的yum源

systemctl start cobblerd &>/dev/null && systemctl enable cobblerd &>/dev/null
  ss -ntupl |grep  cobblerd &>/dev/null;[ $? -eq 0 ]|| exit && echo "cobblerd service installtion successful"
systemctl start httpd &>/dev/null  && systemctl enable httpd &>/dev/null
  ss -ntupl |grep  httpd &>/dev/null;[ $? -eq 0 ]|| exit && echo "httpd  service installtion successful"
##cobbler check 需要解决的问题
sed -i  "384c server: ${cobip}" /etc/cobbler/settings	    ##指定cobbler服务器的IP	
sed -i  "272c next_server: ${cobip}" /etc/cobbler/settings  ##指定文件服务器 是本机
sed -i "s/disable.*/disable\t\t\t= no/" /etc/xinetd.d/tftp  ##开启tftp的托管服务
rpm -q syslinux &>/dev/null;[ $? -eq 0 ] || yum -y install syslinux &>/dev/null && echo "syslinux installtion successful"  ###提供网络引导文件
systemctl  start rsyncd &>/dev/null && systemctl  enable rsyncd &>/dev/null  ###同步服务
  netstat -tnlp |grep :873 &>/dev/null;[ $? -eq 0 ]||exit
rpm -q pykickstart &>/dev/null;[ $? -eq 0 ] || yum -y install pykickstart &>/dev/null ##一种kickstart工具
sed -i  '101c default_password_crypted: "$1$random-p$MvGDzDfse5HkTwXB2OLNb."' /etc/cobbler/settings ###设置root用户的密码变量openssl passwd -1 -salt 'random-phrase-here' 'redhat'
rpm -q fence-agents &>/dev/null;[ $? -eq 0 ] || yum -y install fence-agents &>/dev/null ##一种远程开关电源软件
##第三部：导入镜像
#Cobbler配置主要位置：/var/lib/cobbler/
#snippets代码的位置：/var/lib/cobbler/snippets/
#Kickstart模板的位置: /var/lib/cobbler/kickstarts/
#默认使用的ks文件: /var/lib/cobbler/kickstarts/default.ks
#安装源镜像的位置: /var/www/cobbler/ks_mirror/ 
cobbler import --path=/mnt/ --name=rhel-server-7.2-base --arch=x86_64 &>/dev/null;[ $? -eq 0 ] || exit && echo "cobbler 导入镜像成功0v0"
##第四步:让cobbler来管理dhcp，并进行cobbler配置同步
rpm -q dhcp &>/dev/null;[ $? -eq 0 ] || yum -y install dhcp &>/dev/null && echo "dhcp service installtion successful"
sed -i "21c subnet ${NETWORK} netmask ${MASK} {" /etc/cobbler/dhcp.template 
sed -i "22c      option routers             ${GATEWAY};" /etc/cobbler/dhcp.template
sed -i "23c      option domain-name-servers ${DNS};" /etc/cobbler/dhcp.template
sed -i "24c      option subnet-mask         ${MASK};" /etc/cobbler/dhcp.template
sed -i "25c      range dynamic-bootp        ${segment};" /etc/cobbler/dhcp.template
sed -i "242c manage_dhcp: 1" /etc/cobbler/settings	    ##开启dhcp
systemctl restart cobblerd &>/dev/null
ss -ntupl |grep  cobblerd &>/dev/null


##第四步：测试
rpm -q expect &>/dev/null;[ $? -eq 0 ] || yum -y install expect &>/dev/null
passwd=1
keydir=/root/.ssh
skey=$keydir/id_rsa
pkey=$keydir/id_rsa.pub
[ -f $skey -a -f $pkey ] || $(ssh-keygen -q  -f $skey -N "")
expect <<EOF
 	spawn ssh-copy-id root@localhost
	  expect {
	    "*(yes/no)?" { send "yes\r";exp_continue }
	    "*password:" { send "${passwd}\r";exp_continue }	
	   eof{exit}	
	  }
EOF
ssh root@localhost"cobbler sync"
systemctl restart xinetd && systemctl enable xinetd &>/dev/null
systemctl restart dhcpd && systemctl enable dhcpd &>/dev/null
[ $? -eq 0 ] || exit && echo "xinetd 启动成功"
expect <<EOF
	spawn htdigest /etc/cobbler/users.digest "Cobbler" abc
	  expect {
	    "*password:" { send "123456\r";exp_continue }
           eof{exit}
	  }	
EOF
###扩展装rhel6u5系统
##方法一：直接导入镜像
mkdir -p /rhel6u5
rpm -q nfs-utils &>/dev/null;[ $? -eq 0 ] || yum -y install nfs-utils &>/dev/null
mount -t nfs 192.168.3.112:/iso/rhel6u5 /rhel6u5
cobbler import --path=/rhel6u5/ --name=rhel-server-6.5-base --arch=x86_64 &>/dev/null;[ $? -eq 0 ] || exit && echo "cobbler 导入镜像成功0v0"
##方法二：发布ks文件 （不会做。。。）
no_nono(){
cat >/var/lib/cobbler/kickstarts/rhel6u5_ks.cfg <<EOF
#platform=x86, AMD64, 或 Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://${cobip}/rhel6u5"
# Root password
rootpw --iscrypted $1$um2dWLju$M4Yr.nIWQNQs/Ye3gdGnz1
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --append="selinux=0" --location=mbr --md5pass="$1$1TSDT.RP$Y6ESEsyBDz2r8u0u6HdB41"
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part swap --fstype="swap" --size=1024
part / --fstype="ext4" --size=10000

%pre
clearpart --all --initabel
part /boot --fstype ext4 --size=100
part pv.100000 --size=10000
part swap --size=512
volgroup vg --pesize=32768 pv.100000
logvol /home --fstype ext4 --name=lv_home --vgname=vg --size=480
logvol / --fstype ext4 --name=lv_root --vgname=vg --size=8192
%end

%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
cat >/etc/yum.repos.d/server.repo  <<EOT
[server]
name=servreu7u2
baseurl=ftp://172.25.2.112/rhel7u2
enabled=1
gpgcheck=0

[rhel6u5]
name=servre6u5
baseurl=ftp://172.25.2.112/rhel6u5
enabled=1
gpgcheck=0
EOT
%end

%packages
@base
%end
EOF
cobbler profile add --name=myks1 --distro=rhel-server6u5-base-x86_64 --kickstart=/var/lib/cobbler/kickstarts/rhel6u5_ks.cfg
[root@localhost rhel6u5]# cobbler profile add --name=myks1 --distro=rhel-server6u5-base-x86_64 --kickstart=/var/lib/cobbler/kickstarts/rhel6u5_ks.cfg
exception on server: 'distribution not found'
}
