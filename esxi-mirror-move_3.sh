#!/bin/bash
### First version : 2021/05/21 
### Update : 2022/09/21
### Made by : SYS-Juro
### Description : 檢查機器網路設定 , 並鏡像其設定

### 變數設定
pw='/usr/local/ESXI-update/HCL/nimajuro'
bot="*****27531:AAE3J2dAiVXzLb_q4rkl2OGjW*****KlCXc"
id="-5796*****"
date=$(/bin/date |awk '{print $6,$2,$3,$4}')
file='/usr/local/ESXI-update/HCL/lists/nmap_list'
log='/usr/local/ESXI-update/Logs/work/mirror-move_2.log'
ip_file='/usr/local/ESXI-update/HCL/lists/ip_file'

#read -s -p "請輸入ESXI passwd : " pw 
echo "" >> $log
echo "========================" >> $log
echo "| $date |" >> $log
echo "========================" >> $log

while getopts f:dt: arg
do
    case $arg in
        f) ### 原ESXi
           echo "FROM : $OPTARG" >> $log
		   from=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$OPTARG "esxcli network ip interface ipv4 get" |grep vmk0 |awk '{print $2}'`
           ;;
        d) ### 尾碼取得
           last=`echo $from |awk -F \. '{print $4}'`
		   echo "尾碼 : $last" >> $log
           ;;
        t) ### 目標ESXi
		   echo "TO   : $OPTARG" >> $log
           ip=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$OPTARG "esxcli network ip interface ipv4 get" |grep vmk0 |awk '{print $2}'`
		   t_sub_tmp=`echo $ip |awk -F \. '{print $4}'`
		   t_subnet=`echo "$ip" |sed "s/.${t_sub_tmp}$//g"`
		   echo "目標網段為: ${t_subnet}"
           ;;
    esac
done
echo "" >> $log

### buffer , 避免拿到重複IP
sleep 5
wait

### SSH check
timeout 4 bash -c "</dev/tcp/$ip/22" 2>/dev/null
ssh_check=`echo $?`
sleep 0.1
wait
if [ $ssh_check -eq "1" ];then
	echo "目標ping fail" >> $log
	exit 0 ### ping fail退出

elif [ $ssh_check -eq "0" ];then

### 維護模式確認
mode=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$from "esxcli system maintenanceMode get"`
if [ "$mode" == "Enabled" ];then

### 取得目標基本資訊 & 創建暫時腳本
	sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "exit"
	script="/tmp/$from.sh"
	echo "" > $script |tee > /dev/null 2>&1
	model=$(curl http://sys.chungyo.local/esxi_hardware/api/version/esxi_model.php?esxi_model=$from)
	vswitch_all=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard list" |grep vSwitch |grep -v Name |grep -v vSwitch0`
	vmkernel_all=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network ip interface ipv4 get" |grep vmk |awk '{print $1}' |grep -v vmk0`
	portgroup_all=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard portgroup list" |grep vSwitch |awk '{print $1}' |grep -v "Management Network"`
	nfs_all=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli storage nfs list" |egrep "true|false" |awk '{print $1}'`

### 更換管理段IP
	s_sub_tmp=`echo $from |awk -F \. '{print $4}'`
    s_subnet=`echo "$from" |sed "s/.${s_sub_tmp}$//g"`
	if [ "$t_subnet" == "$s_subnet" ];then	
		echo "$from 不需更換IP" >> $log
		echo ""> $ip_file ### 給其餘腳本使用	 

	elif [ "$t_subnet" != "$s_subnet" ];then
		nmap -sP "${t_subnet}.0/24" |grep "Nmap scan" |awk '{print $5}' |awk -F \. '{print $4}' |tee > $file	
		for i in $(seq 11 230);
    	do
			new_ip="${t_subnet}.$i"
        	if [ ! $(cat $file |grep -w $i) ];then
           	 	if [ ! "$(nmap -Pn ${new_ip} |grep "Nmap done" |awk -F \( '{print $2}' |awk -F \) '{print $1}' |grep "1 host up")" ];then
					new_ip_chk='OK'
           	    	echo "${new_ip} 可以用"
					curl -s -X POST https://api.telegram.org/bot"$bot"/sendMessage -d chat_id="$id" -d text="$(echo -e "時間: $date\n型號: $model\nHost: $from\n狀態: 管理IP已改為${new_ip} \n請於NMS資產表上更改")"
					echo "$new_ip" > $ip_file
					t_vmk=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network ip interface ipv4 get" |grep vmk0`
					t_vmk_mask=`echo ${t_vmk} |awk '{print $3}'`
					t_vmk_gw=`echo ${t_vmk} |awk '{print $6}'`
			
					### 寫入暫時腳本
					echo "esxcli network ip interface ipv4 set -i vmk0 -I $new_ip -g $t_vmk_gw -N $t_vmk_mask -t static" |tee >> $script
					
					### 更換尾碼 
					last=`echo ${new_ip} |awk -F \. '{print $4}'`
					break
					echo "" >> $log
           	 	else
           	     	echo "${new_ip}不可用" >> $log
           	 	fi
			else ### 無IP可用
				new_ip_chk='NO'
				echo "${new_ip}不可用" >> $log
			fi	
    	done
	fi

	if [ "$new_ip_chk" == 'NO' ];then
		curl -s -X POST https://api.telegram.org/bot"$bot"/sendMessage -d chat_id="$id" -d text="$(echo -e "時間: $date\n型號: $model\nHost: $from\n狀態: ${t_subnet}.0/24 無IP可用")"
	fi

### vSwitch
		for a in $(echo $vswitch_all)
		do
			vswitch=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard list" |grep -A13 $a |egrep "MTU|Uplinks|Portgroups|Name" |tr '\n' '|'`
			sw_name=`echo $vswitch |awk -F \| '{print$1}' |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
			sw_MTU=`echo $vswitch |awk -F \| '{print$2}' |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
#			sw_Uplink=`echo $vswitch |awk -F \| '{print$3}' |awk -F \: '{print $2}' |sed s/[[:space:]]//g |sed 's/\,/ /g'`
			sw_link1=`echo $vswitch |awk -F \| '{print$3}' |awk -F \: '{print $2}' |sed s/[[:space:]]//g |awk -F \, '{print $1}'`
			sw_link2=`echo $vswitch |awk -F \| '{print$3}' |awk -F \: '{print $2}' |sed s/[[:space:]]//g |awk -F \, '{print $2}'`
			sw_policy=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard policy failover get -v $a" |grep "Load Balancing" |awk -F \: '{print $2}' |sed 's/[[:space:]]//g'`
			echo "$sw_name | $sw_MTU | $sw_link1 | $sw_link2 | $sw_policy" >> $log
		### 寫入暫時腳本
			echo "esxcli network vswitch standard add -v $sw_name" >> $script
			echo "esxcli network vswitch standard set -v  $sw_name -m $sw_MTU" >> $script
			echo "esxcli network vswitch standard uplink add -u $sw_link1 -v $sw_name" >> $script
			echo "esxcli network vswitch standard uplink add -u $sw_link2 -v $sw_name" >> $script
			echo "esxcli network vswitch standard policy failover set -a ${sw_link1},${sw_link2} -v $a -l $sw_policy" >> $script
		done
		echo "" >> $log


### portgroup
		for c in $(echo $portgroup_all)
		do
			portgroup=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard portgroup list" |grep $c`
			pg_name=`echo $c |grep -v "Management"`
			pg_switch=`echo $portgroup |awk '{print $2}'`
			pg_vlan=`echo $portgroup |awk '{print $4}' |grep -v "Network"`
			echo "$pg_name | $pg_switch | $pg_vlan" |grep -v "Network" >> $log
		
		### 寫入暫時腳本
			if [ "$pg_name" -a "$pg_vlan" ];then
				echo "esxcli network vswitch standard portgroup add -p $pg_name -v $pg_switch" >> $script
				echo "esxcli network vswitch standard portgroup set -p $pg_name -v $pg_vlan" >> $script
			fi
		done
		echo "" >> $log


### vmkernel
		for b in $(echo $vmkernel_all)
   	 	do
        	vmkernel=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network ip interface ipv4 get" |grep $b`
        	kn_name=`echo $b`
       	 	kn_ip=`echo $vmkernel |awk '{print $2}'`
        	kn_mask=`echo $vmkernel |awk '{print $3}'`
    	    kn_gw=`echo $vmkernel |awk '{print $6}'`
       		kn_tmp1=`echo $kn_ip |awk -F \. '{print $1}'`
       		kn_tmp2=`echo $kn_ip |awk -F \. '{print $2}'`
       		kn_tmp3=`echo $kn_ip |awk -F \. '{print $3}'`
       	 	kn_check_ip=`echo "$kn_tmp1.$kn_tmp2.$kn_tmp3.$last"`
        	vmk_check=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "ping -c 2 $kn_check_ip" |grep "received" |awk -F \, '{print $3}' |awk -F \% '{print $1}' |sed s/[[:space:]]//g`
			vmotion=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "vim-cmd hostsvc/vmotion/netconfig_get" | grep vim.host.VirtualNic:VMotionConfig.vmotion.key-vim.host.VirtualNic |awk -F \- '{print $3}' |sed s/\>//g`
        	if [ "$vmk_check" == "0" ];then
           	 vmk_ip="Unusable"
#          	 curl -s -X POST https://api.telegram.org/bot"$bot"/sendMessage -d chat_id="$id" -d text="$(echo -e "時間: $date\n型號: $model\nHost: $from\n狀態: $b重複IP無法建立")"
        	elif [ "$vmk_check" == "100" -o "$vmk_check" == "" ];then
            	vmk_ip="$kn_check_ip"
        	fi
        	echo "$kn_name | $kn_ip | $kn_mask | $kn_gw" >> $log
        	echo "測試IP : $kn_check_ip , VMK_IP : $vmk_ip" >> $log

		#### 2021/08/02 新增MTU設定
			if [ "$vmk_ip" ];then
				kn_pg=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard portgroup list" |grep vSwitch |grep "$kn_tmp1.$kn_tmp2.$kn_tmp3" |awk '{print $1}'` ### 自訂
				kn_pg_tmp=`echo $kn_pg |awk -F \_ '{print $2}'`
				kn_mtu=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network vswitch standard list" |grep -B13 "$kn_pg" |grep "MTU" |awk -F \: '{print $2}' |sed 's/ //g'`
		
			#### 寫入暫時腳本	
			#echo $kn_pg_tmp
				if [ "$kn_pg_tmp" == "$kn_tmp1.$kn_tmp2.$kn_tmp3" ];then
					echo "$b 的portgroup : $kn_pg" >> $log
					echo "" >> $log
					echo "esxcli network ip interface add --interface-name=$b -p $kn_pg" >> $script
					echo "sleep 0.5 ; wait" >> $script
					echo "esxcli network ip interface ipv4 set -i $b -I $vmk_ip -N $kn_mask -t static" >> $script
					echo "esxcli network ip interface set -i $b -m $kn_mtu" >> $script
					echo "vim-cmd hostsvc/vmotion/vnic_set $vmotion" >> $script
				else
					echo "$b 無相對應portgroup" >> $log
					echo "" >> $log
				fi
			else
				echo "$kn_check_ip 無法使用" >> $log
				echo "" >> $log
			fi		
   		done
		echo "sleep 0.5 ; wait" >> $script

### NFS
		for d in $(echo $nfs_all)
		do
			nfs=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli storage nfs list" |grep -w $d`
			nfs_name=`echo $d`
			nfs_host=`echo $nfs |awk '{print $2}'`
			nfs_share=`echo $nfs |awk '{print $3}'`
			echo "$nfs_name | $nfs_host | $nfs_share" >> $log
		
		### 寫入暫時腳本
    	   	echo "esxcli storage nfs add -H $nfs_host -s $nfs_share -v $nfs_name" >> $script
		done
		echo "" >> $log

### License / 登記前設定license以避免被cluster拒絕
		license='5C2DM-20J1N-5ZTX8-UACE2-23XNL'

		### 寫入暫時腳本
		echo "vim-cmd vimsvc/license --set=$license" >> $script

	else
		echo "$from 須進入維護模式" >> $log
	fi		
	fi

### 執行暫時腳本後刪除
echo "--------------------------------------------------------------------------------" >> $log
echo "$from 開始執行腳本" >> $log
chmod +x "/tmp/$from.sh"
cat $script >> $log
echo "" >> $log
echo "==========================================================================================================================================" >> $log
echo "" >> $log
cat $script |sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$from "sh"
rm -rf $script


