#!/bin/bash
read -p "请输入你u盘的名字如（/dev/sdc）：" name
newname=$(basename $name)  #basename命令用于打印目录或者文件的基本名称
mname=$(/bin/mount |awk "/$newname/ {print \$1}")
##判断盘是否挂载
if [ -n "$mname" ];then
    for i in $mname
	 do
	   umount -f $i
    done 
fi
##格式化分区
dd if=/dev/zero of=$name bs=500 count=1 &>/dev/null
fdisk $name <<EOF &>/dev/null
n
p
1

+4G
a
1
w
EOF

mkfsname=$name'1'
mkfs.ext4 $mkfs$name &>/dev/null
mkdir -p /media/usb
mount $mkfsname /media/usb
##解压原来安装好的U盘系统文件至当前U盘，修改相关的配置文件(fstab grub.conf)中的UUID
sname=rhel6u5.tar.bz2
tar xf ./$sname -C /media/usb
uuid=$(blkid $mkfsname | grep -Eo'(.){8}-((.){4}-){3}(.){12}')
sed -i -r "s/(.){8}-((.){4}-){3}(.){12}/$uuid/g" /media/usb/etc/fstab  /media/usb/boot/grub/grub.conf
##安装grub
grub-install --root-directory=/media/usb/ --recheck $name &>/dev/null
[ $? -eq 0 ] && umount /mnt/usb && echo "U盘系统制作成功"
