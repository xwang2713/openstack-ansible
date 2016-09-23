#!/bin/bash

bin_dir=$(dirname $0)
script_name=$(basename $0)

. ../hpccsystems-openrc.sh


declare -A image server

image[hpcc-xenial64]=Ubuntu-16.04-x86_64
image[hpcc-wily64]=Ubuntu-15.10.x86_64
#It reports there are two image with the same name
#image[hpcc-trusty64]=Ubuntu-14.04-x86_64
image[hpcc-trusty64]=930610c5-6697-4e25-833f-9b80ce57e767
image[hpcc-trusty32]=Ubuntu-14.04-i386
image[hpcc-precise64]=Ubuntu-12.04-x86_64
image[hpcc-precise64cpp11]=Ubuntu-12.04-x86_64
image[hpcc-precise32]=Ubuntu-12.04-i386
#image[hpcc-centos7]=CentOS-7-x86_64
image[hpcc-centos7]=f08962d7-2394-46bb-a8cc-d1cf7bc3e77d
image[hpcc-centos6]=CentOS-6-x86_64
image[hpcc-centos5]=CentOS-5-x86_64

server[hpcc-xenial64]=hpcc-platform-dev-xenial64-build
server[hpcc-wily64]=hpcc-platform-dev-wily64-build
server[hpcc-trusty64]=hpcc-platform-dev-trusty64-build
server[hpcc-trusty32]=hpcc-platform-dev-trusty32-build
server[hpcc-precise64]=hpcc-platform-dev-precise64-build
server[hpcc-precise64cpp11]=hpcc-platform-dev-precise64cpp11-build
server[hpcc-precise32]=hpcc-platform-dev-precise32-build
server[hpcc-centos7]=hpcc-platform-dev-el7-build
server[hpcc-centos6]=hpcc-platform-dev-el6-build
server[hpcc-centos5]=hpcc-platform-dev-el5-build


function usage()
{
   echo ""
   echo "Usage: $script_name <paramters or options> "
   echo ""
   echo "      -f FLAVOR "
   echo "         m1.tiny, m1.small, m1.medium, m1.large. The default is m1.small" 
   echo "      -g INSTANCE_GROUP "
   echo "         For example, hpcc-xenial64, hpcc-centos5" 
   echo "      -i INSTANCE_ID" 
   echo "         instance index in integer 1-99. This index must be unique." 
   echo "      -k SSH_KEY" 
   echo "         ssh key name. The default is hpcc_key_pair." 
   echo "      -s VOLUME_SIZE" 
   echo "         volume size in GB. The default is 100." 
   echo "      -u USER_DATA" 
   echo "         User data file relative to ${bin_dir}/../user-data/.  " 
   echo "         The default is <INSTANCE_GROUP>."
   echo "      -V No volume will be created." 
   echo ""
   exit
}

instance_group=
instance_index=
flavor=m1.small 
key=hpcc_key_pair
instance_zone=redundancy-group-2
volume_zone=nova
volume_size=100
create_volume=yes

while getopts "*hf:g:i:k:s:u:V" arg
do
   case $arg in
      h) usage
         ;;
      f) flavor=$OPTARG
         ;;
      g) instance_group=$OPTARG
         ;;
      i) instance_index=$OPTARG
         ;;
      k) key=$OPTARG
         ;;
      s) volume_size=$OPTARG
         ;;
      u) user_data=$OPTARG
         ;;
      V) create_volume=no
         ;;
      ?)
         echo "Unknown option $1"
         usage
         ;;
   esac
done

[ -z "$instance_group" ] || [ -z "$instance_index" ] && usage

instance_index=$(printf "%02d" $instance_index)
image_name=${image[$instance_group]}
server_name=${server[$instance_group]}${instance_index}
volume_name=${server_name}-disk-01

if [ -z "$image_name" ] 
then
   echo "Unknown group name: $instance_group"
   exit 1
fi

if [ -z "$user_data" ] 
then
   user_data="${bin_dir}/../user-data/${instance_group}"
else
   user_data="${bin_dir}/../user-data/${user_data}"
fi

echo "image to launch: ${image_name}"
echo "instance name: ${server_name}"
echo "volume name: ${volume_name}"

openstack server list | grep ${server_name} | \
cut -d'|' -f 2 | sed 's/ //g' | while read server_id
do
   [ -n "$server_id" ] && openstack server delete -wait $server_id
done  


echo "openstack server create \
       --image  $image_name    \
       --flavor $flavor       \
       --key-name $key    \
       --user-data ${user_data}    \
       --availablility-zone $instance_zone \
       --wait \
       $server_name"

openstack server create \
       --image  $image_name    \
       --flavor $flavor       \
       --key-name $key    \
       --user-data ${user_data}    \
       --availability-zone $instance_zone \
       --wait \
       $server_name 

if [ $? -ne 0 ]
then
    echo "Faild to create new instance $server_name"
    exit 1
fi

sleep 2
server_info=$(openstack server list | grep ${server_name}) 
server_id=$(echo $server_info | cut -d'|' -f 2 | sed 's/ //g')   
server_ip=$(echo $server_info | cut -d'|' -f 5 | cut -d'=' -f2 | sed 's/ //g')   

if [ "$create_volume" = "no" ]
then
    echo "Succeed  instance_id=${server_id},instance_ip=${server_ip}"
    exit 0
fi

openstack volume list | grep ${volume_name} | \
cut -d'|' -f 2 | sed 's/ //g' | while read volume_id
do
   [ -n "$volume_id" ] && openstack volume  delete  $volume_id
done  
echo "openstack volume create \
      --size $volume_size \
      $volume_name"

openstack volume create \
      --size $volume_size \
      $volume_name

if [ $? -ne 0 ] 
then
    echo "Faild to create volume $volume_name"
    exit 1
fi

volume_info=$(openstack volume list | grep $volume_name )
volume_status=unknown

time_to_wait=20
while [ $time_to_wait -gt 0 ]
do
   volume_status=$(echo $volume_info | cut -d'|' -f4 | sed 's/ //g')
   [ "$volume_status" = "available" ] && break
   time_to_wait=$(expr $time_to_wait - 1)
   sleep 1
done
if [ "$volume_status" != "available" ] 
then
    echo "Timeout to wait volume $volume_name return state 'available'."
    exit 1
fi
volume_id=$(echo $volume_info | cut -d'|' -f2 | sed 's/ //g')

echo "openstack server add volume --device /dev/vdb  $server_id  $volume_id" 
openstack server add volume --device "/dev/vdb"  $server_id  $volume_id 
if [ $? -eq 0 ] 
then
    echo "Succeed instance_name=${server_name},instance_ip=${server_ip}"
    echo "        instance_id=${server_id},volume_id=$volume_id"
else
    echo "Faild"
    exit 1
fi

