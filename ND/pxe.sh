#!/bin/bash
##国庆节补交作业
##第一步准备环境
setenforce 0 &>/dev/null
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
systemctl stop firewalld && systemctl disable firewalld &>/dev/null
rpm -q nfs-utils &>/dev/null
  [ $? -eq 0 ] || yum -y install nfs-utils &>/dev/null && echo "nfs-utils installtion successful!"
mkdir -p /rhel6u5
mount -t nfs 172.25.2.112:/iso/rhel6u5  /rhel6u5

##第二部搭建DHCP服务器
echo "nameserver 172.25.2.200">>/etc/resolv.conf
##安装
rpm -q dhcp &>/dev/null
   if [ $? -ne 0  ];then
       yum install -y dhcp  &>/dev/null && echo "dhcp sevice installtion successful!"
   fi
###配置
DNS=`cat /etc/resolv.conf |grep '^nameserver' |awk '{print $2}'`    #read -p "请输入DNS服务器的IP :" DNS
DHCP=`ifconfig |  grep 'bro' |awk '{print $2}'`			    #read -p "请输入DHCP服务器的IP:" DHCP	
NETWORK=$(echo $DHCP |awk -F"." '{print $1"."$2"."$3"."0}')         #read -p "请输入DHCP分配的网段如（192.168.3.0）：" NETWORK
MASK=`ifconfig |  grep 'bro' |awk '{print $4}'`			    #read -p "请输入DHCP分配的网段的掩码如（255.255.255.0) ：" MASK
Broadcast=`ifconfig |  grep 'bro' |awk '{print $6}'`                #read -p "请输入你分配的地址的广播地址（255）：" BRO
GATEWAY=$(echo $DHCP |awk -F"." '{print $1"."$2"."$3"."254}')       #read -p "请输入你的网关如（254）：" GAT
read -p "请输入你要分配的地址段($(echo 你的DHCP服务器的地址是$DHCP)):" segment  ###分配的地址段
cat >/etc/dhcp/dhcpd.conf <<EOF
allow booting;
allow bootp;
log-facility local7;
subnet ${NETWORK} netmask ${MASK} {
  range ${segment};
  option domain-name-servers ${DNS};
  option domain-name "internal.example.org";
  option routers ${GATEWAY};
  option broadcast-address ${Broadcast};
  default-lease-time 600;
  max-lease-time 7200;
  next-server $DHCP;
  filename "pxelinux.0";
}
EOF

###启动
systemctl  restart dhcpd &&  systemctl enable dhcpd
ss -ntupl |grep :67 &>/dev/null
    [ $? -eq 0 ]  &&  echo "服务配置成功" || exit

##第三步：搭建TFTP让客户据下载vmlinuz核心文件和initrd内核
rpm -q tftp-server &>/dev/null
   [ $? -eq 0 ] || yum -y install tftp-server &>/dev/null && echo "tftp service installtion successful!"
rpm -q xinetd  &>/dev/null
   [ $? -eq 0 ] || yum -y install xinetd  &>/dev/null && echo "tftp service installtion successful!"
rpm -q syslinux &>/dev/null
   [ $? -eq 0 ] || yum -y install syslinux &>/dev/null && echo "syslinux service installtion successful!" ###生成内核文件
cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/pxelinux.cfg
###生成标签文件
cat >/var/lib/tftpboot/pxelinux.cfg/default <<EOF
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff

label install rhel7
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://$DHCP/myks.cfg

label install rhel6
        menu label Install rhel6
        kernel rhel6u5/vmlinuz
        append initrd=rhel6u5/initrd.img ks=http://$DHCP/rhel6u5_ks.cfg
EOF
cd /mnt/isolinux
\cp splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/   ##拷贝rhel7的核心文件到tftp的家目录下
mkdir -p /var/lib/tftpboot/rhel6u5
cd /rhel6u5/isolinux
\cp vmlinuz initrd.img /var/lib/tftpboot/rhel6u5/  ##拷贝rhel6u的核心文件到tftp家目录下的rhel6u5的文件夹中
sed -i "s/disable.*/disable\t\t\t= no/" /etc/xinetd.d/tftp
systemctl restart xinetd && systemctl enable xinetd &>/dev/null
netstat -unlp |grep :69 &>/dev/null
  [ $? -eq 0 ]||exit

##第五步：安装httpd服务 发布ks和iso镜像
rpm -q httpd &>/dev/null
 [ $? -eq 0 ] || yum -y install httpd &>/dev/null && echo "httpd service installtion successful!"
##生成rhel7u2的lks文件
cat >/var/www/html/myks.cfg <<EOF
#platform=x86, AMD64, 或 Intel EM64T
#version=DEVEL
# Install OS instead of upgrade
install
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --iscrypted $1$raEx373S$GedDnDSSUSwMDRgcUfSVU.
# System timezone
timezone Asia/Shanghai --isUtc
# Use network installation
url --url="http://$DHCP/rhel7u2"
# System language
lang en_US
# Firewall configuration
firewall --disabled
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# SELinux configuration
selinux --disabled
# Network information
network  --bootproto=dhcp --device=eno16777736
# Reboot after installation
reboot
# System bootloader configuration
bootloader --append="selinux=0" --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part /boot --fstype="xfs" --size=200
part / --fstype="xfs" --size=10000
part swap --fstype="swap" --size=1024
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
cat >/etc/yum.repos.d/server.repo  <<EOT
[server]
name=servreu7u2
baseurl=ftp://172.25.254.112/rhel7u2
enabled=1
gpgcheck=0

[rhel6u5]
name=servre6u5
baseurl=ftp://172.25.254.112/rhel6u5
enabled=1
gpgcheck=0
EOT
%end

%packages
@core
%end
EOF
###生成rhel6u5的ks文件
cat >/var/www/html/rhel6u5_ks.cfg <<EOF
#platform=x86, AMD64, 或 Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://${DHCP}/rhel6u5"
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
ln -s /mnt/	/var/www/html/rhel7u2
ln -s /rhel6u5/  /var/www/html/rhel6u5
systemctl restart httpd  && systemctl enable httpd
ss -ntupl |grep :80
    [ $? -eq 0 ]  &&  echo "服务启动成功" || exit

