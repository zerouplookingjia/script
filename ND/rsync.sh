#!/bin/bash
##该脚本是搭建rsync服务器 -->sysrsync+sync
sersync=sersync2.5.4_64bit_binary_stable_final.tar.gz
sersync_ip=`ifconfig |grep "bro" |awk '{print $2}'`
read -p "请输入你服务器端要同步的目录如（/mnt）只能是一级目录:" sdir
read -p "请输入你客户端要同步的目录如（/mnt）只能是一级目录:" cdir
read -p "请输入你允许同步的IP：" ip
read -p "请输入你允许同步的用户：" user
read -p "请输入你允许同步的用户的密码：" passwd
rpm -q rsync || yum -y install rsync &>/dev/null &>/dev/null
mkdir -p $sdir
tar -xzf $sersync -C /opt
mv /opt/GNU-Linux-x86/  /opt/sersync
sed -i "24 s#/opt/tongbu#$sdir#" /opt/sersync/confxml.xml 
sed -i -e "25 s#127.0.0.1#$ip#" -e "s#tongbu1#$sdir#" /opt/sersync/confxml.xml 
sed -i -e "31 s/false/true/" -e "s/root/$user/" /opt/sersync/confxml.xml
echo $passwd >/etc/rsync.pas
chmod 600 /etc/rsync.pas
##sync客户端
ssh root@$ip "
cat >/etc/rsyncd.conf <<EOF
uid = root
gid = root
use chroot = yes
max connections = 3306
pid file = /var/run/rsyncd.pid
log file = /var/log/rsyncd.log
lock file = /var/run/rsync.lock
exclude = lost+found/
transfer logging = yes
timeout = 900
ignore nonreadable = yes
dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2 *.iso
port 873
address=$ip
hosts allow=$sersync_ip/24

[php]
        path = $cdir
        ignore errors = yes
        read only = no
        auth users = $user
        secrets file = /etc/rsyncd_user.db
EOF
cat >/etc/rsyncd_user.db <<EOF
$user:$passwd
EOF
"
cd /opt/sersync
./sersync2  -d -r -n -12 -o ./confxml.xml 
[ $? -eq 0 ] || echo "同步失败"
