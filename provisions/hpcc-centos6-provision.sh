#!/bin/bash

LOG=/var/log/provision.log
exec >$LOG 2>&1
set -x
hostname

[ $(id -u) -ne 0 ] && echo "Must run as root" && exit 3


if [ ! -e /home/centos/.ssh/id_rsa ] 
then
   cp /root/.ssh/id_rsa  /home/centos/.ssh/
   chown centos:centos /home/centos/.ssh/id_rsa
fi



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
  echo "1.0.0.17	file-server.novalocal" >> /etc/hosts
fi

# Move /usr/local to /mnt/disk1/
#-------------------------------
if [ ! -d /mnt/disk1/usr/local ]
then
  mkdir -p /mnt/disk1/usr
  mv /usr/local /mnt/disk1/usr/
  ln -s /mnt/disk1/usr/local /usr/local
fi

# Move /opt to /mnt/disk1/
#-------------------------------
if [ ! -d /mnt/disk1/opt ]
then
   if [ -d /opt ]
   then
      mv /opt /mnt/disk1/
   else
      mkdir -p /mnt/disk1/opt
   fi
   ln -s /mnt/disk1/opt /opt
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
#yum update -y
yum install -y epel-release wget
yum install -y gcc-c++ gcc make bison flex binutils-devel openldap-devel libicu-devel 
yum install -y libxslt-devel libarchive-devel boost-devel openssl-devel apr-devel apr-util-devel
yum install -y hiredis-devel numactl-devel mysql-devel libevent-devel
yum install -y python-devel apr1-devel aprutil-devel 
yum install -y sqlite-devel libmemcached-devel memcached-devel tbb-devel
yum install -y rpm-build curl-devel gtk2-devel v8-devel freetype-devel
curl --silent --location https://rpm.nodesource.com/setup | bash -
yum install -y nodejs

yum install -y java-1.6.0-openjdk-devel java-1.7.0-openjdk-devel
# Recent Jenkins requires Java 1.7 or later
update-alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java




# Install git package
#------------------------------
cd /Downloads
scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/git/git-1.7.12.4-1.el6.rfx.x86_64.rpm .
scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/git/perl-Git-1.7.12.4-1.el6.rfx.x86_64.rpm .
scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/git/perl-YAML-0.70-4.el6.noarch.rpm .
yum install -y git-1.7.12.4-1.el6.rfx.x86_64.rpm perl-Git-1.7.12.4-1.el6.rfx.x86_64.rpm perl-YAML-0.70-4.el6.noarch.rpm

# Install R 
#-------------------------------
yum install -y R-core-devel
cd /Downloads
scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/R/Rcpp_0.12.1.tar.gz .
R CMD INSTALL Rcpp_0.12.1.tar.gz
scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/R/RInside_0.2.12.tar.gz .
R CMD INSTALL RInside_0.2.12.tar.gz


# Add ANTLRA and graphviz
#-----------------------------------------
cd /Downloads
scp -r -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/antlr/ANTLR.tar.gz .
tar -zxvf ANTLR.tar.gz -C /usr/local/
scp -r -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/graphviz/graphviz-2.26.3.tar.gz .
tar -zxvf graphviz-2.26.3.tar.gz -C /usr/local/src/


# Add Maven
#-----------------------------------------
maven_name=apache-maven-3.3.9
cd /usr/local
if [ ! -d $maven_name ]
then 
  scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/apache/${maven_name}-bin.tar.gz .
  tar -zxvf ${maven_name}-bin.tar.gz
  rm -rf ${maven_name}-bin.tar.gz
  [ -d maven ] && rm -rf maven
  ln -s $maven_name maven
  grep MAVEN_HOME /etc/profile 
  if [ $? -ne 0 ]
  then
     echo "export MAVEN_HOME=/usr/local/maven" >> /etc/profile
     echo "export PATH=\${MAVEN_HOME}/bin:\$PATH" >> /etc/profile
  fi
fi

# Add hadoop
#-------------------------------
cd /usr/local
if [ ! -e hadoop ]
then
  scp -r -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/hadoop/hadoop-1.2.1.tar.gz /usr/local/
  tar -zxvf hadoop-1.2.1.tar.gz
  rm -rf hadoop-1.2.1.tar.gz

  scp -r -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/hadoop/hadoop-2.6.0.tar.gz /usr/local/
  tar -zxvf hadoop-2.6.0.tar.gz
  rm -rf hadoop-2.6.0.tar.gz
  ln -s hadoop-2.6.0 hadoop
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

# Install Ruby, Puppet agent
#-------------------------------
yum install -y ruby puppet
cd /etc/puppet
grep "^[[:space:]]*server[[:space:]]*=[[:space:]]file-server"  puppet.conf
if [ $? -ne 0 ]
then
   sed -i '/^[[:space:]]*postrun_command/a server=file-server.novalocal' puppet.conf
fi

# Install cmake
#------------------------------
expected_version=3.5.2
cmake_path=$(which cmake)
[ -n "$cmake_path" ] && cmake_version=$(cmake -version | head -n 1 | cut -d' ' -f3)
if [ -z "$cmake_path" ] || [[ "$cmake_version" != "$expected_version" ]]
then
   cd /Downloads
   scp -o StrictHostKeyChecking=no root@1.0.0.17:/data3/software/cmake/cmake-${expected_version}-el6-x86_64.tar.gz .
   tar -zxf cmake-${expected_version}-el6-x86_64.tar.gz
   rm -rf  cmake-${expected_version}-el6-x86_64.tar.gz
   cd  cmake-${expected_version}-Linux-x86_64
   cp -r * /usr/local/

fi


# Install C++11 package
#------------------------------
wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
yum install -y devtoolset-2-gcc devtoolset-2-binutils
yum install -y devtoolset-2-gcc-gfortran devtoolset-2-gcc-c++
yum install -y devtoolset-2-libatomic-devel devtoolset-2-gdb devtoolset-2-git devtoolset-2-gitk
yum install -y  devtoolset-2-valgrind devtoolset-2-elfutils devtoolset-2-strace devtoolset-2-git-gui
