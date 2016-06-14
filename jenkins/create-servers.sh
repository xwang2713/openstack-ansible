#!/bin/bash

cur_dir=$(pwd)
script_name=$(basename $0)
script_dir=$(dirname $0)

root_dir=${script_dir}/..
log_dir=${script_dir}/log
data_dir=${script_dir}/data

mkdir -p $log_dir $data_dir



result=${log_dir}/create_result
log=${log_dir}/create.log
tmp_log=${log_dir}/create_$$
server_ip_list=${data_dir}/server_ip_list


[ -e $result ] && rm -rf $result
[ -e $log ] && rm -rf $log
[ -e $tmp_log ] && rm -rf $tmp_log
[ -e $server_ip_list ] && rm -rf $server_ip_list

touch $log
touch $server_ip_list

declare -A IPS 
DISTROS=""


function usage()
{
   echo ""
   echo "Usage: $script_name <paramters or options> "
   echo ""
   echo "      -i INPUT_FILE "
   echo "         in format: <instance group> <index>" 
   echo "      -o OUTPUT_HOSTS_FILE_NAME"
   echo "         in format: ansible hosts file under ../etc/ansible. The default is jenkins_slaves" 
   echo ""
   exit
}

input_file=
slave_list=jenkins_slaves

while getopts "*hi:o:" arg
do
   case $arg in
      h) usage
         ;;
      i) input_file=$OPTARG
         ;;
      i) slave_list=$OPTARG
         ;;
      ?)
         echo "Unknown option $1"
         usage
         ;;
   esac
done

[ -z "$input_file" ]  && usage

slave_list=${rootDir}/etc/ansible/$slave_list
[ -e $slave_list ] && rm -rf $slave_list

# Create new instances
#---------------------
error=0
while read group index options
do
    [ -z "$group" ] && continue
    echo $group | grep -q "^[[:space:]]*#"  
    [ $? -eq 0 ] && continue

    #echo "$group,$index,$options"
    
    #echo ""
    echo "Launch $group $index" | tee -a $log 
    echo "-----------------------"  | tee -a $log
    ${script_dir}/../client/create-instance.sh -g $group -i $index "$options"  |& tee  $tmp_log 
    if [ $? -eq 0 ]
    then  
        # Collect new instance information
        #---------------------------------
        result_string=$(cat $tmp_log | tail -n 2 | head -n 1) 
        resul_string=$(echo $result_string | cut -d' ' -f 2)
        instance_name=$(echo $result_string | cut -d',' -f 1 | cut -d'=' -f 2)
        instance_ip=$(echo $result_string | cut -d',' -f 2 | cut -d'=' -f 2)
        echo "$instance_ip	$instance_name" >> $server_ip_list	
        if [ ${IPS[$group]} ]
        then
            IPS[$group]="${IPS[$group]} $instance_ip"
        else
            IPS[$group]="$instance_ip"
        fi

        if echo $group | grep -q centos
        then
           if echo "$DISTROS" | grep -q -v $group
           then
              if [ -n "${DISTROS}" ]
              then
                 DISTROS="${DISTROS} $group"
              else
                 DISTROS="$group"
              fi
           fi
        else
           if echo "${DISTROS}" | grep -q -v $group
           then
              if [ -n "${DISTROS}" ]
              then
                 DISTROS="${DISTROS} $group"
              else
                 DISTROS="$group"
              fi
           fi
        fi
    else
        error=$(expr $error \+ 1) 
    fi
    cat $tmp_log >> $log
done < $input_file

if [ $error -eq 0 ]
then
   echo "Succeed" | tee  $result
else
   echo "Failed. There are $error instance(s) failed to create." | tee  $result
   exit 1
fi

# Create host list file $slave_list
#----------------------------------
touch $slave_list
for group in ${DISTROS}
do
   echo "[$group]" >> $slave_list
   for ip in  ${IPS[$group]} 
   do
      echo "$ip" >> $slave_list
   done
   echo "" >> $slave_list
done
echo "" >> $slave_list
echo "[new:children]" >> $slave_list
for group in ${DISTROS}
do
   echo "$group" >> $slave_list
done
echo "" >> $slave_list

echo ""
echo "Hosts file for Ansible" | tee -a $log
cat $slave_list | tee -a $log
