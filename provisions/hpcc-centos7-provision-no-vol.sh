#!/bin/bash -x

LOG=/var/log/provision.log
exec >$LOG 2>&1
set -x
hostname

FILE_SERVER=10.240.32.242
[ -n "$1" ] && FILE_SERVER=$1

[ $(id -u) -ne 0 ] && echo "Must run as root" && exit 3

[ ! -e /root/.ssh/id_rsa ] && echo "Missing  /root/.ssh/id_rsa"  && exit 3

if [ ! -e /home/centos/.ssh/id_rsa ] 
then 
  cp /root/.ssh/id_rsa /home/centos/.ssh/
  chown centos:centos /home/centos/.ssh/id_rsa
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

# Install pre-requisite packages 
#-------------------------------
#yum update -y

#git
yum install -y perl-ExtUtils-MakeMaker.noarch
scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/git/git-2.9.5.tar.xz .
tar -xf git-2.9.5.tar.xz
cd git-2.9.5
./configure
make -j4
make install
cd ..
rm -rf git-2.9.5*

yum install -y epel-release wget
yum install -y gcc-c++ gcc make bison flex binutils-devel openldap-devel libicu-devel 
yum install -y libxslt-devel libarchive-devel boost-devel openssl-devel apr-devel apr-util-devel
yum install -y hiredis-devel numactl-devel libevent-devel
yum install -y python-devel python34-devel java-1.8.0-openjdk-devel apr1-devel aprutil-devel 
yum install -y sqlite-devel libmemcached-devel memcached-devel tbb-devel v8-devel
yum install -y rpm-build curl-devel gtk2-devel freetype-devel libtool
curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
yum install -y nodejs
#if still install old nodejs run "yum clean all" first. Also remove other nodesource under /etc/yum.repos.d/ then run curl for setup_8.x
yum install -y http://10.240.32.242/data3/software/mysql/MySQL-devel-5.6.21-1.el7.x86_64.rpm

# Install R 
#-------------------------------
yum install -y R-core-devel
cd /Downloads
scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/R/Rcpp_0.12.19.tar.gz .
R CMD INSTALL Rcpp_0.12.19.tar.gz
scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/R/RInside_0.2.12.tar.gz .
R CMD INSTALL RInside_0.2.12.tar.gz


# Add ANTLRA and graphviz
#-----------------------------------------
cd /Downloads
scp -r -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/antlr/ANTLR.tar.gz .
tar -zxvf ANTLR.tar.gz -C /usr/local/
scp -r -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/graphviz/graphviz-2.26.3.tar.gz .
tar -zxvf graphviz-2.26.3.tar.gz -C /usr/local/src/


# Add Maven
#-----------------------------------------
maven_name=apache-maven-3.3.9
cd /usr/local
if [ ! -d $maven_name ]
then 
  scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/apache/${maven_name}-bin.tar.gz .
  tar -zxvf ${maven_name}-bin.tar.gz
  rm -rf ${maven_name}-bin.tar.gz
  [ -d maven ] && rm -rf maven
  ln -s $maven_name maven
  grep MAVEN_HOME /etc/profile 
  if [ $? -ne 0 ]
  then
     echo "export MAVEN_HOME=/usr/local/maven" >> /etc/profile
     echo "export PATH=\${MAVEN_HOME}/bin:\${PATH}" >> /etc/profile
  fi
fi

echo $PATH

# Add hadoop
#-------------------------------
cd /usr/local
if [ ! -e hadoop ]
then
  scp -r -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/hadoop/hadoop-1.2.1.tar.gz /usr/local/
  tar -zxvf hadoop-1.2.1.tar.gz
  rm -rf hadoop-1.2.1.tar.gz

  scp -r -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/hadoop/hadoop-2.6.0.tar.gz /usr/local/
  tar -zxvf hadoop-2.6.0.tar.gz
  rm -rf hadoop-2.6.0.tar.gz
  ln -s hadoop-2.6.0 hadoop
fi

# Configure Jenkins slaves
#-------------------------------
mkdir -p /var/lib/jenkins/workspace
chown -R centos:centos /var/lib/jenkins
[ ! -e /jenkins ] &&  ln -s /var/lib/jenkins /jenkins

# Install cmake
#------------------------------
expected_version=3.13.1
codename=el7
cmake_path=$(which cmake)
[ -n "$cmake_path" ] && cmake_version=$(cmake -version | head -n 1 | cut -d' ' -f3)
if [ -z "$cmake_path" ] || [[ "$cmake_version" != "$expected_version" ]]
then
   cd /Downloads
   scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/cmake/${expected_version}/cmake-${expected_version}-${codename}-x86_64.tar.gz .
   tar -zxf cmake-${expected_version}-${codename}-x86_64.tar.gz
   rm -rf  cmake-${expected_version}-${codename}-x86_64.tar.gz
   cd  cmake-${expected_version}-${codename}-x86_64
   cp -r * /usr/local/

fi

# Install Couchbase
#------------------------------
wget http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-x86_64.rpm
rpm -iv couchbase-release-1.0-2-x86_64.rpm
yum install -y libcouchbase-devel libcouchbase2-bin
rm -rf couchbase-release-1.0-2-x86_64.rpm

# gpg
#------------------------------
su - centos -c "wget http://${FILE_SERVER}/data3/build/gpg/HPCCSystems.priv"
su - centos -c "gpg --import HPCCSystems.priv"
su - centos -c "rm -rf HPCCSystems.priv"

# atlas
#------------------------------
yum install -y atlas-devel

#devtoolset-7
#------------------------------
sudo yum install -y centos-release-scl
sudo yum install -y devtoolset-7

# To enable in current session:
# scl enable devtoolset-7 bash

# Install Sybase
#------------------------------
wget http://${FILE_SERVER}/data3/software/Sybase/sybase_install.tar.gz
tar -zxvf sybase_install.tar.gz
cd sybase_install
./install.sh
cd ..
rm -rf sybase*

