#!/bin/bash
### First version : 2020/11/13
### Update date   : 2022/06/01
### Made by       : SYS-Juro
### Description   : Config ESXi SNMP,NTP,coredump,High-performance..etc

pw=/usr/local/ESXI-update/HCL/nimajuro
ip_list=$(cat /usr/local/ESXI-update/HCL/host_lists/Auto_move_list_2)
log='/usr/local/ESXI-update/Logs/work/esxi_setting.log_2'
license='5C2DM-20J1N-*****-UACE2-23XNL'

#read -p "要設定的ESXI_IP : " ip

time_stamp()
{
    echo "" >> $log
    echo "" >> $log
    echo "" >> $log
    echo "===================" >> $log
    /bin/date |awk '{print $6,$2,$3,$4}' >> $log
    echo "===================" >> $log
    echo "" >> $log
}

time_stamp
echo "參數對照 // IP , SNMP , NTP , CoreDump , PowerPolicy , TSO4 , TSO6 , LRO , Hostname , NFS_Volumes , Local_volume , License //" |tee >> $log

for ip in ${ip_list}
do
{
	timeout 4 bash -c "</dev/tcp/$ip/22" 2>/dev/null
	ssh_check=`echo $?`
	sleep 0.1
	wait
	if [ $ssh_check -eq "1" ];then
		echo "!!! $ip Host down !!!"

	elif [ $ssh_check -eq "0" ];then
		### 判斷是否為數字 -> 判斷站別
    	tmp1=$(echo $ip |awk -F \- '{print $1}' |cut -c 1)
    	tmp2=$(echo $ip |awk -F \. '{print $2}')
    	tmp3=$(echo $ip |awk -F \. '{print $1}' |awk -F \- '{print $1}' |cut -c 1)
    	if  [ "$tmp1" -gt 0 ] 2>/etc/null ; then ### 是數字
        	if [ "$tmp2" -eq 213 ];then
	            site="SZ"
        	elif [ "$tmp2" -eq 253 ];then
	            site="FU"
        	elif [ "$tmp2" -eq 246 ];then
	            site="AS"
        	elif [ "$tmp2" -eq 247 ];then
	            site="CQ"
        	elif [ "$tmp2" -eq 248 ];then
	            site="SH"
        	elif [ "$tmp2" -eq 250 ];then
	            site="HK"
        	elif [ "$tmp2" -eq 252 ];then
	            site="TPE"
        	else
	            site="ERROR1"
        	fi

    	else ### 是字串
            #echo "$tmp3"
        	if [ "$tmp3" == "a" -o "$tmp3" == "b" ];then
                site="AS"
            elif [ "$tmp3" == "t" ];then
                site="CQ"
            else
                site="ERROR2"
            fi
        fi

		#echo "====== 設定SNMP ======"
		snmp_key=$(sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system snmp get" |grep Communities |awk -F \: '{print $2}' |sed 's/^[ \t]*//g')
		snmp_enable=$(sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system snmp get" |grep Enable |awk -F \: '{print $2}' |sed 's/^[ \t]*//g')
		wait
		if [ "$snmp_enable" == "true" -a "$snmp_key" == "cyanyellowgreen168" ];then
			SNMP_chk="OK"
		else
			SNMP_chk="NO"
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system snmp set -e 1" |tee >> $log
        	sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system snmp set -c cyanyellowgreen168" |tee >> $log
			wait
		fi
		wait
	
		#echo "====== 設定NTP ======"

		ntp_set()
		{
			NTP_chk="NO"
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd stop"
            sshpass -f $pw scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HCL/shell_scripts/${site}-ntp.conf root@$ip:/tmp |tee >> $log
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "mv /tmp/ntp.conf /etc"
            sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/bin/ntpd -qg"
            sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd restart"
            wait
		}
		if [ "$site" == "SZ" ];then
        	ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |egrep "172.17.0.11|172.17.0.12|server 172.17.1.2|server 172.17.1.3" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "4" ];then
            	NTP_chk="OK"
        	else
				#echo "!!! NTP設定 !!!"
            	ntp_set
        	fi

		elif [ "$site" == "FU" ];then
			ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |egrep "192.168.136.244|192.168.138.33" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "2" ];then
            	NTP_chk="OK"
			else
				ntp_set
			fi

		elif [ "$site" == "AS" ];then
			ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |egrep "ntp1.sys.c2c|ntp2.sys.c2c|10.248.255.253" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "3" ];then
            	NTP_chk="OK"
			else
				ntp_set
			fi		

		elif [ "$site" == "CQ" ];then
			ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |egrep "192.168.138.33|192.168.138.34" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "2" ];then
            	NTP_chk="OK"
			else
				ntp_set
			fi
		
		elif [ "$site" == "SH" ];then
			ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |egrep "192.168.138.33|192.168.138.34" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "2" ];then
            	NTP_chk="OK"
			else
				ntp_set
			fi

		elif [ "$site" == "HK" ];then
			ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |egrep "10.248.255.253|10.249.255.253" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "2" ];then
            	NTP_chk="OK"
			else
				ntp_set
			fi

		elif [ "$site" == "TPE" ];then
			ntp_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "/etc/init.d/ntpd status" |awk '{print $3}'`
        	ntp_server=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "cat /etc/ntp.conf" |grep -Fv "#" |grep -w "10.249.255.253" |wc -l`
        	wait
        	if [ "$ntp_en" == "running" -a $ntp_server -eq "1" ];then
            	NTP_chk="OK"
			else
				ntp_set
			fi
		else
			echo "*** ${ip}的Site: ${site}不存在" >> $log
		fi
        wait
				
		#echo "====== 設定Core_dump ======"
		core_en=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network get" |grep Enabled |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		core_ip=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network get" |grep "Network Server IP" |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		wait
		
		if [ "$site" == "SZ" -o "$site" == "FU" ];then
			if [ "$core_en" == "true" -a "$core_ip" == "10.213.10.10" ];then
				CoreD_chk="OK"
			else
				#echo "!!! Coredump設定 !!!"
				CoreD_chk="NO"
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip	"esxcli system coredump network set --enable false" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --interface-name vmk0 --server-ipv4 10.213.10.10 --server-port 6500" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --enable true" |tee >> $log
				wait
			fi

		elif [ "$site" == "AS" ];then
			if [ "$core_en" == "true" -a "$core_ip" == "10.246.8.239" ];then
				CoreD_chk="OK"
			else
				#echo "!!! Coredump設定 !!!"
				CoreD_chk="NO"
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip	"esxcli system coredump network set --enable false" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --interface-name vmk0 --server-ipv4 10.246.8.239 --server-port 6500" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --enable true" |tee >> $log
				wait
			fi
		
		elif [ "$site" == "CQ" ];then
			if [ "$core_en" == "true" -a "$core_ip" == "10.247.15.239" ];then
				CoreD_chk="OK"
			else
				#echo "!!! Coredump設定 !!!"
				CoreD_chk="NO"
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip	"esxcli system coredump network set --enable false" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --interface-name vmk0 --server-ipv4 10.247.15.239 --server-port 6500" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --enable true" |tee >> $log
				wait
			fi

		elif [ "$site" == "SH" ];then
			if [ "$core_en" == "true" -a "$core_ip" == "10.248.15.239" ];then
				CoreD_chk="OK"
			else
				#echo "!!! Coredump設定 !!!"
				CoreD_chk="NO"
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip	"esxcli system coredump network set --enable false" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --interface-name vmk0 --server-ipv4 10.248.15.239 --server-port 6500" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --enable true" |tee >> $log
				wait
			fi

		elif [ "$site" == "HK" ];then
			if [ "$core_en" == "true" -a "$core_ip" == "10.250.10.10" ];then
				CoreD_chk="OK"
			else
				#echo "!!! Coredump設定 !!!"
				CoreD_chk="NO"
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip	"esxcli system coredump network set --enable false" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --interface-name vmk0 --server-ipv4 10.250.10.10 --server-port 6500" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --enable true" |tee >> $log
				wait
			fi

		elif [ "$site" == "TPE" ];then
			if [ "$core_en" == "true" -a "$core_ip" == "10.252.10.10" ];then
				CoreD_chk="OK"
			else
				#echo "!!! Coredump設定 !!!"
				CoreD_chk="NO"
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip	"esxcli system coredump network set --enable false" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --interface-name vmk0 --server-ipv4 10.252.10.10 --server-port 6500" |tee >> $log
				sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system coredump network set --enable true" |tee >> $log
				wait
			fi
		fi
		wait


		#echo "====== 設定Power Policy ======"
		fwrule=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced list --option=/Power/CpuPolicy" |grep "String Value" |grep -v "Default" |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		wait
		if [ "$fwrule" == "HighPerformance" ];then
			#echo "* 電力設定設定 OK"
			Power_chk="OK"
		else
			#echo "!!! 電力設定 !!!"
			Power_chk="NO"
        	sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced set --option=/Power/CpuPolicy --string-value='High Performance'" |tee >> $log
			wait
		fi
		wait


		#echo "===== 網卡TSO/LRO設定 ====="

		TSO_4=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced list -o /Net/UseHwTSO" |grep "Int Value" |grep -v "Default" |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		wait
		
		TSO_6=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced list -o /Net/UseHwTSO6" |grep "Int Value" |grep -v "Default" |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		wait

		LRO=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced list -o /Net/Vmxnet3HwLRO" |grep "Int Value" |grep -v "Default" |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		wait

		if [ "$TSO_4" == "0" ];then
			#echo "* TSO4設定 OK"
			TSO4_chk="OK"
		else
			#echo "!!! TSO4設定 !!!"
			TSO4_chk="NO"
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced set -o /Net/UseHwTSO -i 0" |tee >> $log
			wait
		fi
		wait

		if [ "$TSO_6" == "0" ];then
			#echo "* TSO6設定 OK"
			TSO6_chk="OK"
		else
			#echo "!!! TSO6設定 !!!"
			TSO6_chk="NO"
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced set -o /Net/UseHwTSO6 -i 0" |tee >> $log
			wait
		fi
		wait

		if [ "$LRO" == "0" ];then
			#echo "* LRO設定  OK"
			LRO_chk="OK"
		else
			#echo "!!! LRO設定 !!!"
			LRO_chk="NO"
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced set -o /Net/Vmxnet3HwLRO -i 0" |tee >> $log
			wait
		fi
		wait

		### Hostname check ###

		if [ "$site" == "SZ"  -o "$site" == "FU" -o "$site" == "SH" -o "$site" == "HK" -o "$site" == "TPE" ];then
        	name_tmp=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname get" |grep "Host Name" |awk -F \: '{print $2}' |sed 's/\ //g' |awk -F \- '{print $2,$3,$4,$5}' |sed 's/\ /\./g'`
        	if [ "$ip" == "$name_tmp" ];then
            	name_chk="OK"

        	else
	            name_chk="NO"
    	        new_name_tmp=`echo $ip |sed 's/\./\-/g'`
        	    hostname="${site}-$new_name_tmp"
            	sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname set --host=$hostname"
        	fi

		elif [ "$site" == "CQ" ];then
			name_tmp=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname get" |grep "Host Name" |awk -F \: '{print $2}' |sed 's/\ //g'`
			if [ `echo "$name_tmp" |awk -F \- '{print $2}' |cut -c 1` == "u" ];then ### t04-u25
				if [ "$name_tmp" == `echo "$ip" |sed 's/\.esxi\.cq//g'` ];then
					name_chk="OK" 
				else
					name_chk="NO"
					hostname=`echo "$ip" |sed 's/\.esxi\.cq//g'`
            		sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname set --host=$hostname"
				fi
			elif [ `echo "$name_tmp" |awk -F \- '{print $2,$3,$4,$5}' |sed 's/\ /\./g'` == "$ip" ];then ### CQ-10-247-15-24
				name_chk="OK"
			else
				name_chk="NO"
				new_name_tmp=`echo $ip |sed 's/\./\-/g'`
        	    hostname="${site}-${new_name_tmp}"
            	sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname set --host=${hostname}"
			fi
		
		elif [ "$site" == "AS" ];then
			name_tmp=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname get" |grep "Host Name" |awk -F \: '{print $2}' |sed 's/\ //g'`
			if [ "$name_tmp" == `echo $ip |sed 's/\.esxi\.c2c//g'` ];then
				name_chk="OK"
			else
				name_chk="NO"
        	    hostname=`echo $ip |sed 's/\.esxi\.c2c//g'`
            	sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system hostname set --host=${hostname}"
			fi
		else
			echo "*** ${ip}的Site: ${site}不存在" >> $log
		fi


		### NFS.MaxVolumes check ###
		volume_tmp=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced list -o '/NFS/MaxVolumes'" |grep 'Int Value' |grep -v 'Default' |awk -F \: '{print $2}' |sed s/[[:space:]]//g`
		if [ "$volume_tmp"  == "256" ];then
			volume_chk="OK"
		else
			volume_chk="NO"
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli system settings advanced set -o '/NFS/MaxVolumes' -i 256"	
		fi

		### local volume_name check ### 2022/06/01
		local_volume=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "ls /vmfs/volumes" |grep -i 'datastore1'`
		if [ "$local_volume" ];then
			local_disk_chk="NO"
			mgt_ip=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "esxcli network ip interface ipv4 get" |grep vmk0 |awk '{print $2}' |sed 's/[[:space:]]//g'`		
			### 名稱修正
			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "vim-cmd hostsvc/datastore/rename '$local_volume' 'local_${mgt_ip}'"
		else
			local_disk_chk="OK"
		fi				

		### License check ### 2022/09/20 -> 轉移至鏡像時動作
#		lic=`sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "vim-cmd vimsvc/license --show" |grep 'serial:' |awk -F \: '{print $2}' |sed 's/[[:space:]]//g'`
#		if [ "$lic" == "$license" ];then
#			Lic_chk='OK'
#		else
#			Lic_chk='NO'
#			sshpass -f $pw ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip "vim-cmd vimsvc/license --set=$license"
#		fi

		### 輸出結果
#        echo "$ip","$SNMP_chk","$NTP_chk","$CoreD_chk","$Power_chk","$TSO4_chk","$TSO6_chk,$LRO_chk","$name_chk","$volume_chk","$local_disk_chk","$Lic_chk" |tee >> $log
		echo "$ip","$SNMP_chk","$NTP_chk","$CoreD_chk","$Power_chk","$TSO4_chk","$TSO6_chk,$LRO_chk","$name_chk","$volume_chk","$local_disk_chk" |tee >> $log
	fi
}&

### 最多線程數設定
NPROC=$(($NPROC+1))
if [ "$NPROC" -ge 15 ]; then
	wait
	NPROC=0
fi
done

