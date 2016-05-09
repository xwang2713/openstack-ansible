#!/bin/bash

script_dir=$(dirname $0)
script_name=$(basename $0)

log=${script_dir}/log/delete.log
[ -e $log ] && rm -rf $log

function usage()
{
   echo ""
   echo "Usage: $script_name <paramters or options> "
   echo ""
   echo "      -i INPUT_FILE "
   echo "         in format: <instance group> <index>" 
   echo ""
   exit
}

input_file=

while getopts "*hf:g:i:k:V" arg
do
   case $arg in
      h) usage
         ;;
      i) input_file=$OPTARG
         ;;
      ?)
         echo "Unknown option $1"
         usage
         ;;
   esac
done

[ -z "$input_file" ]  && usage

cat $input_file | while read group index options
do
    [ -z "$group" ] && continue
    echo $group | grep -q "^[[:space:]]*#" 
    [ $? -eq 0 ] && continue

    #echo "$group,$index,$options"
    
    echo "" | tee -a $log
    echo "" | tee -a $log
    ${script_dir}/../client/delete-instance.sh -g $group -i $index "$options" |& tee -a $log 
    
done

