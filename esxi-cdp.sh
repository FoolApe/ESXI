#!/bin/bash
passwd='PASSWORD'
list='/opt/lists/cdp_list'

for a in `cat $list`
do
    vmnics=`sshpass -p $passwd ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$a "esxcli network nic list" |grep '10000' |grep 'Up' |awk '{print $1}' |sed 's/[[:space:]]//g'`
    echo "=== $a ==="
    for nic in $vmnics
    do
        info=`sshpass -p $passwd ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$a "vim-cmd hostsvc/net/query_networkhint --pnic-names $nic" |egrep "devId|portId"`
#        echo $info |awk -F \, '{print $1}' |awk -F \= '{print $2}' |sed 's/[[:space:]]//g' |sed 's/\"//g'
        device=`echo $info |awk -F \, '{print $1}' |awk -F \= '{print $2}' |sed 's/[[:space:]]//g' |sed 's/\"//g'`
        port=`echo $info |awk -F \, '{print $2}' |awk -F \= '{print $2}' |sed 's/[[:space:]]//g' |sed 's/\"//g'`
        echo "$nic | $device | $port"
    done
    echo ""
done
