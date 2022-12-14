#!/bin/bash
### Made by : SYS-Juro
### Update date : 2022/02/16
###				  2022/10/25 修改boot mode 為UEFI mode
###				  2022/11/24 修改AdaptorOption 為 Auto
###							 修改EtherNet over USB 為 disable

### Description : Lenovo auto_update script ==> Must install One-Cli first

### @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
### @@@    For Lenovo servers only   @@@@@
### @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
### !!!!!   Make sure the updated servers are in maintainance mode   !!!!!
### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

######################################################################################
### 宣告變數
Lenovo_updatedir='/Path/To/Your/Dir'
old='/Path/To/Your/Lenovo_Update_list_2'
new='/Path/To/Your/Update_list_2'
ok='/Path/To/Your/update_ok_Lenovo2'

api='http://10.249.34.51/api/esxi_info.php'
token='d70083451462**********006a729a69'
oneCLI='/Path/To/Your/OneCli'
move_script='/Path/To/Your/esxi-move-update-folder_v2.ps1'

esxi_pass=`cat /Path/To/Your/Pass`
ipmi_pass=`cat /Path/To/Your/Pass2`

### Controller
control=`cat /Path/To/Your/control_2`
control_dir='/Path/To/Your/control_2'

common_log='/Path/To/Your/Logs'

######################################################################################

cat $new |tee > $old
esxi=`cat $old |sed 's/\                              /\@/g'|grep -v "^$"`

######################################################################################
### Log時間戳
time_stamp() 
{
	echo "" 
	echo "" 
	echo "" 
	echo "====================" 
	/bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' 
	echo "===================="
	echo ""
}

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
	echo "******* No Host in Update *******" |tee >> $common_log
	echo "" |tee >> $common_log
	exit 0 
else
	### 卡控機制
	if [ $control == "running" ];then
		time_stamp
		echo "******* Update script is running *******" |tee >> $common_log
		exit 0

	elif [ $control == "available" ];then
	 ### 主程式開始

	 #########################################################################################################################################

	 ### 改變卡控狀態
    	time_stamp |tee >> $common_log
        echo "******* 更新程式開始 *******" |tee >> $common_log
		control_run
		sleep 0.2
		wait
				
	 ### 取得IPMI_ip , 廠商 , SN
		for x in $esxi
		do
			### 宣告IP/Site
			site=`echo $x |awk -F \@ '{print $1}' |awk -F \/ '{print $2}'`
			x=`echo $x |awk -F \@ '{print $2}'`
			ip=`sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli network ip interface ipv4 get" |grep vmk0 |awk '{print $2}'`

			### SSH check
			timeout 4 bash -c "</dev/tcp/$ip/22" 2>/dev/null
        	ssh_check=`echo $?`
        	sleep 0.1
        	wait
        	if [ $ssh_check -eq "1" ];then
            	echo "******* $x Host down *******" |tee >> $common_log

        	elif [ $ssh_check -eq "0" ];then		
				ipmi=`curl -s "$api?token=$token&host=$ip&type=IPMI"`
				mode=`curl -s "$api?token=$token&host=$ip&type=Mode"`
				vendor=`curl -s "$api?token=$token&host=$ip&type=Vendor"`
				SN=`curl -s "$api?token=$token&host=$ip&type=SN"`

				### 產生各自的LOG
				Lenovo_log="/Path/To/Your/${SN}-update.log"
	            touch $Lenovo_log
	            time_stamp |tee > $Lenovo_log
			
				### 取得SSID,disk_check
				RAID_ssid=$(curl http://sys.chungyo.local/esxi_hardware/api/raid/esxi_raid_id_api.php?esxi_id=$x)
				NET_ssid=$(curl http://sys.chungyo.local/esxi_hardware/api/network/esxi_nic_id_api.php?esxi_id=$x)
				Disk=$(curl http://10.249.34.13/esxi_hardware/api/raid/esxi_disk_vib.php?disk_vib=$x)

				### Common_log導出
				/bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' |tee >> $common_log
				echo "$x,$ipmi,$mode,$vendor" |tee >> $common_log
				echo "" |tee >> $common_log

				### Lenovo 更新,fw自動偵測
				if [ $mode == "Enabled" -a $vendor == "Lenovo" ] 2>/dev/null ;then
					### 設定為UEFI MODE
					/Path/To/Your/OneCli config set IMM.SystemNextBootMode "UEFI" -b USERID:$ipmi_pass@$ipmi ### change
					if [ "$site" == "SZ" ];then
						echo ""
						### RAID
						wait
						echo ""
						echo "******* 更新RAID驅動 *******" >> $Lenovo_log
				   		if [ "$RAID_ssid" == "1000:0016:****:0601" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/ef******-ec0ff12b/Lenovo/driver/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip" |tee >> $Lenovo_log	
						else		
							echo "****** 需新增 $RAID_ssid 更新包 ******" |tee >> $Lenovo_log
						fi

						### Net 
						echo "" |tee >> $Lenovo_log
						echo "******* 更新網卡驅動 *******" |tee >> $Lenovo_log
						if [ "$NET_ssid" == "15b3:****:15b3:0058" ];then	
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/ef******-ec0ff12b/Lenovo/driver/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip" |tee >> $Lenovo_log
							
						else
							echo "****** 需新增 $NET_ssid 更新包 ******" |tee >> $Lenovo_log
						fi

						### FW 更新
						echo ""
						echo "****** 更新韌體 ******" |tee >> $Lenovo_log
						$oneCLI update flash --noreboot -b USERID:$ipmi_pass@$ipmi --dir $Lenovo_updatedir --nolog |tee >> $Lenovo_log

						### 檢查Disk check tool
						echo "****** 安裝Disk tool ******" |tee >> $Lenovo_log
						if [ "$Disk" == "OK" ];then
							echo "Disk tool已安裝." |tee >> $Lenovo_log
	
						elif [ "$Disk" == "ERROR" ];then
							echo "開始安裝Disk tool." |tee >> $Lenovo_log
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef******-ec0ff12b/Lenovo/driver/esxi_storcli.vib --no-sig-check" |tee >> $Lenovo_log

						else
							echo "****** Disk tool偵測異常 ******"
						fi

						### 安裝Mellanox驅動
						echo "****** 安裝Mellonox driver ******"
						sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef******-ec0ff12b/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $Lenovo_log
						sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef******-ec0ff12b/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $Lenovo_log
	
						### Check log
						wait
						echo ""	|tee >> $Lenovo_log
						echo "******* 取得log *******" |tee >> $Lenovo_log
						$oneCLI inventory getinfor --device bmc_event_logs --output /usr/local/ESXI-update/Logs/onecli_log -b USERID:$ipmi_pass@$ipmi |tee > Path/To/Your/log_check
						sleep 30s	

						### Log判斷更新是否成功
						wait
						loggg=`cat Path/To/Your/log_check |grep "writing inventory result to" |awk '{print $7}'`
						cat $loggg |grep " by Tools" |uniq |tee >> $Lenovo_log
		
						#	if {更新成功判斷};then
						echo "$x" > $ok
						time_stamp

						### 重啟前調整設定, 避免IPMI抓不到adaptor資訊/ 關閉vusb0
						$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardsSATA Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardSATA Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardVideo Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.Slot1 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.Slot2 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.Slot3 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.Slot4 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.Slot5 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardLANPort1 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardLANPort2 Auto -b USERID:$ipmi_pass@$ipmi
						$oneCLI config set IMM.LanOverUsb Disabled -b USERID:$ipmi_pass@$ipmi
						echo "******* $x BMC restart *******" |tee >> $Lenovo_log
						$oneCLI misc rebootimm --nolog -b USERID:$ipmi_pass@$ipmi
						#	else {更新失敗判斷};then
						#		其他動作
						#	fi

						### 呼叫搬移
						/bin/pwsh $move_script
						sleep 5s
	
						### Reboot
						wait
						echo "******* 重開機 *******" |tee >> $Lenovo_log
						sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot"
						
					elif [ "$site" != "SZ" ];then
						echo ""
						### RAID
						wait
						echo ""
						echo "******* 更新RAID驅動 *******" >> $Lenovo_log
				    	if [ "$RAID_ssid" == "1000:0016:****:0601" ];then
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/Lenovo/driver/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip  root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /tmp/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip" |tee >> $Lenovo_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/VMW-ESX-6.5.0-lsi_mr3-7.705.10.00-offline_bundle-11658035.zip"

						else		
							echo "****** 需新增 $RAID_ssid 更新包 ******" |tee >> $Lenovo_log
						fi

						### Net 
						echo "" |tee >> $Lenovo_log
						echo "******* 更新網卡驅動 *******" |tee >> $Lenovo_log
						if [ "$NET_ssid" == "15b3:****:15b3:0058" ];then
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/Lenovo/driver/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /tmp/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip" |tee >> $Lenovo_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/MLNX-NATIVE-ESX-ConnectX-4-5_4.16.13.5-10EM-650.0.0-offline_bundle-8277601.zip"
							
						else
							echo "****** 需新增 $NET_ssid 更新包 ******" |tee >> $Lenovo_log
						fi

						### FW 更新
						echo ""
						echo "****** 更新韌體 ******" |tee >> $Lenovo_log
						$oneCLI update flash --noreboot -b USERID:$ipmi_pass@$ipmi --dir $Lenovo_updatedir --nolog |tee >> $Lenovo_log

                        ### 安裝Mellanox驅動
                        echo "****** 安裝Mellonox driver ******"
						sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib root@$x:/tmp
						sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $Lenovo_log

						sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib root@$x:/tmp
                        sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $Lenovo_log

						### 檢查Disk check tool
						echo "****** 安裝Disk tool ******"
						if [ "$Disk" == "OK" ];then
							echo "Disk_tool已安裝" |tee >> $Lenovo_log
							echo "$x" > $ok
	                        time_stamp
    	                    echo "******* $x BMC restart *******" |tee >> $Lenovo_log
        	                $oneCLI misc rebootimm --nolog -b USERID:$ipmi_pass@$ipmi
							### 呼叫搬移
                        	/bin/pwsh $move_script
                        	sleep 5s

                        	### Reboot
                        	wait
							$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardsSATA Auto -b USERID:$ipmi_pass@$ipmi
	                        $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardSATA Auto -b USERID:$ipmi_pass@$ipmi
    	                    $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardVideo Auto -b USERID:$ipmi_pass@$ipmi
        	                $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot1 Auto -b USERID:$ipmi_pass@$ipmi
            	            $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot2 Auto -b USERID:$ipmi_pass@$ipmi
                	        $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot3 Auto -b USERID:$ipmi_pass@$ipmi
                    	    $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot4 Auto -b USERID:$ipmi_pass@$ipmi
                        	$oneCLI config set EnableDisableAdapterOptionROMSupport.Slot5 Auto -b USERID:$ipmi_pass@$ipmi
	                        $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardLANPort1 Auto -b USERID:$ipmi_pass@$ipmi
    	                    $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardLANPort2 Auto -b USERID:$ipmi_pass@$ipmi
        	                $oneCLI config set IMM.LanOverUsb Disabled -b USERID:$ipmi_pass@$ipmi
                        	echo "******* 重開機 *******" |tee >> $Lenovo_log
                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot"
	
						elif [ "$Disk" == "ERROR" ];then
							echo "開始安裝" |tee >> $Lenovo_log
							sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/Lenovo/driver/esxi_storcli.vib root@$x:/tmp
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/esxi_storcli.vib --no-sig-check" |tee >> $Lenovo_log
							wait
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "rm -rf /tmp/esxi_storcli.vib"
							### Reboot
                            wait
							$oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardsSATA Auto -b USERID:$ipmi_pass@$ipmi
	                        $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardSATA Auto -b USERID:$ipmi_pass@$ipmi
    	                    $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardVideo Auto -b USERID:$ipmi_pass@$ipmi
        	                $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot1 Auto -b USERID:$ipmi_pass@$ipmi
            	            $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot2 Auto -b USERID:$ipmi_pass@$ipmi
                	        $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot3 Auto -b USERID:$ipmi_pass@$ipmi
                    	    $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot4 Auto -b USERID:$ipmi_pass@$ipmi
	                        $oneCLI config set EnableDisableAdapterOptionROMSupport.Slot5 Auto -b USERID:$ipmi_pass@$ipmi
    	                    $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardLANPort1 Auto -b USERID:$ipmi_pass@$ipmi
        	                $oneCLI config set EnableDisableAdapterOptionROMSupport.OnboardLANPort2 Auto -b USERID:$ipmi_pass@$ipmi
            	            $oneCLI config set IMM.LanOverUsb Disabled -b USERID:$ipmi_pass@$ipmi
                            echo "******* 重開機 *******" |tee >> $Lenovo_log
                            sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot"

						else
							echo "****** Disk tool偵測異常 ******"
						fi
					fi

				 ### 不支援廠商或沒進入maintainance_mode
				else
					if [ $vendor == "IBM" ];then
						echo "***** $x M4/M5不支援 *****" |tee >> $common_log					
	
					else
						echo "***** $x ======> Check Maintainance_mode or Vendor *****" |tee >> $Lenovo_log
					fi
				fi
				echo "===================================================" |tee >> $common_log
    		else
        		echo "******* SSH_check ERROR *******" |tee >> $Lenovo_log
        		echo "" |tee >> $Lenovo_log
			fi	
		done
	else
		time_stamp
		echo "******* Script Error *******" |tee >> $Lenovo_log
		control_ok
		exit 0  
	fi
fi

### 程式結束清空更新清單及log
echo ""  > $old

### 程式結束更改狀態
control_ok