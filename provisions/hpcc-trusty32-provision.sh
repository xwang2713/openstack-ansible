#!/bin/bash

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

#apt-get install -y python2.7


# Mount volume /dev/vdb
#--------------------------
mount | grep "/dev/vdb"
if [ $? -eq 0 ]
then
  echo "/dev/vdb was already mounted"
else
  echo "Format and mount /dev/vdb"
  mke2fs -t ext4 /dev/vdb
  mkdir -p /mnt/disk1
  mount -t ext4 /dev/vdb /mnt/disk1
fi

# Add /dev/vdb to fstab
#--------------------------
grep  "[[:space:]]*/dev/vdb" /etc/fstab
if [ $? -ne 0 ] 
then
  echo "add /dev/vdb to /etc/fstab"
  echo "/dev/vdb	/mnt/disk1	ext4	defaults	0 0" >> /etc/fstab
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

# Move /usr/local to /mnt/disk1/
#-------------------------------
if [ ! -d /mnt/disk1/usr/local ]
then
  mkdir -p /mnt/disk1/usr
  mv /usr/local /mnt/disk1/usr/
  ln -s /mnt/disk1/usr/local /usr/local
fi

# Move /tmp to /mnt/disk1/
#-------------------------------
if [ ! -d /mnt/disk1/tmp ]
then
  mv /tmp /mnt/disk1/
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

# Install pre-requisite packages 
#-------------------------------
apt-get update
apt-get install -y libgtk2.0-dev curl libcurl4-gnutls-dev
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install -y nodejs
apt-get install -y g++ gcc make bison git flex build-essential binutils-dev libldap2-dev libcppunit-dev libicu-dev
apt-get install -y libxslt1-dev zlib1g-dev libboost-regex-dev libssl-dev libarchive-dev
apt-get install -y python2.7-dev python3-dev libv8-dev openjdk-6-jdk openjdk-7-jdk libapr1-dev libaprutil1-dev 
apt-get install -y libhiredis-dev libtbb-dev libnuma-dev libevent-dev
apt-get install -y libsqlite3-dev libmemcached-dev fop zip
apt-get install -y libboost-thread-dev libboost-filesystem-dev libmysqlclient-dev
apt-get install -y libtool autotools-dev automake m4

# Install R 
#-------------------------------
apt-get install -y r-base r-cran-rcpp
cd /Downloads
scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/R/RInside_0.2.12.tar.gz .
R CMD INSTALL RInside_0.2.12.tar.gz

# Add ANTLRA and graphviz
#-----------------------------------------
cd /Downloads
scp -r -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/antlr/ANTLR.tar.gz .
tar -zxvf ANTLR.tar.gz -C /usr/local/
scp -r -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/graphviz/graphviz-2.26.3.tar.gz .
tar -zxvf graphviz-2.26.3.tar.gz -C /usr/local/src/


# Configure Jenkins slaves
#-------------------------------
cd /mnt/disk1
if [ ! -d jenkins ]
then
  mkdir -p jenkins/workspace
  chown -R ubuntu:ubuntu jenkins
fi
[ ! -e /jenkins ] &&  ln -s /mnt/disk1/jenkins /jenkins

# Install Ruby, Puppet agent
#-------------------------------
apt-get install -y ruby puppet
cd /etc/puppet
grep "^[[:space:]]*server[[:space:]]*=[[:space:]]file-server"  puppet.conf
if [ $? -ne 0 ]
then
   sed -i '/^[[:space:]]*postrun_command/a server=file-server.novalocal' puppet.conf
fi

# Install cmake
#------------------------------
expected_version=3.13.1
cmake_path=$(which cmake)
[ -n "$cmake_path" ] && cmake_version=$(cmake -version | head -n 1 | cut -d' ' -f3)
if [ -z "$cmake_path" ] || [[ "$cmake_version" != "$expected_version" ]]
then
   cd /Downloads
   wget http://${FILE_SERVER}:/data3/software/cmake/${expected_version}/cmake-${expected_version}-trusty-i686.tar.gz
   tar -zxf cmake-${expected_version}-trusty-i686.tar.gz
   rm -rf  cmake-${expected_version}-trusty-i686.tar.gz
   cd  cmake-${expected_version}-trusty-i686
   cp -r * /usr/local/
fi

# gpg
#------------------------------
su - ubuntu -c "wget http://${FILE_SERVER}/data3/build/gpg/HPCCSystems.priv"
su - ubuntu -c "gpg --import HPCCSystems.priv"
su - ubuntu -c "rm -rf HPCCSystems.priv"

# atlas
#------------------------------
apt-get install -y libatlas-base-dev

exit

