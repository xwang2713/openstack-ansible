#!/bin/bash -x

LOG=/var/log/provision.log
exec >$LOG 2>&1
set -x
hostname

FILE_SERVER=10.240.32.242
[ -n "$1" ] && FILE_SERVER=$1

[ $(id -u) -ne 0 ] && echo "Must run as root" && exit 3


#[ ! -e ~/.ssh/id_rsa ] && cp /root/.ssh/id_rsa ~/.ssh/

# Mount volume /dev/vdb
#--------------------------
mount | grep "/dev/vdb"
if [ $? -eq 0 ]
then
  echo "/dev/vdb was already mounted"
else
  echo "Format and mount /dev/vdb"
  /sbin/fdisk -l
  /sbin/mkfs.ext3 /dev/vdb
  mkdir -p /mnt/disk1
  mount -t ext3 /dev/vdb /mnt/disk1
fi

# Add /dev/vdb to fstab
#--------------------------
grep  "[[:space:]]*/dev/vdb" /etc/fstab
if [ $? -ne 0 ] 
then
  echo "add /dev/vdb to /etc/fstab"
  echo "/dev/vdb	/mnt/disk1	ext3	defaults	0 0" >> /etc/fstab
fi

df -k

# Add hostname to /etc/hosts
#---------------------------
host_ip=$(ifconfig | grep "[[:space:]]*inet addr:1.0" | cut -d':' -f2 | cut -d' ' -f1)
host_name=$(hostname -s)
grep $host_name /etc/hosts
if [ $? -ne 0 ] 
then
  echo "add ip and hostname to /etc/hosts"
  echo "$host_ip	$host_name ${host_name}.novalocal" >> /etc/hosts
fi

grep file-server /etc/hosts
if [ $? -ne 0 ] 
then
  echo "${FILE_SERVER}	file-server.novalocal" >> /etc/hosts
fi

# Move /tmp to /mnt/disk1/
#-------------------------------
if [ ! -d /mnt/disk1/tmp ]
then
  mkdir -p /mnt/disk1/tmp
  rm -rf /tmp
  ln -s /mnt/disk1/tmp /tmp
fi

# Some utility directories
#-------------------------------
if [ ! -d /mnt/disk1/Downloads ]
then
  mkdir -p /mnt/disk1/Downloads
  chmod -R 777 /mnt/disk1/Downloads
  ln -s /mnt/disk1/Downloads /Downloads
fi

# Configure Jenkins slaves
#-------------------------------
cd /mnt/disk1
if [ ! -d jenkins ]
then
  mkdir -p jenkins/workspace
  chown -R centos:centos jenkins
fi
[ ! -e /jenkins ] &&  ln -s /mnt/disk1/jenkins /jenkins

#/etc/resolv.conf
# search openstacklocal novalocal
#nameserver 10.121.146.70
#nameserver 10.121.146.71
