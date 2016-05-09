#!/bin/bash
cmd="cat /etc/hosts  "
while read ip hostname
do
   cmd="$cmd | grep -v $hostname"
done <  /tmp/server_ip_list

eval $cmd  > /tmp/new_hosts
cat /tmp/server_ip_list >> /tmp/new_hosts

rm -rf /etc/hosts
mv /tmp/new_hosts /etc/hosts
chmod 644 /etc/hosts

