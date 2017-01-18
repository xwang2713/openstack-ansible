#!/bin/bash

bin_dir=$(dirname $0)
script_name=$(basename $0)

. ../hpccsystems-openrc.sh


declare -A server 

server[hpcc-xenial64]=hpcc-platform-dev-xenial64-
server[hpcc-wily64]=hpcc-platform-dev-wily64-
server[hpcc-trusty64]=hpcc-platform-dev-trusty64-
server[hpcc-trusty32]=hpcc-platform-dev-trusty32-
server[hpcc-precise64]=hpcc-platform-dev-precise64-
server[hpcc-precise64cpp11]=hpcc-platform-dev-precise64cpp11-
server[hpcc-precise32]=hpcc-platform-dev-precise32-
server[hpcc-centos7]=hpcc-platform-dev-el7-
server[hpcc-centos6]=hpcc-platform-dev-el6-
server[hpcc-centos5]=hpcc-platform-dev-el5-
server[hpcc-yakkety64]=hpcc-platform-dev-yakkety64-


function usage()
{
   echo ""
   echo "Usage: $script_name <paramters or options> "
   echo ""
   echo "      -g INSTANCE_GROUP "
   echo "         For example, hpcc-xenial64, hpcc-centos5" 
   echo "      -i INSTANCE_ID" 
   echo "         instance index in integer 1-99. This index must be unique." 
   echo "      -V do not delete volume" 
   echo "         The instance may not have any volume attached." 
   echo ""
   exit
}

instance_type=build
instance_group=
instance_index=
delete_volume=yes

while getopts "*hf:g:i:k:V" arg
do
   case $arg in
      h) usage
         ;;
      g) instance_group=$OPTARG
         ;;
      i) instance_index=$OPTARG
         ;;
      t) instance_type=$OPTARG
         ;;
      V) delete_volume=no
         ;;
      ?)
         echo "Unknown option $1"
         usage
         ;;
   esac
done

[ -z "$instance_group" ] || [ -z "$instance_index" ] && usage

if [ -z "${server[$instance_group]}" ]
then
   echo ""
   echo "Unknown instance group $instance_group"
   usage
fi
instance_index=$(printf "%02d" $instance_index)
server_name=${server[$instance_group]}${instance_type}${instance_index}
volume_name=${server_name}-disk-01

echo "instance name: ${server_name}"
echo "volume name: ${volume_name}"


echo "openstack server delete \
       --wait \
       $server_name"

#openstack server delete \
#       --wait \
#       $server_name 

openstack server list | grep ${server_name} | \
cut -d'|' -f 2 | sed 's/ //g' | while read server_id
do
   if [ -n "$server_id" ] 
   then 
      openstack server delete --wait $server_id
      if [ $? -eq 0 ] 
      then
         echo "Succeed deleting server $server_name"
      else
         echo "Failed deleting server $server_name"
      fi
   fi
done 

[ "$delete_volume" = "no" ] && exit 0

sleep 3

echo ""
echo "openstack volume delete \
      $volume_name"

#openstack volume delete \
#      $volume_name
openstack volume list | grep ${volume_name} | \
cut -d'|' -f 2 | sed 's/ //g' | while read volume_id
do
   if [ -n "$volume_id" ] 
   then  
      openstack volume delete $volume_id
      if [ $? -eq 0 ] 
      then
         echo "Succeed deleting volume $volume_name $volume_id"
      else
         echo "Failed deleting volume $volume_name  $volume_id"
      fi
   fi
done
