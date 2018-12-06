#!/bin/bash -x

LOG=/var/log/provision.log
exec >$LOG 2>&1
set -x
hostname

FILE_SERVER=10.240.32.242
[ -n "$1" ] && FILE_SERVER=$1

[ $(id -u) -ne 0 ] && echo "Must run as root" && exit 3

[ ! -e /root/.ssh/id_rsa ] && echo "Missing  /root/.ssh/id_rsa"  && exit 3

if [ ! -e /home/ubuntu/.ssh/id_rsa ] 
then
    cp /root/.ssh/id_rsa /home/ubuntu/.ssh/
    chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
fi

df -k

apt-get install -y python2.7-dev
apt-get install -y python3-dev


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

mkdir -p /Downloads
chmod -R 777 /Downloads

# Install pre-requisite packages 
#-------------------------------
apt-get update
apt-get install -y libgtk2.0-dev curl libcurl4-gnutls-dev libfreetype6-dev fop zip
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install -y nodejs
apt-get install -y g++ gcc make bison git flex build-essential binutils-dev libldap2-dev libcppunit-dev libicu-dev
apt-get install -y libxslt1-dev zlib1g-dev libboost-regex-dev libssl-dev libarchive-dev
apt-get install -y libv8-dev default-jdk libapr1-dev libaprutil1-dev libiberty-dev
apt-get install -y libhiredis-dev libtbb-dev libxalan-c-dev libnuma-dev libevent-dev
apt-get install -y libsqlite3-dev libmemcached-dev 
apt-get install -y libboost-thread-dev libboost-filesystem-dev libmysqlclient-dev
apt-get install -y libtool autotools-dev automake m4

# Install R 
#-------------------------------
apt-get install -y r-base r-cran-rcpp
cd /Downloads
scp -o StrictHostKeyChecking=no root@${FILE_SERVER}:/data3/software/R/RInside_0.2.14.tar.gz .
R CMD INSTALL RInside_0.2.14.tar.gz

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

mkdir -p /var/lib/jenkins/workspace
chown -R ubuntu:ubuntu /var/lib/jenkins
[ ! -e /jenkins ] &&  ln -s /var/lib/jenkins /jenkins

# Install cmake
#------------------------------
expected_version=3.13.1
codename=bionic
cmake_path=$(which cmake)
[ -n "$cmake_path" ] && cmake_version=$(cmake -version | head -n 1 | cut -d' ' -f3)
if [ -z "$cmake_path" ] || [[ "$cmake_version" != "$expected_version" ]]
then
   cd /Downloads
   wget http://${FILE_SERVER}:/data3/software/cmake/${expected_version}/cmake-${expected_version}-${codename}-amd64.tar.gz
   tar -zxf cmake-${expected_version}-${codename}-amd64.tar.gz
   rm -rf  cmake-${expected_version}*.tar.gz
   cd  cmake-${expected_version}-${codename}-amd64
   cp -r bin /usr/local/
   cp -r doc /usr/local/
   cp -r share /usr/local/
   cp -r man/* /usr/local/man/
fi


#------------------------------
#wget http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-amd64.deb
#sudo dpkg -i couchbase-release-1.0-2-amd64.deb
#sudo apt-get update
#sudo apt-get install -y libcouchbase-dev libcouchbase2-bin build-essential
#rm -rf couchbase-release-1.0-2-amd64.deb

# gpg
#------------------------------
#su - ubuntu -c "wget http://${FILE_SERVER}/data3/build/gpg/HPCCSystems.priv"
#su - ubuntu -c "gpg --import HPCCSystems.priv"
#su - ubuntu -c "rm -rf HPCCSystems.priv"
#try gpg --passphrase icanspellthis --import HPCCSystems.priv


# atlas
#------------------------------
apt-get install -y libatlas-base-dev


exit 0
