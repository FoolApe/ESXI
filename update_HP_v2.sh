#!/bin/bash
### Made by : SYS-Juro
### Update date : 2022/04/07

### Description : Must install 更新包套件 first

###  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
###  @@@   For HP servers only     @@@
###  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
### !!!!!   Make sure the updated servers are in maintainance mode   !!!!!
### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


firm_dir=/vmfs/volumes/ef225d93-ec0ff12b/HP/firmware
dri_dir=/vmfs/volumes/ef225d93-ec0ff12b/HP/driver

esxi_pass=`cat /Path/To/Your/Pass`
ipmi_pass=`cat /Path/To/Your/Pass2`

api='http://10.249.34.51/api/esxi_info.php'
token='d70083451**********b5a006a729a69'

old='/Path/To/Your/HP_Update_list2'
new='/Path/To/Your/Update_list_2'
ok_list='/Path/To/Your/update_ok_HP2'
move_script='/Path/To/Your/esxi-move-update-folder-HP_v2.ps1'
control=`cat /Path/To/Your/control2`
control_dir='/Path/To/Your/control2'


update_pack=/Path/To/Your/update_pack2
common_log=/Path/To/Your/Logs

###########################################################

cat $new |tee > $old
esxi=`cat $old |sed 's/\                              /\@/g' |grep -v "^$"`

### Log時間戳
time_stamp()
{
    echo "" 
    echo "" 
    echo "" 
    echo "===================" 
    /bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g'
    echo "==================="
    echo ""
}

### 卡控副程式
control_run()
{
	echo "running" > $control_dir
}

control_ok()
{
	echo "available" > $control_dir
}

### 觸發機制

if [ ! -n "$esxi" ];then
    time_stamp |tee >> $common_log 
    echo "******* No Host in Update *******" |tee >> $common_log
    exit 0
else
 	### 卡控機制
	if [ "$control" == "running" ];then
        time_stamp |tee >> $common_log
        echo "******* Update script is running *******" |tee >> $common_log
        exit 0

    elif [ "$control" == "available" ];then
		### 改變卡控狀態
        time_stamp |tee >> $common_log
		echo "******* 更新程式開始 *******" |tee >> $common_log
		control_run
		
		for x in $esxi
		do
			### 檢查host是否開機
			site=$(echo $x |awk -F \@ '{print $1}' |awk -F \/ '{print $2}')
			x=$(echo $x |awk -F \@ '{print $2}')
			ip=$(sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli network ip interface ipv4 get" |grep vmk0 |awk '{print $2}')
			timeout 4 bash -c "</dev/tcp/$ip/22" 2>/dev/null
			ssh_check=`echo $?`
			sleep 0.1
			wait
			echo "Site:$site , IP:$ip" 

			### volume check
			if [ "$ssh_check" -eq "1" ];then
				echo "******* $x Host down *******" |tee >> $common_log

			elif [ "$ssh_check" -eq "0" ];then
				### 取得IPMI_IP,維護模式,廠商資訊
				ipmi=`curl -s "$api?token=$token&host=$ip&type=IPMI"`
				mode=`curl -s "$api?token=$token&host=$ip&type=Mode"`
				vendor=`curl -s "$api?token=$token&host=$ip&type=Vendor"`
				SN=`curl -s "$api?token=$token&host=$ip&type=SN"`
				#RAID_fold=`ls /usr/local/ESXI-update/HP/firmware/RAID/_hp_scexe_info`
				local_dir=$(sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "ls /vmfs/volumes/" |grep local)

				### 產生各自的Log
				HP_log=/Path/To/Your/HP/$SN.log
				#touch $HP_log

				### 檢查SSID	    
				RAID_ssid=$(curl http://sys.chungyo.local/esxi_hardware/api/raid/esxi_raid_id_api.php?esxi_id=$x)
			    NET_ssid=$(curl http://sys.chungyo.local/esxi_hardware/api/network/esxi_nic_id_api.php?esxi_id=$x)
				wait

				### 導出資訊			
				/bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' |tee > $HP_log	
				echo "" |tee >> $HP_log
				echo "=======================" |tee >> $HP_log
				echo "Vendor : $vendor" |tee >> $HP_log
				echo "ESXI   : $x "	|tee >> $HP_log
				echo "IPMI   : $ipmi"	|tee >> $HP_log
				echo "SN     : $SN" |tee >> $HP_log
				echo "======================="	|tee >> $HP_log
				echo ""	|tee >> $HP_log
				echo "RAID SSID : $RAID_ssid" |tee >> $HP_log
				echo "NET  SSID : $NET_ssid" |tee >> $HP_log
				echo "-------------------------------" |tee >> $HP_log
				echo "" |tee >> $HP_log

				### 檢查更新套件 & disk check tool
				sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib list" |egrep "nmst|hpe-smx-provider|amshelper|hpe-ilo|hpe-cru|hpe-esxi-fc-enablement|ssacli|nmst|mft"|tee > $update_pack
				nmst=`cat $update_pack |grep "nmst"`
				smx=`cat $update_pack |grep "hpe-smx-provider"`
				amshelper=`cat $update_pack |grep "amshelper"`
				ilo=`cat $update_pack |grep "hpe-ilo"`
				cru=`cat $update_pack |grep "hpe-cru"`
				fc_enable=`cat $update_pack |grep "hpe-esxi-fc-enablement"`
				disk_tool=`cat $update_pack |grep "ssacli"`
				nmst=`cat $update_pack |grep "nmst"`
				mft=`cat $update_pack |grep "mft"`	

				### 檢查必要套件是否安裝完成
				if [ ! -n "$nmst" -o ! -n "$smx" -o ! -n "$amshelper" -o ! -n "$ilo" -o ! -n "$cru" -o ! -n "$fc_enable" -o ! -n "$disk_tool" -o ! -n "$nmst" -o ! -n "$mft" ];then
					pack_check="NEED"
					echo "===> 需要安裝套件" |tee >> $HP_log
					echo "-----------------"
					echo "" |tee >> $HP_log |tee >> $HP_log
				else
					pack_check="OK"
					echo "===> 套件已安裝" |tee >> $HP_log
					echo "-----------------" |tee >> $HP_log
					echo "" |tee >> $HP_log
				fi
	
				### Common_log導出
				echo "" |tee >> $common_log
				echo "===================" |tee >> $common_log
				/bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' |tee >> $common_log
				echo "===================" |tee >> $common_log
				echo "$x,$ipmi,$mode,$vendor,$SN" |tee >> $common_log

				 ### 有更新套件 ==> 開始更新Firmware & driver

				 ### G9更新
				if [ "$vendor" == "HP" -a "$mode" == "Enabled" ];then
					if [ "$pack_check" == "OK" ];then
						echo "******* Update BIOS *******" |tee >> $HP_log 
						
						### 刪除錯誤資料夾
						BIOS_folder="/usr/local/ESXI-update/HP/firmware/BIOS/G9/2.80/_hp_scexe_info"
						[[ `ls $BIOS_folder` ]] 2>/dev/null && rm -rf $BIOS_folder || echo "=== 無BIOS錯誤資料夾 ===" |tee >> $HP_log
						
						### BIOS 2.80
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/BIOS/G9/2.80 ; echo y |$firm_dir/BIOS/G9/2.80/CP046147.vmexe" |tee >> $HP_log
							sleep 0.2
							wait
							echo "----------------------------------" |tee >> $HP_log
							echo "" |tee >> $HP_log
						
						else
							if [ "$local_dir" ];then
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/BIOS/G9/2.80/CP046147-G9-BIOS-2.80.zip root@$x:/vmfs/volumes/$local_dir
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "touch /vmfs/volumes/$local_dir/BIOS ; mv /vmfs/volumes/$local_dir/CP046147-G9-BIOS-2.80.zip /vmfs/volumes/$local_dir/BIOS ; cd /vmfs/volumes/$local_dir/BIOS ; unzip CP046147-G9-BIOS-2.80.zip ; echo y | CP046147.vmexe" |tee >> $HP_log
								sleep 0.2
								wait
								echo "----------------------------------" |tee >> $HP_log
								echo "" |tee >> $HP_log
							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi
							
						### 檢查RAID卡SSID					
						echo "******* Update RAID *******" |tee >> $HP_log

						### 刪除錯誤資料夾
						RAID_folder="/usr/local/ESXI-update/HP/firmware/RAID/_hp_scexe_info"
						[[ `ls $RAID_folder` ]] 2>/dev/null && rm -rf $RAID_folder || echo "=== 無RAID錯誤資料夾 ===" |tee >> $HP_log			

						if [ "$RAID_ssid" == "103c:****:103c:21c0" ];then		
							if [ "$site" == "SZ" ];then	
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/RAID ; echo A | $firm_dir/RAID/CP038306.vmexe" |tee >> $HP_log
								sleep 0.2
								wait
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d $dri_dir/RAID_driver_2.0.38-offline_bundle.zip" |tee >> $HP_log
								echo "----------------------------------" |tee >> $HP_log
								echo "" |tee >> $HP_log
							else
								if [ "$local_dir" ];then
									### Firmware
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/RAID/CP038306_RAID_FW_6.88.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "touch /vmfs/volumes/$local_dir/RAID ; mv /vmfs/volumes/$local_dir/CP038306_RAID_FW_6.88.zip /vmfs/volumes/$local_dir/RAID ; cd /vmfs/volumes/$local_dir/RAID ; unzip CP038306_RAID_FW_6.88.zip ; echo y | CP038306.vmexe" |tee >> $HP_log
									sleep 0.2
									wait

									### Driver
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/RAID_driver_2.0.38-offline_bundle.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/$local_dir/RAID_driver_2.0.38-offline_bundle.zip" |tee >> $HP_log
									echo "----------------------------------" |tee >> $HP_log
									echo "" |tee >> $HP_log
								else
									echo "$x 無local_disk" |tee >> $HP_log
								fi
							fi
						else
							echo "******* 需增加 $RAID_ssid 更新包 *******" |tee >> $HP_log
							echo "----------------------------------" |tee >> $HP_log
		                    echo "" |tee >> $HP_log
						fi					
	
						echo "******* Update NET *******" |tee >> $HP_log

						### 檢查網卡SSID					
						if [ "$NET_ssid" == "15b3:****:103c:8020" ];then 
							if [ "$site" == "SZ" ];then
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/net/2.42.5000 ; $firm_dir/net/2.42.5000/CP034530.vmexe" |tee >> $HP_log
								sleep 0.2
								wait
				            	echo "" |tee >> $HP_log
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d $dri_dir/MLNX-Net_driver-3.16.11.10.zip" |tee >> $HP_log
								echo "----------------------------------" |tee >> $HP_log
								echo "" |tee >> $HP_log
							else
								if [ "$local_dir" ];then
									### Firmware
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/net/2.42.5000/CP034530_NET_FW_2.42.5000.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "touch /vmfs/volumes/$local_dir/NET ; mv /vmfs/volumes/$local_dir/CP034530_NET_FW_2.42.5000.zip /vmfs/volumes/$local_dir/NET ; cd /vmfs/volumes/$local_dir/NET ; unzip CP034530_NET_FW_2.42.5000.zip ; echo y | CP034530.vmexe" |tee >> $HP_log
									sleep 0.2
									wait
									echo "" |tee >> $HP_log

									### Driver
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/MLNX-Net_driver-3.16.11.10.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/$local_dir/MLNX-Net_driver-3.16.11.10.zip" |tee >> $HP_log
									echo "----------------------------------" |tee >> $HP_log
									echo "" |tee >> $HP_log
								else
									echo "$x 無local_disk" |tee >> $HP_log
								fi
							fi
	
	                    elif [ "$NET_ssid" == "15b3:**** 1590:00d3" ];then
							if [ "$site" == "SZ" ];then
	                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/net/14.27.4000 ; $firm_dir/net/14.27.4000/CP044339.vmexe" |tee >> $HP_log
	                        	sleep 0.2
	                        	wait
	                        	echo "" |tee >> $HP_log
	                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d $dri_dir/MLNX-NATIVE-ConnectX-4.16.70.1-offline_bundle.zip"
	                        	echo "----------------------------------" |tee >> $HP_log
	                        	echo "" |tee >> $HP_log
							else
								if [ "$local_dir" ];then
									### Firmware
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/net/14.27.4000/Net_fir-14.27.4000-CP044339.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd /vmfs/volumes/$local_dir ; mkdir /vmfs/volumes/$local_dir/NET ; mv /vmfs/volumes/$local_dir/Net_fir-14.27.4000-CP044339.zip /vmfs/volumes/$local_dir/Net ; cd /vmfs/volumes/$local_dir/Net ; unzip /vmfs/volumes/$local_dir/Net/Net_fir-14.27.4000-CP044339.zip ; /vmfs/volumes/$local_dir/Net/CP044339.vmexe" |tee >> $HP_log
	                        		sleep 0.2
	                        		wait
	                        		echo "" |tee >> $HP_log

									### Driver
	                        		sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/MLNX-NATIVE-ConnectX-4.16.70.1-offline_bundle.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/$local_dir/MLNX-NATIVE-ConnectX-4.16.70.1-offline_bundle.zip"
	                        		echo "----------------------------------" |tee >> $HP_log
	                        		echo "" |tee >> $HP_log
								else
									echo "$x 無local_disk" |tee >> $HP_log
								fi
							fi

						else
							echo "******* 需增加 $NET_ssid 更新包 *******" |tee >> $HP_log
							echo "----------------------------------" |tee >> $HP_log
	                       	echo "" |tee >> $HP_log
						fi
	
						echo "******* Update IPMI *******" |tee >> $HP_log
						### 刪除異常資料夾
						IPMI_folder="/usr/local/ESXI-update/HP/firmware/iLO/iLO4/_hp_scexe_info"
						[[ `ls $IPMI_folder` ]] 2>/dev/null && rm -rf $IPMI_folder || echo "=== 無IPMI錯誤資料夾 ===" |tee >> $HP_log

						### iLO4 2.77
						if [ "$site" == "SZ" ];then
			            	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/iLO/iLO4-2.78/ ; echo y | $firm_dir/iLO/iLO4-2.78/CP046464.vmexe" |tee >> $HP_log
							sleep 0.2
	                    	wait
							echo "----------------------------------" |tee >> $HP_log
			            	echo "" |tee >> $HP_log
						else
							if [ "$local_dir" ];then
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/iLO/iLO4-2.78/CP046464-ilo4-2.78.zip root@$x:/vmfs/volumes/$local_dir |tee >> $HP_log
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "mkdir /vmfs/volumes/$local_dir/iLO ; mv /vmfs/volumes/$local_dir/CP046464-ilo4-2.78.zip /vmfs/volumes/$local_dir/iLO ; cd /vmfs/volumes/$local_dir/iLO ; unzip /vmfs/volumes/$local_dir/iLO/CP046464-ilo4-2.78.zip ; echo y | /vmfs/volumes/$local_dir/iLO/CP046464.vmexe" |tee >> $HP_log
								sleep 0.2
	                    		wait
								echo "----------------------------------" |tee >> $HP_log
			            		echo "" |tee >> $HP_log
							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi
							
						echo "******* $x Reboot *******" |tee >> $HP_log
						sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot" |tee >> $HP_log
			            echo "" |tee >> $HP_log
						
						echo "******* $x 搬移 *******" |tee >> $HP_log
						echo "$x" > $ok_list
						sleep 0.2
						wait
			            pwsh $move_script |tee >> $HP_log 
			            echo "" |tee >> $HP_log
				
					 ### 無更新套件 ===> 安裝更新套件
					elif [ "$pack_check" == "NEED" ];then
						echo "******* 安裝更新套件 *******" |tee >> $HP_log
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v  $dri_dir/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $HP_log
							wait
							echo "----------------------------------" |tee >> $HP_log
							echo "" |tee >> $HP_log
						else
							if [ "$local_dir" ];then
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib root@$x:/vmfs/volumes/$local_dir
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -d /vmfs/volumes/$local_dir/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $HP_log
								wait
								echo "----------------------------------" |tee >> $HP_log
			            		echo "" |tee >> $HP_log
							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi

						### HP-bundle
						echo "******* 安裝HP套件 *******" |tee >> $HP_log
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -d $dri_dir/hpe-esxi6.5uX-bundle-2.6.2-2.zip" |tee >> $HP_log
							wait
							echo "----------------------------------" |tee >> $HP_log
							echo "" |tee >> $HP_log
						else
							if [ "$local_dir" ];then
                        		sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/hpe-esxi6.5uX-bundle-2.6.2-2.zip root@$x:/vmfs/volumes/$local_dir
                        		sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -d /vmfs/volumes/$local_dir/hpe-esxi6.5uX-bundle-2.6.2-2.zip" |tee >> $HP_log
                        		wait
                        		echo "----------------------------------" |tee >> $HP_log
                        		echo "" |tee >> $HP_log
							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi
						
						echo "******* 安裝Disk套件 *******" |tee >> $HP_log
						if [ "$site" == "SZ" ];then
	                    	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v  $dri_dir/esxi_ssacli.vib" |tee >> $HP_log
	                    	wait
	                    	echo "----------------------------------" |tee >> $HP_log
	                    	echo "" |tee >> $HP_log
						else
							if [ "$local_dir" ];then
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/esxi_ssacli.vib root@$x:/vmfs/volumes/$local_dir
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v  /vmfs/volumes/$local_dir/esxi_ssacli.vib"
							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi

						echo "******* 安裝Mellanox驅動 *******" |tee >> $HP_log
						if [ "$site" == "SZ" ];then
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $HP_log
							wait
							echo "----------------------------------" |tee >> $HP_log
                        	echo "" |tee >> $HP_log
						else
							if [ "$local_dir" ];then
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib root@$x:/vmfs/volumes/$local_dir
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/$local_dir/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib"
							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi

						echo "******* $x 安裝套件reboot *******" |tee >> $HP_log
		                sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot" |tee >> $HP_log
		
					else
						echo "******* 安裝套件ERROR *******"
					fi
	
				 ### G10更新
				elif [ "$vendor" == "HPE" -a "$mode" == "Enabled" ];then
	                if [ "$pack_check" == "OK" ];then
	                    echo "******* Update BIOS *******" |tee >> $HP_log
	                    /sbin/ilorest flashfwpkg /usr/local/ESXI-update/HP/firmware/BIOS/G10/U32_2.40_10_26_2020.fwpkg --logdir=/usr/local/ESXI-update/Logs/HP --url="$ipmi" -u administrator -p $ipmi_pass |grep -v Updating |tee >> $HP_log
						sleep 0.2
	                    wait
	                    echo "----------------------------------" |tee >> $HP_log
	                    echo "" |tee >> $HP_log
	
	                    echo "******* Update RAID *******" |tee >> $HP_log
						echo "G10 沒有RAID卡" |tee >> $HP_log
						echo "" |tee >> $HP_log	
                        echo "----------------------------------" |tee >> $HP_log
	                    echo "" |tee >> $HP_log
	
	                    echo "******* Update NET *******" |tee >> $HP_log
						### 檢查網卡SSID
	                    if [ "$NET_ssid" == "15b3:****:103c:8020" ];then
							if [ "$site" == "SZ" ];then
	                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/net/2.42.5000 ; $firm_dir/net/2.42.5000/CP034530.vmexe" |tee >> $HP_log
	                        	sleep 0.2
	                        	wait
	                        	echo "" |tee >> $HP_log
	                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d $dri_dir/MLNX-Net_driver-3.16.11.10.zip" |tee >> $HP_log
	                        	echo "----------------------------------" |tee >> $HP_log
	                        	echo "" |tee >> $HP_log
							else
								if [ "$local_dir" ];then
									### Firmware
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x /usr/local/ESXI-update/HP/firmware/net/2.42.5000/CP034530_NET_FW_2.42.5000.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "mkdir /vmfs/volumes$local_dir/NET ; mv /vmfs/volumes$local_dir/CP034530_NET_FW_2.42.5000.zip /vmfs/volumes$local_dir/NET ; cd /vmfs/volumes$local_dir/NET ; unzip /vmfs/volumes$local_dir/NET/CP034530_NET_FW_2.42.5000.zip ; /vmfs/volumes$local_dir/NET/CP034530.vmexe" |tee >> $HP_log
	                        		sleep 0.2
	                        		wait
	                        		echo "" |tee >> $HP_log

									### Driver
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/MLNX-Net_driver-3.16.11.10.zip root@$x:/vmfs/volumes/$local_dir
	                        		sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/$local_dir/MLNX-Net_driver-3.16.11.10.zip" |tee >> $HP_log
	                        		echo "----------------------------------" |tee >> $HP_log
	                        		echo "" |tee >> $HP_log
								else
									echo "$x 無local_disk" |tee >> $HP_log
								fi
							fi
	
						elif [ "$NET_ssid" == "15b3:****:1590:00d3" ];then
							if [ "$site" == "SZ" ];then
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/net/14.27.4000 ; $firm_dir/net/14.27.4000/CP044339.vmexe" |tee >> $HP_log
								sleep 0.2
	                        	wait
	                        	echo "" |tee >> $HP_log
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d $dri_dir/MLNX-NATIVE-ConnectX-4.16.70.1-offline_bundle.zip" |tee >> $HP_log
								echo "----------------------------------" |tee >> $HP_log
	                        	echo "" |tee >> $HP_log						
							else
								if [ "$local_dir" ];then
									### Firmware
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/net/14.27.4000/Net_fir-14.27.4000-CP044339.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "mkdir /vmfs/volumes/$local_dir/NET ; mv /vmfs/volumes/$local_dir/Net_fir-14.27.4000-CP044339.zip /vmfs/volumes/$local_dir/NET ; cd /vmfs/volumes/$local_dir/NET ; unzip /vmfs/volumes/$local_dir/NET/Net_fir-14.27.4000-CP044339.zip ; /vmfs/volumes/$local_dir/NETCP044339.vmexe" |tee >> $HP_log
									sleep 0.2
	                        		wait
	                        		echo "" |tee >> $HP_log

									### Driver
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/MLNX-NATIVE-ConnectX-4.16.70.1-offline_bundle.zip /vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/$local_dir/MLNX-NATIVE-ConnectX-4.16.70.1-offline_bundle.zip" |tee >> $HP_log
									echo "----------------------------------" |tee >> $HP_log
	                        		echo "" |tee >> $HP_log	
								else
									echo "$x 無local_disk" |tee >> $HP_log
								fi
							fi
						
						elif [ "$NET_ssid" == "15b3:****:1590:02c1" ];then
							if [ "$site" == "SZ" ];then
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "cd $firm_dir/net/14.27.1016 ; $firm_dir/net/14.27.1016/CP040053.vmexe" |tee >> $HP_log
								sleep 0.2
	                        	wait
	                        	echo "" |tee >> $HP_log
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d $dri_dir/MLNX-NATIVE-4.16.14.2-6.5-offline_bundle.zip" |tee >> $HP_log
								echo "----------------------------------" |tee >> $HP_log
	                        	echo "" |tee >> $HP_log
							else
								if [ "$local_dir" ];then
									### Firmware
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/firmware/net/14.27.1016/CP040053-14.26.1040.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "mkdir /vmfs/volumes/$local_dir/NET ; mv /vmfs/volumes/$local_dir/CP040053-14.26.1040.zip /vmfs/volumes/$local_dir/NET ; cd /vmfs/volumes/$local_dir/NET ; unzip /vmfs/volumes/$local_dir/NET/CP040053-14.26.1040.zip ; /vmfs/volumes/$local_dir/NET/CP040053.vmexe" |tee >> $HP_log
									sleep 0.2
	                        		wait
	                        		echo "" |tee >> $HP_log

									### Driver
									sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/MLNX-NATIVE-4.16.14.2-6.5-offline_bundle.zip root@$x:/vmfs/volumes/$local_dir
									sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib update -d /vmfs/volumes/$local_dir/MLNX-NATIVE-4.16.14.2-6.5-offline_bundle.zip" |tee >> $HP_log
									echo "----------------------------------" |tee >> $HP_log
	                        		echo "" |tee >> $HP_log
								else
									echo "$x 無local_disk" |tee >> $HP_log
								fi
							fi
					
	                    else
	                        echo "******* 需增加 $NET_ssid 更新包 *******" |tee >> $HP_log
							echo "" |tee >> $HP_log
	                        echo "----------------------------------" |tee >> $HP_log
	                        echo "" |tee >> $HP_log
	                    fi
	
		                echo "******* Update IPMI *******" |tee >> $HP_log
						### G10 iLO5-2.33
	                    /sbin/ilorest flashfwpkg /usr/local/ESXI-update/HP/firmware/iLO/iLO5/ilo5_233.fwpkg --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log/ --url="$ipmi_tmp" -u administrator -p $ipmi_pass |grep -v Updating |tee >> $HP_log
	                    sleep 0.2
	                    wait
	                    echo "----------------------------------" |tee >> $HP_log
	                    echo "" |tee >> $HP_log
	
	                    echo "******* $x Reboot *******" |tee >> $HP_log
						
	                    sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot" |tee >> $HP_log
	                    echo "" |tee >> $HP_log
	
	                    echo "******* $x 搬移 *******" |tee >> $HP_log
	                    echo "$x" > $ok_list
						sleep 0.2
						wait
	                    pwsh $move_script |tee >> $HP_log
	                    echo "" |tee >> $HP_log

				 	 ### 無更新套件 ===> 安裝更新套件
   	             	elif [ "$pack_check" == "NEED" ];then
	                	echo "******* 安裝更新套件 *******" |tee >> $HP_log
						echo "" |tee >> $HP_log
						if [ "$site" == "SZ" ];then
							### nmst
	                    	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v  $dri_dir/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $HP_log
	                    	wait
	                    	echo "----------------------------------" |tee >> $HP_log
	                    	echo "" |tee >> $HP_log
							
							### HP-bundle
							sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -d $dri_dir/hpe-esxi6.5uX-bundle-2.6.2-2.zip" |tee >> $HP_log
	                    	wait
	                    	echo "----------------------------------" |tee >> $HP_log
	                    	echo "" |tee >> $HP_log
							
							### Disk tool
	                    	echo "******* 安裝Disk套件 *******" |tee >> $HP_log
	                    	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v  $dri_dir/esxi_ssacli.vib" |tee >> $HP_log
	                    	wait
	                    	echo "----------------------------------" |tee >> $HP_log
	                    	echo "" |tee >> $HP_log
							
							### Mellanox tool
                        	echo "******* 安裝Mellanox驅動 *******" |tee >> $HP_log
                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $HP_log
                        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $HP_log
                        	wait
                        	echo "----------------------------------" |tee >> $HP_log
                        	echo "" |tee >> $HP_log

						else
							if [ "$local_dir" ];then
								### nmst
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib root@$x:/vmfs/volumes/$local_dir
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/$local_dir/nmst-4.12.0.105-1OEM.650.0.0.4598673.x86_64.vib" |tee >> $HP_log
								wait
	                    		echo "----------------------------------" |tee >> $HP_log
	                    		echo "" |tee >> $HP_log

								### HP-bundle
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/hpe-esxi6.5uX-bundle-2.6.2-2.zip root@$x:/vmfs/volumes/$local_dir
								sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -d /vmfs/volumes/$local_dir/hpe-esxi6.5uX-bundle-2.6.2-2.zip" |tee >> $HP_log
	                    		wait
	                    		echo "----------------------------------" |tee >> $HP_log
	                    		echo "" |tee >> $HP_log

								### Disk tool
	                    		echo "******* 安裝Disk套件 *******" |tee >> $HP_log
								sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/HP/driver/esxi_ssacli.vib root@$x:/vmfs/volumes/$local_dir 
	                    		sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v  /vmfs/volumes/$local_dir/esxi_ssacli.vib" |tee >> $HP_log
	                    		wait
	                    		echo "----------------------------------" |tee >> $HP_log
	                    		echo "" |tee >> $HP_log

								### Mellanox tool
                        		echo "******* 安裝Mellanox驅動 *******" |tee >> $HP_log
                        		sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /usr/local/ESXI-update/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib root@$x:/vmfs/volumes/$local_dir
                        		sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/$local_dir/mft-4.16.1.9-10EM-650.0.0.4598673.x86_64.vib" |tee >> $HP_log
                        		wait
                        		echo "----------------------------------" |tee >> $HP_log
                        		echo "" |tee >> $HP_log

							else
								echo "$x 無local_disk" |tee >> $HP_log
							fi
						fi
		
	                    echo "******* $x 安裝套件reboot *******" |tee >> $HP_log
	                    sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot" |tee >> $HP_log
						echo "" |tee >> $HP_log
	
	                else
	                    echo "******* 安裝套件ERROR *******"
	                fi

				 ## 不支援廠商或沒進入maintainance_mode
		        else
		            echo "* * * * * $x ======> Check Maintainance_mode or Server_Vendor * * * * *" |tee >> $HP_log
		        fi
				echo "=================================================================================" |tee >> $HP_log
				echo "" |tee >> $HP_log
			
			else
				echo "******* SSH_check ERROR *******" |tee >> $HP_log
				echo "" |tee >> $HP_log
			fi
		done
		control_ok	
    else
        time_stamp |tee >> $HP_log
        echo "******* 卡控 Error *******" |tee >> $HP_log
        control_ok
        exit 0
    fi
fi

time_stamp |tee >> $common_log
echo "******* 更新程式結束 *******" |tee >> $common_log

