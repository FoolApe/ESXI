#!/bin/bash
### Made by : SYS-Juro
### Update date : 2022/02/18
###				  2022/06/06	R640 IPMI version update

### Description : Dell auto_update script ==> Must install RACADM first

###  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
###  @@@   For Dell servers only   @@@
###  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
### !!!!!   Make sure the updated servers are in maintainance mode   !!!!!
### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

######################################################################################
### 宣告變數

esxi_pass=`cat /Path/To/Your/Pass`
ipmi_pass=`cat /Path/To/Your/Pass2`
dir='/Path/To/Your/Dir'

control=`cat $dir/control2`
control_dir=$dir/control2

api='http://10.249.34.51/api/esxi_info.php'
token='d70083451462**********006a729a69'

Dell_updatedir=/Path/To/Your/Dir/Update_pack
move_script='/usr/local/ESXI-update/HCL/power_shell/esxi-move-update-folder-Dell_v2.ps1'
common_log=/Path/To/Your/Logs

old=/Path/To/Your/Dell_Update_list2 
new=/Path/To/Your/host_lists/Update_list_2

ok_list='/Path/To/Your/update_ok_Dell_2'
fail_list='/Path/To/Your/update_fail_Dell_2'

######################################################################################

### 取得最新清單

cat $new |tee > $old
esxi=`cat $old |grep -v "^$"|sed 's/\                              /\@/g'`

######################################################################################

### log時間戳
time_stamp()
{
	echo "" 
	echo ""
	echo "====================" 
	/bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' 
	echo "===================="
}

######################################################################################

### 卡控設定
control_run()
{
	echo "running" > $control_dir
}

control_ok()
{
	echo "available" > $control_dir
}

######################################################################################

### 觸發機制

if [ ! -n "$esxi" ];then
	time_stamp |tee >> $common_log
    echo "******* No Host in Update ******* " |tee >> $common_log
	echo "" |tee >> $common_log
    exit 0
else

 ### 卡控機制
	if [ $control == "running" ];then
    	time_stamp |tee >> $common_log
        echo "******* Update script is running *******" |tee >> $common_log
		echo "" |tee >> $common_log
        exit 0
	
    elif [ $control == "available" ];then
 	 ### 改變卡控狀態
        control_run
		sleep 5s 
		wait

		for x in $esxi
		do
			### 檢查host是否能ssh
			x=$(echo $x |sed 's/\@/\ /g' |awk '{print $2}')
			#echo $x
			#x=$(echo $x |awk '{print $2}')
			site=$(echo $x |awk '{print $1}' |awk -F \/ '{print $2}')
			ip=$(sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli network ip interface ipv4 get" |grep vmk0 |awk '{print $2}')
        	timeout 4 bash -c "</dev/tcp/$ip/22" 2>/dev/null
        	ssh_check=`echo $?`
        	sleep 0.1
        	wait	
        	if [ $ssh_check -eq "1" ];then
            	echo "******* $x Host down *******" |tee >> $common_log

        	elif [ $ssh_check -eq "0" ];then	
				### 取得IPMI_ip ,維護模式,廠商資訊
				cat /root/.ssh/id_rsa.pub | sshpass -p "$esxi_pass"	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x 'cat >>/etc/ssh/keys-root/authorized_keys'
				ipmi=`curl -s "$api?token=$token&host=$ip&type=IPMI"`
				mode=`curl -s "$api?token=$token&host=$ip&type=Mode"`
				vendor=`curl -s "$api?token=$token&host=$ip&type=Vendor"`
				SN=`curl -s "$api?token=$token&host=$ip&type=SN"`
				model=$(sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli hardware platform get" |grep "Product" |awk -F \: '{print $2}' |sed 's/PowerEdge//g' |sed 's/[[:space:]]//g') 
	
				### 取得SSID,Disk_check tool
				RAID_ssid=$(curl http://sys.chungyo.local/esxi_hardware/api/raid/esxi_raid_id_api.php?esxi_id=$x)
				NET_ssid=$(curl http://sys.chungyo.local/esxi_hardware/api/network/esxi_nic_id_api.php?esxi_id=$x)
				Disk=$(curl http://10.249.34.13/esxi_hardware/api/raid/esxi_disk_vib.php?disk_vib=$x)
				mellenox=$(sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib list" |grep -i nmst)
				mft=$(sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib list" |grep -i mft)

				### 產生各自的Log
	    	    Dell_log=/usr/local/ESXI-update/Logs/Dell/$SN-update.log
		        touch $Dell_log
				time_stamp |tee > $Dell_log
	 
				### Common_log導出
				echo "===================" |tee >> $common_log
				/bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' |tee >> $common_log
				echo "===================" |tee >> $common_log
				echo "$x,$ipmi,$mode,$vendor,$SN" |tee >> $common_log
				echo "" |tee >> $common_log

					
				# Dell 更新,BIOS -> RAID -> NET -> IPMI 
				if [ `echo $mode` == "Enabled" -a `echo $vendor` == "Dell" ] 2>/dev/null ;then
					# ~~~~~~~~~~ BIOS ~~~~~~~~~~
					if [ `echo $model` == "R630" ];then
						echo "" |tee >> $Dell_log
						echo "***** 更新 R630-BIOS *****" |tee >> $Dell_log
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/BIOS_2JFRF_WN64_2.8.0_01.EXE |tee >> $Dell_log 
						sleep 90s
		
					elif [ `echo $model` == "R640" ];then
						echo "" |tee >> $Dell_log
						echo "***** 更新 R640-BIOS *****" |tee >> $Dell_log
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/BIOS_92RFG_WN64_2.11.2.EXE |tee >> $Dell_log
						sleep 3m
	
					elif [ `echo $model` == "XC640-10" ];then
						echo "" |tee >> $Dell_log
	                	echo "***** 更新 XC640-BIOS *****" |tee >> $Dell_log
	               		/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/BIOS_422T0_WN64_1.4.9.EXE |tee >> $Dell_log
						sleep 3m
	
					else
						echo "" |tee >> $Dell_log
	                	echo "***** 需新增 `echo $model` BIOS更新包 *****" |tee >> $Dell_log
						echo ""
					fi

					# ~~~~~~~~~~ RAID ~~~~~~~~~~
					wait
					
					echo "" |tee >> $Dell_log
					echo "***** 更新RAID卡 *****" |tee >> $Dell_log
					if [ $RAID_ssid == "1000:****:1028:1f47" -o $RAID_ssid == "1000:005d:****:1f49" ];then
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/SAS-RAID_Firmware_F675Y_WN64_25.5.5.0005_A13_01.EXE |tee >> $Dell_log
						sleep 90s
						wait
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/ef225d93-ec0ff12b/Dell/driver/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip" |tee >> $Dell_log
						else
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/Dell/driver/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /tmp/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip" |tee >> $Dell_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip" |tee >> $Dell_log
						fi

					elif [ ! -n "$RAID_ssid" ];then
						echo "***** 無RAID卡 *****" |tee >> $Dell_log
			
					else
						echo "******* 需新增 $RAID_ssid 更新包 *******" |tee >> $Dell_log
					fi
	
					# ~~~~~~~~~~  Net  ~~~~~~~~~~
					wait
					echo "" |tee >> $Dell_log
					echo "***** 更新網卡 *****" |tee >> $Dell_log
					if [ $NET_ssid == "8086:1572:****:1f99" ];then
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/Network_Firmware_539P6_WN64_18.0.17_A00.EXE |tee >> $Dell_log
						sleep 3m
						wait
						### i40 較麻煩,需跑腳本	
						cat /usr/local/ESXI-update/Dell/update_nic_dri.sh | sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x /bin/sh

					elif [ $NET_ssid == "8086:1572:****:0006" ];then
                   		/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/Network_Firmware_539P6_WN64_18.0.17_A00.EXE |tee >> $Dell_log
                   		sleep 3m
                  		wait
						### i40 較麻煩,需跑腳本 
                    	cat /usr/local/ESXI-update/Dell/update_nic_dri.sh | sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x /bin/sh
			
					elif [ $NET_ssid == "15b3:****:15b3:0025" ];then
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/Network_Firmware_0XN9N_WN64_14.25.80.00.EXE |tee >> $Dell_log
						sleep 2m
						wait
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/ef225d93-ec0ff12b/Dell/driver/MLNX/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip" |tee >> $Dell_log
						else
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/Dell/driver/MLNX/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /tmp/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip" |tee >> $Dell_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip" |tee >> $Dell_log
						fi
					else
						echo "******* 需新增 $NET_ssid 更新包 *******" |tee >> $Dell_log
					fi
					wait

					### 安裝Disk_check tool
					echo "****** 安裝Disk tool ******" |tee >> $Dell_log
					if [ "$Disk" == "OK" ];then
						echo "安裝完成" |tee >> $Dell_log
	
					elif [ "$Disk" == "ERROR" ];then
						echo "開始安裝" |tee >> $Dell_log
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/Dell/driver/esxi_perccli.vib" |tee >> $Dell_log	
						else
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/Dell/driver/esxi_perccli.vib root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/esxi_perccli.vib" |tee >> $Dell_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/esxi_perccli.vib"
						fi
					else
						echo "****** 安裝Disk tool異常 ******" |tee >> $Dell_log
					fi

					### 安裝Mellanox驅動
					echo "" |tee >> $Dell_log
					echo "****** 安裝Mellanox驅動 ******" |tee >> $Dell_log
					if [ "$mellanox" ];then
						echo "nmst已安裝" |tee >> $Dell_log
					else
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $Dell_log
						else
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee > $Dell_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib"
						fi
					fi

					if [ "$mft" ];then
						echo "mft已安裝" |tee >> $Dell_log
					else
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $Dell_log
						else
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $Dell_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib"
						fi
					fi

					# ~~~~~~~~~~ Job Check ~~~~~~~~~~
					wait
					echo "" |tee >> $Dell_log
					echo "***** 確認Job建立中 *****" |tee >> $Dell_log
					job_fail=`/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass jobqueue view | egrep -B1 -A5 "Firmware Update" |grep "Status" |awk -F \= '{print $2}' |grep "Failed"`
					sleep 30s
					wait

					# ~~~~~~~~~~ IPMI ~~~~~~~~~~
					echo "" |tee >> $Dell_log
					echo "***** 更新IPMI *****" |tee >> $Dell_log
					if [ `echo $model` == "R640" ];then
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/iDRAC-with-Lifecycle-Controller_Firmware_FPTF1_WN64_5.10.10.00_A00.EXE |tee >> $Dell_log
						wait
					elif [ `echo $model` == "R630" ];then
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass update -f $Dell_updatedir/iDRAC-with-Lifecycle-Controller_Firmware_5HN4R_WN64_2.81.81.81_A00.EXE |tee >> $Dell_log
						wait

					else
						echo "***** 需新增 $model 的IPMI版本" |tee >> $Dell_log
					fi
					wait

					# ~~~~~~~~~~ 呼叫搬移 ~~~~~~~~~~
					 ### Job建立成功 ###
    	        	if [ ! -n "$job_fail" ];then 
						echo "***** Job建立成功 *****" |tee >> $Dell_log
	                	echo "$x" > $ok_list
	                	pwsh $move_script |tee >> $Dell_log
			
					 ### Job建立失敗 ###
    	        	else
        	        	echo "***** 清除Job *****" |tee >> $Dell_log
	                	echo "$x" >> $fail_list
	     	        	echo "$x" > $ok_list
						/opt/dell/srvadmin/sbin/racadm -r $ipmi -u root -p $ipmi_pass jobqueue delete -i JID_CLEARALL_FORCE |tee > $Dell_log
    	            	pwsh $move_script |tee >> $Dell_log
					fi
	
					# ~~~~~~~~~~ Reboot ~~~~~~~~~~
					echo "****** $x Reboot ******" |tee >> $Dell_log
					sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot"		

				 ### 不支援廠商或沒進入maintainance_mode
				else
					echo "* * * * * $x ======> Check Maintainance_mode or Server_Vendor * * * * *" |tee >> $common_log
					echo "" >> $common_log
				fi
    		else
        		echo "***** SSH_check ERROR *****" |tee >> $Dell_log
        		echo "" |tee >> $Dell_log
    		fi
		done	
	else
		time_stamp
		echo "***** Script Error *****" |tee >> $Dell_log
        control_ok
		exit 0
    fi
fi

### 程式結束清空更新清單
echo ""  > $old

### 改變卡控狀態
control_ok