#!/bin/bash

LOG=/var/log/provision.log
exec >$LOG 2>&1
set -x
hostname


echo "This some of these need run maunally ..."
exit

[ $(id -u) -ne 0 ] && echo "Must run as root" && exit 3


if [ ! -e /home/centos/.ssh/id_rsa ] 
then 
  cp /root/.ssh/id_rsa /home/centos/.ssh/
  chown centos:centos /home/centos/.ssh/id_rsa
fi


# Add hostname to /etc/hosts
#---------------------------
host_ip=$(ifconfig | grep "[[:space:]]*inet addr:1.0" | cut -d':' -f2 | cut -d' ' -f1)
host_name=$(hostname -s)
grep $host_name /etc/hosts
if [ $? -ne 0 ] 
then
  echo "add ip and hostname to /etc/hosts"
  echo "$host_ip	file-server file-server.novalocal" >> /etc/hosts
  echo "$host_ip	$host_name ${host_name}.novalocal" >> /etc/hosts
fi


# enable "PermitRootLogin yes" in /etc/ssh/sshd_config
# Remove prompt at begining of /root/.ssh/authorized_keys
# Restart sshd
# modify to "UMASK 022" in /etc/login.defs. This may require reboot for make cross system change
# SELINUX setting: set  "SELINUX=permissive" in /etc/selinux/config. Need reboot
# run "sestatus" to verify 

# Some usefull directores 
#-------------------------------
mkdir -p /root/Downloads  /root/work

# Add users 
# new users should in "users" group (id=100)
#-------------------------------
useradd -d /home/hpccbuild -s /bin/bash -G users hpccbuild
mkdir -p /home/hpccbuild/.ssh
cp -r ~/.ssh/id_rsa  ~/.ssh/authorized_keys /home/hpccbuild/.ssh/
chown -R hpccbuild:hpccbuild /home/hpccbuild/.ssh

useradd -d /home/netshare -s /bin/bash -G users netshare
mkdir -p /home/netshare/.ssh
cp -r ~/.ssh/id_rsa  ~/.ssh/authorized_keys /home/netshare/.ssh/
chown -R netshare:netshare /home/netshare/.ssh


# Install pre-requisite packages 
#-------------------------------
yum update -y
yum install -y epel-release wget nfs-utils nfs-utils-lib
yum install -y python34.x84_64
yum install -y java-1.8.0-openjdk
yum install -y httpd.x86_64
yum install -y samba
yum install -y git
yum groupinstall "Development tools"
yum install zlib-devel bzip2-devel
yum install -y openssl-devel libcurl-devel ncurses-devel
pip install --upgrade pip
# latest Django such as 1.9  drop FastCGI support
# Need some investigate for how to migration. For now stll use working one
# Also remember Django 1.5.4 shipped with simplejson. For new new Django
# either switch to python json module and install simplejson as 'pip install simplejson'
pip install django Django==1.5.4
pip install flup
# Install django-piston
# Download django-piston from https://pypi.python.org/pypi/django-piston/. 
# The current latest is 0.2.3. Untar the file.
# Go to untar the directory and run python setup.py install

#yum install -y gcc gcc-c++


# Install nginx 
#-------------------------------
#add /etc/yum.repos.d/nginx.repo:
#[nginx]
#name=nginx repo
#baseurl=http://nginx.org/packages/centos/7/$basearch/
#gpgcheck=0
#enabled=1

#yum install -y nginx
#Configuration file /etc/nginx/conf.d/default.conf
#start/stop/restart: systemctl <start|stop|restart> nginx


# mount volumes 
#-------------------------------
mkdir -p /data1 /data2 /data3
mount -t ext4 /dev/vdb /data1
mount -t ext4 /dev/vdc /data2
mount -t ext4 /dev/vdd /data3
chown -R netshare:users /data1 /data2 /data3
chown -R hpccbuild:users /data1/hpcc/builds


# httpd configuration 
#-------------------------------
#/etc/httpd/conf/httpd.conf
#   <IfModule autoindex_module>
#       IndexOptions FancyIndexing FoldersFirst NameWidth=* DescriptionWidth=*
#   </IfModule>
#   <Directory "/builds/">
#      Options FollowSymLinks Indexes
#      AllowOverride None
#      Order allow,deny
#      allow from all
#   </Directory>
# create link /var/www/html/builds -> /data1/hpcc/builds 
# do the same for /data1 , /data2 and /data3


mkdir -p /data1 /data2 /data3

# nfs configuration 
#-------------------------------
##/data1 10.240.32.242/24(rw,sync,insecure,all_squash,anonuid=1002,anongid=100) 1.0.0.31/24(rw,sync,insecure,all_squash,anonuid=1002, anongid=100)  10.240.32.0/24(rw,sync,insecure,all_squash,anonuid=1002,anongid=100)
#/data1 *(rw,sync,insecure,all_squash,anonuid=1002,anongid=100)
#/data2 *(rw,sync,insecure,all_squash,anonuid=1002,anongid=100)
#/data3 *(rw,sync,insecure,all_squash,anonuid=1002,anongid=100)
#exportfs -a
#systemctl enable rpcbind
#systemctl start rpcbind
#systemctl enable nfs-server
#systemctl start nfs-server
~                                                             

# samba configuration 
#-------------------------------
# /etc/samba/smb.conf 
# [global]
# workgroup = WORKROUP
# server string = Samba Server Version %v
# netbios name = HPCC-FSVR
# log file = /var/log/samba/log.%m
# max log size = 50
#      security = user
#        passdb backend = tdbsam
#
#[data3]
#        comment = shared volume data3
#        path = /data3
#        public = no
#        writable = yes
#        printable = no
#        read only = no
#        valid users = netshare
#        write list = @users
#        force user = netshare
#        force group = users
#        browseable = yes
#        create mask = 0775
#        directory mask = 0775
#        share modes = yes
#
#[data2]
#       comment = shared volume data2
#        path = /data2
#        public = no
#        writable = no
#        printable = no
#        valid users = netshare
#
#[data1]
#        comment = shared volume data1
#        path = /data1
#        public = no
#        writable = no
#        printable = no
#        valid users = netshare

#systemctl enable smb.service
#systemctl enable nmb.service
#systemctl restart smb.service
#systemctl restart nmb.service

#smbpasswd -a netshare
#password: hpcc


# Download HPCC_Build_Staging and start staging app
#---------------------------------------------------
#under /u
#git clone https://github.com/xwang2713/HPCC_Build_Staging
#make sure /u/tBuilds is linked to /data1/hpcc/builds
#nginx config settings:
#   upstream stagingdjango {
#             server 127.0.0.1:8000;
#   }
#
#   server {
#          listen 8000;
#          server_name _;
#          access_log /var/log/nginx/BuildStaging.access.log;
#          error_log /var/log/nginx/BuildStaging.error.log;
#
#          location / {
#              include fastcgi_params;
#              fastcgi_split_path_info ^()(.*)$;
#              fastcgi_pass 127.0.0.1:9001;
#          }
#    }

# start nginx: service nginx start
# go to /u/HPCC_Build_Staging and start app:  ./start
# verify from browser: http://10.240.32.242:8000/staging/api/build/


