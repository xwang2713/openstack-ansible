#!/bin/bash -x

LOG=/var/log/provision.log
exec >$LOG 2>&1
set -x
hostname

FILE_SERVER=10.240.32.242
[ -n "$1" ] && FILE_SERVER=$1

[ $(id -u) -ne 0 ] && echo "Must run as root" && exit 3

if [ ! -e /home/ubuntu/.ssh/id_rsa ] 
then
    cp /root/.ssh/id_rsa /home/ubuntu/.ssh/
    chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
fi

apt-get install -y python2.7

df -k

# Add hostname to /etc/hosts
#---------------------------
host_ip=$(ifconfig | grep "[[:space:]]*inet 1.0" | sed 's/  */ /g' | cut -d' ' -f3)
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

# Some utility directories
#-------------------------------
if [ ! -d ~/Downloads ]
then
  mkdir -p ~/Downloads
  chmod -R 777 ~/Downloads
fi


# Configure Jenkins slaves
#-------------------------------
cd /var/lib
if [ ! -d jenkins ]
then
  mkdir -p jenkins/workspace
  chown -R ubuntu:ubuntu jenkins
fi

[ ! -e /jenkins ] &&  ln -s /var/lib/jenkins /jenkins

exit 0
