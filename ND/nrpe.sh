#!/bin/bash
##监控端通过 nrpe 来监控 被监控端  编译安装
nagios_passwd=123456
id nagios &>/dev/null  || useradd nagios 
echo $nagios_passwd | passwd --stdin nagios &>/dev/null || exit

rpm -q gcc &>/dev/null || yum -y install gcc &>/dev/null
tar xf nagios-plugins-1.4.14.tar.gz  -C /tmp/ && cd /tmp/nagios-plugins-1.4.14/
./configure &>/dev/null || exit	&& echo "./configure successful"
make &>/dev/null  &>/dev/null || exit && echo "make  successful"
make install  &>/dev/null || exit  && echo "make install successful"
chown  nagios. /usr/local/nagios/
chown  -R  nagios. /usr/local/nagios/libexec/
rpm -q xinetd &>/dev/null || yum -y install xinetd &>/dev/null

rpm -q openssl-devel &>/dev/null || yum -y install openssl-devel &>/dev/null
tar xf /root/nrpe-2.12.tar.gz  -C /tmp/ && cd /tmp/nrpe-2.12/
./configure &>/dev/null || exit && echo "configure successful"
make all &>/dev/null ||exit && echo "make successful"
##创建目录 文件 修改权限 并把他们放到相应的目录
make install-plugin &>/dev/null || exit && echo "install-plugin successful"
make install-daemon &>/dev/null || exit && echo "install-daemon successful"
make install-daemon-config &>/dev/null || exit && echo "daemon-config successful"
make install-xinetd &>/dev/null || exit && echo "install-xinetd successful"
read -p "请输入你监控端的IP：" IP
sed -i "15 s/ 127.0.0.1/ 127.0.0.1 $IP/"  /etc/xinetd.d/nrpe 
echo "nrpe            5666/tcp                #nagios nrpe">>/etc/services
service  xinetd restart &>/dev/null && chkconfig xinetd on &>/dev/null
ss -ntupl | grep 5666 &>/dev/null || exit && echo "service 启动成功"
##修改磁盘名字s/vda1/sda1/
a=$(ls -l /dev/?d? | awk -F'/' '{print $3}')
sed -i -e "201 s/vda1/${a}1/" -e "s/vda1/${a}1/" /usr/local/nagios/etc/nrpe.cfg 
##添加监控项
sed -i "203a command[check_swap]=/usr/local/nagios/libexec/check_swap -w 20% -c 10%" /usr/local/nagios/etc/nrpe.cfg
##如果服务端没有check_nrpe 这条命令则需要安装 因为搭建服务端时是安装*.rpm 包 所以nrpe 也装有了
rpm -q nrpe &>/dev/null || yum -y install nrpe 
##服务端配置 ##定义监控服务 先写好模板 然和 拷贝到服务端
ssh root@$IP "
echo 'define command{
        command_name    check_nrpe
        command_line    \$USER1$/check_nrpe -H \$HOSTADDRESS$ -c \$ARG1$
        } ' >>/etc/nagios/objects/commands.cfg 
mv /root/nrpe.cfg /etc/nagios/objects/serverb.cfg
sed -i '36a cfg_file=/etc/nagios/objects/serverb.cfg' /etc/nagios/nagios.cfg
nagios -v /etc/nagios/nagios.cfg &>/dev/null || exit
systemctl restart nagios 
"
