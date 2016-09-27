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
yum install -y gcc-c++ gcc make binutils-devel openldap-devel libicu-devel 
yum install -y libxslt-devel libarchive-devel boost141-devel openssl-devel apr-devel apr-util-devel
yum install -y hiredis-devel numactl-devel libevent-devel apr1-devel aprutil-devel 
yum install -y python26-devel.x86_64 sqlite-devel libmemcached-devel memcached-devel tbb-devel redis
yum install -y rpm-build git mysql-devel curl-devel


yum install -y python26-devel.x86_64 java-1.6.0-openjdk-devel java-1.7.0-openjdk-devel
# Recent Jenkins requires Java 1.7 or later
update-alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java  

# Install R 
#-------------------------------
yum install -y R-core-devel
cd /Downloads
scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/R/Rcpp_0.12.1.tar.gz .
R CMD INSTALL Rcpp_0.12.1.tar.gz
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
     echo "export PATH=\${MAVEN_HOME}/bin:\$PATH" >> /etc/profile
  fi
fi

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
   scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/cmake/cmake-${expected_version}-el5-x86_64.tar.gz .
   tar -zxf cmake-${expected_version}-el5-x86_64.tar.gz 
   rm -rf  cmake-${expected_version}-el5-x86_64.tar.gz 
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

# Install bison 2.4.1 
#------------------------------
bison_version=$(bison -V | head -n 1 | grep 2.4.1 | cut -d' ' -f4)
if [ -z "$bison_version" ] || [[ "$bison_version" <  "2.4.1" ]]
then
   cd /Downloads/
   wget http://${FILE_SERVER}/data3/software/bison/bison-2.4.1-src.tar.gz
   tar -zxf bison-2.4.1-src.tar.gz
   cd bison-2.4.1-src
   ./configure
   make
   make install
fi

# Install flex 2.5.35
#------------------------------
flex_version=$(flex -V | head -n 1 | cut -d' ' -f 3)
if [ -z "$flex_version" ] || [ "$flex_version" = "2.5.4" ] # [[ "2.5.4" < "2.5.35" ]] doesn't work. since 3 < 4
then
   cd /Downloads/
   wget http://${FILE_SERVER}/data3/software/flex/flex-2.5.35.tar.gz
   tar -zxf flex-2.5.35.tar.gz
   cd flex-2.5.35
   ./configure
   make
   make install
fi

# Install tbb
#------------------------------
rpm -qa | grep tbb-devel
if [ $? -ne 0 ]
then
   cd /Downloads/
   wget http://${FILE_SERVER}/data3/software/tbb/tbb-2.2-2.20090809.el5.x86_64.rpm
   wget http://${FILE_SERVER}/data3/software/tbb/tbb-devel-2.2-2.20090809.el5.x86_64.rpm
   rpm -i tbb-2.2-2.20090809.el5.x86_64.rpm tbb-devel-2.2-2.20090809.el5.x86_64.rpm
fi

# gpg 
#------------------------------
su - centos -c "wget http://${FILE_SERVER}/data3/build/gpg/HPCCSystems.priv"
su - centos -c "gpg --import HPCCSystems.priv"
su - centos -c "rm -rf HPCCSystems.priv"

# atlas
#------------------------------
yum install -y atlas-devel

# This doesn't work. Take off --silent will see the error similar to this:
#OpenSSL: error:14077410:SSL routines:SSL23_GET_SERVER_HELLO:sslv3 alert handshake failure
curl --silent --location https://rpm.nodesource.com/setup | bash -
yum install -y nodejs
