#!/bin/bash
### Create by    : SYS-Juro
### Update date  : 2022/05/31
### Description  : 檢查BIOS設定並調整
  
esxi_pass=`cat /usr/local/ESXI-update/HCL/nimajuro`
ipmi_pass=`cat /usr/local/ESXI-update/HCL/nibalei`

list=`cat /usr/local/ESXI-update/HCL/host_lists/Setting_list_2`
ipmi='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/ipmi_2'
mode='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/mode_2'
vendor='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/vendor_2'

BIOS='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/BIOS-settings_2'
hotspare='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/hotspare_2'
HT='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/hyperthreading_2'
State='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/state_2'
Model='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/model_2'

control=`cat '/usr/local/ESXI-update/HCL/shell_scripts/BIOS/control_2'`
control_dir='/usr/local/ESXI-update/HCL/shell_scripts/BIOS/control_2'

oneCLI='/usr/local/ESXI-update/HCL/update/OneCLI-3.4.0/OneCli'
move_script='/usr/local/ESXI-update/HCL/power_shell/esxi-move-set-folder_v2.ps1'
ok_list='/usr/local/ESXI-update/HCL/host_lists/Setting_OK_list_2'
BIOS_log='/usr/local/ESXI-update/Logs/work/set_bios.log_2'

######################################################################################
### log時間戳
time_stamp()
{
    echo "" |tee >> $BIOS_log
    echo "" |tee >> $BIOS_log
    echo "" |tee >> $BIOS_log
    echo "@@@@@@@@@@@@@@@@@@@" |tee >> $BIOS_log
    /bin/date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' |tee >> $BIOS_log
    echo "@@@@@@@@@@@@@@@@@@@" |tee >> $BIOS_log
	echo ""
}

control_ok()
{
	echo "available" > $control_dir
}

control_no()
{
	echo "no" > $control_dir
}

######################################################################################

### 程式卡控	

if [ $control == "no" ];then
	time_stamp
	echo "=== 程式正在執行,請稍等 ===" |tee >> $BIOS_log
	echo ""

elif [ $control == "available" ];then
	control_no

	############################## 程式開始 ##############################3

	### 取得IPMI,廠商,Conn-limit
	for x in $list
	do
	### 檢查host是否開機
        timeout 4 bash -c "</dev/tcp/$x/22" 2>/dev/null
        ssh_check=`echo $?`
        sleep 0.1
        wait
        if [ $ssh_check -eq "1" ];then
			time_stamp
            echo "******* $x Host down *******" |tee >> $BIOS_log
            break
        elif [ $ssh_check -eq "0" ];then
			time_stamp
			echo "" |tee >> $BIOS_log	
		    sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/nul /usr/local/ESXI-update/ipmitool root@$x:/tmp
		    wait
			limit=`sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcfg-advcfg -g /SunRPC/MaxConnPerIP" |awk '{print $5}'`
			netapp=`sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib list" |grep "NetAppNasPlugin" |awk '{print $1}'`

		 ### 撈取BIOS設定
#			ipmi_tmp=`curl "http://10.249.34.51/api/esxi_info.php?token=d7008*****62cf20fefb5a006a729a69&host=${x}&type=IPMI"`
			ipmi_tmp=`sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "/tmp/ipmitool lan print" |grep "IP Address" |grep -v "Source" |awk -F \: '{print $2}' |sed 's/[[:space:]]//g'`
			mode_tmp=`curl "http://10.249.34.51/api/esxi_info.php?token=d7008*****62cf20fefb5a006a729a69&host=${x}&type=Mode"`
		    vendor_tmp=`curl "http://10.249.34.51/api/esxi_info.php?token=d7008*****62cf20fefb5a006a729a69&host=${x}&type=Vendor"`
	
			echo "===========================" |tee >> $BIOS_log
		    echo "Host_ip : $x" |tee >> $BIOS_log
		    echo "IPMI_ip : $ipmi_tmp" |tee >> $BIOS_log
		    echo "Vendor  : $vendor_tmp " |tee >> $BIOS_log
		    echo "===========================" |tee >> $BIOS_log	

		 ######################################################################################

		 ############
		 ### Dell ###
		 ############

			if [ $mode_tmp == "Enabled" -a $vendor_tmp == "Dell" ] 2>/dev/null	;then
				echo "=== 檢查電源設定 ===" |sed '/^$/d' |tee >> $BIOS_log
				/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass get System.Power.Hotspare.Enable --nocertwarn |grep "abled" |sed 's/\r//' |sed s/[[:space:]]//g |tee > $hotspare
				sleep 10s
				wait
				cat $hotspare |tee >> $BIOS_log
				echo "" |tee >> $BIOS_log

				echo "=== 檢查邏輯處理器 ===" |sed '/^$/d' |tee >> $BIOS_log
				/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass get BIOS.ProcSettings.LogicalProc --nocertwarn |sed 's/\r//' |sed '/^$/d' |grep "LogicalProc=" |sed '/^$/d' |sed '/^M/d' |tee > $HT
				cat $HT |tee >> $BIOS_log
				echo "" |tee >> $BIOS_log

				echo "===  檢查BIOS設定 ===" |sed '/^$/d' |tee >> $BIOS_log
				/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass get BIOS.SysProfileSettings --nocertwarn |sed 's/\r//' |sed '/^$/d' |egrep "SysProfile|ProcPwrPerf|MemFrequency|ProcTurboMode|ProcC1E|ProcCStates" |grep -v "Key=" |sed '/^$/d' |sed s/[[:space:]]//g |tee > $BIOS
				cat $BIOS |tee >> $BIOS_log
				echo "" |tee >> $BIOS_log
			
		
			 ### 檢查BIOS設定
				hot_check=`cat $hotspare |sed 's/\#//g'`
				sysprofile_check=`cat $BIOS |grep SysProfile |awk -F \= '{print $2}' |sed 's/\#//g'`
				HT_check=`cat $HT |awk -F \= '{print $2}' |sed 's/\#//g'`
				CPUpwr_check=`cat $BIOS |grep ProcPwrPerf |awk -F \= '{print $2}' |sed 's/\#//g'`
				MEMfre_check=`cat $BIOS |grep MemFrequency |awk -F \= '{print $2}' |sed 's/\#//g'`
				Turbo_check=`cat $BIOS |grep ProcTurboMode |awk -F \= '{print $2}' |sed 's/\#//g'`
				C1E_check=`cat $BIOS |grep ProcC1E |awk -F \= '{print $2}' |sed 's/\#//g'`
				CState_check=`cat $BIOS |grep ProcCStates |awk -F \= '{print $2}' |sed 's/\#//g'`
				key=$dir/job_key
	
				echo "===  檢查結果 ===" |tee >> $BIOS_log
				if [ "$hot_check" == "Disabled" ];then
					echo "熱備援     OK" |tee >> $BIOS_log
				else
					echo "熱備援     NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set System.Power.Hotspare.Enable "0" --nocertwarn |tee >> $BIOS_log
					### 熱備援不需要建立任務
				fi
	
				if [ "$sysprofile_check" == "Custom" ];then
					echo "運作模式   OK" |tee >> $BIOS_log
				else
					echo "運作模式   NO" |tee >> $BIOS_log
					/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.SysProfileSettings.SysProfile "Custom" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
					mode_change="Change"
				fi

				if [ "$HT_check" == "Enabled" ];then
					echo "HT         OK" |tee >> $BIOS_log
				else
					echo "HT         NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.ProcSettings.LogicalProc "Enabled" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
					HT_change="Change"
				fi
		
				if [ "$CPUpwr_check" == "MaxPerf" ];then
					echo "CPU效能    OK" |tee >> $BIOS_log
				else	
					echo "CPU效能    NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.SysProfileSettings.ProcPwrPerf "MaxPerf" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
					CPU_change="Change"
				fi
		
				if [ "$MEMfre_check" == "MaxPerf" ];then
					echo "記憶體效能 OK" |tee >> $BIOS_log
				else
					echo "記憶體效能 NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.SysProfileSettings.MemFrequency "MaxPerf" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
					MEM_change="Change"
				fi
		
				if [ "$Turbo_check" == "Enabled" ];then
					echo "加速模式   OK" |tee >> $BIOS_log
				else
					echo "加速模式   NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.SysProfileSettings.ProcTurboMode "Enabled" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
					turbo_change="Change"
				fi

		    	if [ "$CState_check" == "Disabled" ];then
		        	echo "CState     OK" |tee >> $BIOS_log
		    	else
		        	echo "CState     NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.SysProfileSettings.ProcCStates "Disabled" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
		        	CState="Change"
		    	fi
		
				if [ "$C1E_check" == "Disabled" ];then 
					echo "C1E        OK" |tee >> $BIOS_log
				else
					echo "C1E        NO" |tee >> $BIOS_log
		        	/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass set BIOS.SysProfileSettings.ProcC1E "Disabled" --nocertwarn |grep "Key=" |awk -F \# '{print $1}' |awk -F \= '{print $2}' |tee > $key
					CI_change="Change"
				fi

				echo "===========================================" |tee >> $BIOS_log	

			 ### 調整BIOS設定
				echo "=== 設定調整 ===" |tee >> $BIOS_log
				if [ "$mode_change" == "Change" -o "$HT_change" == "Change" -o "$CPU_change" == "Change" -o "$MEM_change" == "Change" -o "$turbo_change" == "Change" -o "$CI_change" == "Change" -o "$" == "Change" -o "$CState" == "Change" ];then
					BIOS_reboot="YES"
					echo "***** BIOS 需調整 *****" |tee >> $BIOS_log
					/opt/dell/srvadmin/sbin/racadm -r $ipmi_tmp -u root -p $ipmi_pass jobqueue create "BIOS.Setup.1-1" --nocertwarn |sed 's/\r//' |sed s/[[:space:]]//g |tee >> $BIOS_log
					echo "===========================================" |tee >> $BIOS_log
				else
					BIOS_reboot="NO"
				fi

			 ### 檢查MaxConPerIP
				if [ "$limit" == "32" ];then
					Con_reboot="NO"
				else
					Con_reboot="YES"
					echo "NFS Connection Limit需調整" |tee >> $BIOS_log
					sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcfg-advcfg -s 32 /SunRPC/MaxConnPerIP" |tee >> $BIOS_log
				fi

			 ### 檢查NetApp plugin
				if [ "$netapp" == "NetAppNasPlugin" ];then
					NetApp_reboot="NO"
				else
					NetApp_reboot="YES"
					echo "NetApp plugin需安裝" |tee >> $BIOS_log
					sshpass -p "$esxi_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/nul /juro_lin/update/NetAppNasPlugin.v22.vib root@$x:/tmp
					sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /tmp/NetAppNasPlugin.v22.vib" |tee >> $BIOS_log
				fi

	
			 ### 檢查是否需要關機			
				if [ $BIOS_reboot == "YES" -o $Con_reboot == "YES" -o $NetApp_reboot == "YES" ];then
					echo "" |tee >> $BIOS_log
					echo "$x Reboot" |tee >> $BIOS_log
		        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot" |tee >> $BIOS_log
					echo "===========================================" |tee >> $BIOS_log
		
				elif [ $BIOS_reboot == "NO" -a $Con_reboot == "NO" -a $NetApp_reboot == "NO" ];then
					###  搬移機器
					echo "$x 無需調整Ya" |tee >> $BIOS_log
		        	echo "$x" > $ok_list
		        	pwsh $move_script |tee >> $BIOS_log
		
				else
					echo "=== Dell part ERROR ===" |tee >> $BIOS_log
				fi

		 ############################################################################################################################################################################

		 ##############
		 ### Lenovo ###
		 ##############

	    	elif [ $mode_tmp == "Enabled" -a $vendor_tmp == "Lenovo" ] 2>/dev/null  ;then
				$oneCLI config show -b USERID:$ipmi_pass@$ipmi_tmp -N --nolog |egrep "OperatingModes.ChooseOperatingMode|Memory.MemorySpeed|Processors.C1EnhancedMode|Processors.TurboMode|EnergyEfficientTurbo|Processors.CStates|Processors.HyperThreading|IMM.PowerRestorePolicy" |tee > $BIOS
	
				cat $BIOS |grep "IMM.PowerRestorePolicy" |tee > $hotspare
				cat $BIOS |grep "Processors.HyperThreading" |tee > $HT
	
	        	echo "=== 檢查電源設定 ===" |sed '/^$/d' |tee >> $BIOS_log
	        	cat $hotspare |tee >> $BIOS_log
	        	echo "" |tee >> $BIOS_log
	
	        	echo "=== 檢查邏輯處理器 ===" |sed '/^$/d' |tee >> $BIOS_log
	        	cat $HT |tee >> $BIOS_log
	        	echo "" |tee >> $BIOS_log
	
	        	echo "===  檢查BIOS設定 ===" |sed '/^$/d' |tee >> $BIOS_log
	        	cat $BIOS |egrep "OperatingModes.ChooseOperatingMode|Memory.MemorySpeed|Processors.TurboMode|Processors.CStates|Processors.C1EnhancedMode|EnergyEfficientTurbo" |tee >> $BIOS_log
	        	echo "" |tee >> $BIOS_log
	
	
			 ### 檢查BIOS設定
		    	hot_check=`cat $hotspare |awk -F \= '{print $2}' |sed 's/\#//g'`
		    	sysprofile_check=`cat $BIOS |grep "OperatingModes.ChooseOperatingMode" |awk -F \= '{print $2}'`
		    	HT_check=`cat $HT |awk -F \= '{print $2}' |sed 's/\#//g'`
		    	CPUpwr_check=`cat $BIOS |grep "Processors.EnergyEfficientTurbo" |awk -F \= '{print $2}'`
		    	MEMfre_check=`cat $BIOS |grep "Memory.MemorySpeed" |awk -F \= '{print $2}'`
		    	Turbo_check=`cat $BIOS |grep "Processors.TurboMode" |awk -F \= '{print $2}'`
		    	C1E_check=`cat $BIOS |grep "Processors.C1EnhancedMode" |awk -F \= '{print $2}'`
		    	CState_check=`cat $BIOS |grep "Processors.CStates" |awk -F \= '{print $2}'`

		    	echo "===  檢查結果 ===" |tee >> $BIOS_log
		    	if [ "$hot_check" == "Restore" ];then
		        	echo "電源設定   OK" |tee >> $BIOS_log
		    	else
		        	echo "電源設定   NO" |tee >> $BIOS_log
					$oneCLI config set IMM.PowerRestorePolicy "Restore" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi

				if [ "$sysprofile_check" == "Maximum Performance" ];then
			        echo "運作模式   OK" |tee >> $BIOS_log
		    	else
		        	echo "運作模式   NO" |tee >> $BIOS_log
		        	Mode_change="Change"
					#$oneCLI config set OperatingModes.ChooseOperatingMode "Custom Mode" -b USERID:$ipmi_pass@$ipmi_tmp
					$oneCLI config set OperatingModes.ChooseOperatingMode "Maximum Performance" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi
		
		    	if [ "$HT_check" == "Enable" ];then
			    	echo "HT         OK" |tee >> $BIOS_log
		    	else
		        	echo "HT         NO" |tee >> $BIOS_log
		        	HT_change="Change"
					$oneCLI config set Processors.HyperThreading "Enable" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi
		
		    	if [ "$CPUpwr_check" == "Disable" ];then
		        	echo "CPU節能    OK" |tee >> $BIOS_log
		    	else
		        	echo "CPU節能    NO" |tee >> $BIOS_log
					CPU_change="Change"
		        	$oneCLI config set Processors.EnergyEfficientTurbo "Disable" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi

		    	if [ "$MEMfre_check" == "Max Performance" ];then
		        	echo "記憶體效能 OK" |tee >> $BIOS_log
		    	else
		        	echo "記憶體效能 NO" |tee >> $BIOS_log
		        	MEM_change="Change"
		    		$oneCLI config set Memory.MemorySpeed "Max Performance" -b USERID:$ipmi_pass@$ipmi_tmp
				fi

		    	if [ "$Turbo_check" == "Enable" ];then
		        	echo "加速模式   OK" |tee >> $BIOS_log
		    	else
		        	echo "加速模式   NO" |tee >> $BIOS_log
		        	Turbo_change="Change"
					$oneCLI config set Processors.TurboMode "Enable" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi

		    	if [ "$CState_check" == "Disable" ];then
		        	echo "CState     OK" |tee >> $BIOS_log
		    	else
		        	echo "CState     NO" |tee >> $BIOS_log
		        	CState="Change"
		        	$oneCLI config set Processors.CStates "Disable" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi

		    	if [ "$C1E_check" == "Disable" ];then
		        	echo "C1E        OK" |tee >> $BIOS_log
		    	else
		        	echo "C1E        NO" |tee >> $BIOS_log
		        	C1_change="Change"
					$oneCLI config set Processors.C1EnhancedMode "Disable" -b USERID:$ipmi_pass@$ipmi_tmp
		    	fi


		    	echo "===========================================" |tee >> $BIOS_log

			 ### 調整BIOS設定
		    	if [ "$Mode_change" == "Change" -o "$HT_change" == "Change" -o "$CPU_change" == "Change" -o "$MEM_change" == "Change" -o "$Turbo_change" == "Change" -o "$C1_change" == "Change" -o "$CState" == "Change" ];then
					echo "***** BIOS 需調整 *****" |tee >> $BIOS_log
					BIOS_reboot="YES"
				else
					BIOS_reboot="NO"
				fi
		
				if [ $limit == "32" ];then
					Con_reboot="NO"
				else
					Con_reboot="YES"
					echo "NFS Connection Limit需調整" |tee >> $BIOS_log
					sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcfg-advcfg -s 32 /SunRPC/MaxConnPerIP" |tee >> $BIOS_log
				fi

			 ### 檢查NetApp plugin
            	if [ "$netapp" == "NetAppNasPlugin" ];then
                	NetApp_reboot="NO"
            	else
                	NetApp_reboot="YES"
                	echo "NetApp plugin需安裝" |tee >> $BIOS_log
                	sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/NetAppNasPlugin.v22.vib" |tee >> $BIOS_log
            	fi	
	
				if [ $BIOS_reboot == "YES" -o $Con_reboot == "YES" -o $NetApp_reboot == "YES" ];then
					echo "$x Reboot" |tee >> $BIOS_log
					sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot"
					echo "===========================================" |tee >> $BIOS_log
	
				elif [ $BIOS_reboot == "NO" -a $Con_reboot == "NO" -a $NetApp_reboot == "NO" ];then
					echo "無需調整Ya" |tee >> $BIOS_log
					### 搬移機器
		        	echo "$x" > $ok_list
		        	pwsh $move_script |tee >> $BIOS_log
		
		    	else
					echo "=== Lenovo part ERROR ===" |tee >> $BIOS_log	
		    	fi

		 ######################################################################################

		 ##########
		 ### HP ### 
		 ##########

		 ### Gen9

	    	elif [ $mode_tmp == "Enabled" -a $vendor_tmp == "HP" ] 2>/dev/null  ;then

		 		### 副程式定義
				get-bios-9()
				{
			    	/sbin/ilorest get --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --selector=Bios. --url=$ipmi_tmp -u administrator -p $ipmi_pass |egrep "PowerProfile|PowerRegulator|ProcHyperthreading|ProcTurbo|ProcVirtualization|RedundantPowerSupply|MinProcIdlePkgState|MinProcIdlePower|BootMode|AutoPowerOn" |tee > $BIOS
					sleep 5s
					wait
			    	/sbin/ilorest logout |tee > /dev/null
				}
	
				get-state()
				{
					/sbin/ilorest serverstate --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp --user administrator --password $ipmi_pass |grep "The server is currently in state" |awk -F \: '{print $2}' |sed s/[[:space:]]//g |tee > $State
					sleep 5s
                	wait
                	/sbin/ilorest logout |tee > /dev/null
				}

				change-bios-9()
				{
					/sbin/ilorest load -f /usr/local/ESXI-update/HCL/shell_scripts/setting/BIOS.json --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp --user administrator --password $ipmi_pass |tee >> $BIOS_log
					sleep 0.2
					wait
					/sbin/ilorest logout |tee > /dev/null
				}		
	
				reboot-server()
				{
					/sbin/ilorest reboot --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp --user administrator --password $ipmi_pass |tee >> $BIOS_log
					sleep 0.2
                	wait
                	/sbin/ilorest logout |tee > /dev/null
				}


			 ### 取得BIOS設定
				get-bios-9
	
		    	Pwr_check=`cat $BIOS |grep "RedundantPowerSupply" |awk -F \= '{print $2}' |sed 's/\#//g'`
		    	sysprofile_check=`cat $BIOS |grep "PowerProfile" |awk -F \= '{print $2}'`
	    		HT_check=`cat $BIOS |grep "ProcHyperthreading" |awk -F \= '{print $2}' |sed 's/\#//g'`
		    	Pwr_regu_check=`cat $BIOS |grep "PowerRegulator" |awk -F \= '{print $2}'`
		    	Turbo_check=`cat $BIOS |grep "ProcTurbo" |awk -F \= '{print $2}' |sed 's/\#//g'`
		    	C1E_check=`cat $BIOS |grep "MinProcIdlePower" |awk -F \= '{print $2}'`
		    	CState_check=`cat $BIOS |grep "MinProcIdlePkgState" |awk -F \= '{print $2}'`		

			 ### 將BIOS設定寫入Log
				echo ""	
				echo "===  檢查BIOS設定 ===" |sed '/^$/d' |tee >> $BIOS_log	
				cat $BIOS |grep "RedundantPowerSupply"	|tee >> $BIOS_log
				cat $BIOS |grep "PowerProfile"	|tee >> $BIOS_log
				cat $BIOS |grep "ProcHyperthreading"	|tee >> $BIOS_log
				cat $BIOS |grep "PowerRegulator"	|tee >> $BIOS_log
				cat $BIOS |grep "ProcTurbo"	|tee >> $BIOS_log
				cat $BIOS |grep "MinProcIdlePower"	|tee >> $BIOS_log
				cat $BIOS |grep "MinProcIdlePkgState"	|tee >> $BIOS_log
				echo "" |tee >> $BIOS_log

			 ### 檢查BIOS設定

				echo "=== 檢查結果 ===" |tee >> $BIOS_log	
				if [ $Pwr_check == "BalancedMode" ];then
					echo "電力設定  OK" |sed '/^$/d' |tee >> $BIOS_log
				else
					echo "電力設定  NO" |sed '/^$/d' |tee >> $BIOS_log
					/sbin/ilorest set AutoPowerOn="RestoreLastState" --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					Pwr_change="Change"	
				fi
	
				if [ $sysprofile_check == "MaxPerf" ];then
					echo "運作模式  OK" |sed '/^$/d' |tee >> $BIOS_log
				else
					echo "運作模式  NO" |sed '/^$/d' |tee >> $BIOS_log
					/sbin/ilorest set PowerProfile="MaxPerf" --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					Mode_change="Change"	
				fi
	
				if [ $HT_check == "Enabled" ];then
					echo "HT        OK" |sed '/^$/d' |tee >> $BIOS_log
				else
					echo "HT        NO" |sed '/^$/d' |tee >> $BIOS_log
					Ht_change="Change"
					/sbin/ilorest set ProcHyperthreading="Enabled" --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
				fi
	
				if [ $Pwr_regu_check == "StaticHighPerf" ];then
					echo "電力原則  OK" |sed '/^$/d' |tee >> $BIOS_log
				else
					echo "電力原則  NO" |sed '/^$/d' |tee >> $BIOS_log
					Pwr_regu_change="Change"
					/sbin/ilorest set PowerRegulator="StaticHighPerf" --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
				fi
	
				if [ $Turbo_check == "Enabled" ];then
					echo "加速模式  OK" |sed '/^$/d' |tee >> $BIOS_log
				else
					echo "加速模式  NO" |sed '/^$/d' |tee >> $BIOS_log
					/sbin/ilorest set ProcTurbo="Enabled" --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp	
					Turbo_change="Change"
				fi
	
	        	if [ $CState_check == "NoState" ];then
	            	echo "CState    OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "CState    NO" |sed '/^$/d' |tee >> $BIOS_log
					Cstate_change="Change"
	        	fi
	
				if [ $C1E_check == "NoCStates" ];then
					echo "C1E       OK" |sed '/^$/d' |tee >> $BIOS_log
				else
					echo "C1E       NO" |sed '/^$/d' |tee >> $BIOS_log
					C1E_change="Change"
				fi
			
				echo "===========================================" |sed '/^$/d' |tee >> $BIOS_log


				if [ "$Pwr_change" == "Change" -o "$Mode_change" == "Change" -o "$Ht_change" == "Change" -o "$Pwr_regu_change" == "Change" -o "$Turbo_change" == "Change" -o "$C1E_change" == "Change" -o "$Cstate_change" == "Change" ];then
					echo "***** BIOS 需調整 *****" |tee >> $BIOS_log
				 #				change-bios-9 -> 不可行 , 改為單項調整
					sleep 0.2
					wait
					BIOS_reboot="YES"
				else
					BIOS_reboot="NO"
				fi
	
	    		if [ $limit == "32" ];then
	        		Con_reboot="NO"
		    	else
					echo "NFS Connection Limit需調整" |tee >> $BIOS_log
		        	Con_reboot="YES"
		        	sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcfg-advcfg -s 32 /SunRPC/MaxConnPerIP" |tee >> $BIOS_log
		    	fi

			 ### 檢查NetApp plugin
            	if [ "$netapp" == "NetAppNasPlugin" ];then
                	NetApp_reboot="NO"
            	else
                	NetApp_reboot="YES"
                	echo "NetApp plugin需安裝" |tee >> $BIOS_log
                	sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/NetAppNasPlugin.v22.vib" |tee >> $BIOS_log
            	fi

		    	if [ $BIOS_reboot == "YES" -o $Con_reboot == "YES" -o $NetApp_reboot == "YES" ];then
	    	    	echo "$x Reboot" |tee >> $BIOS_log
		        	sshpass -p "$esxi_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "reboot"
	
		    	elif [ $BIOS_reboot == "NO" -a $Con_reboot == "NO" -a $NetApp_reboot == "NO" ];then
		        	echo "$x 無需調整Ya" |tee >> $BIOS_log
					### 搬移機器
					echo "$x" >	$ok_list
					pwsh $move_script |tee >> $BIOS_log
	
		    	else
		        	echo "=== HP-G9 restart ERROR ===" |tee >> $BIOS_log
		    	fi	
	
		 ######################################################################################################
		
		 ### Gen10
			elif [ $mode_tmp == "Enabled" -a $vendor_tmp == "HPE" ] 2>/dev/null  ;then

		 	 ### 副程式定義
	        	get-bios-10()
	        	{
	            	/sbin/ilorest get --selector=Bios. --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp -u administrator -p $ipmi_pass |egrep "BootMode|DynamicPowerCapping|EnhancedProcPerf|IntelProcVtd|PowerRegulator|ProcHyperthreading|ProcTurbo|ProcVirtualization|RedundantPowerSupply|MinProcIdlePkgState|MinProcIdlePower|WorkloadProfile" |tee > $BIOS
					sleep 5s 
					wait
	            	/sbin/ilorest logout |tee > /dev/null
	        	}

	        	get-state()
	        	{
	            	/sbin/ilorest serverstate --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp --user administrator --password $ipmi_pass |grep "The server is currently in state" |awk -F \: '{print $2}' |sed s/[[:space:]]//g |tee > $State
					sleep 5s
                	wait
                	/sbin/ilorest logout |tee > /dev/null
				
	        	}
	
	        	change-bios-10() ### 方法已失效
	        	{
	            	/sbin/ilorest load -f /usr/local/ESXI-update/HCL/shell_scripts/setting/BIOS2.json --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp --user administrator --password $ipmi_pass |tee >> $BIOS_log
					sleep 0.5
                	wait
                	/sbin/ilorest logout |tee > /dev/null
	        	}


	        	reboot-server()
	        	{
	            	/sbin/ilorest reboot --logdir=/usr/local/ESXI-update/Logs/HP/iLO_log --url=$ipmi_tmp --user administrator --password $ipmi_pass |tee >> $BIOS_log
					sleep 0.5
                	wait
                	/sbin/ilorest logout |tee > /dev/null
	        	}		

				### 取得BIOS設定
	        	get-bios-10

	        	Pwr_check=`cat $BIOS |grep "RedundantPowerSupply" |awk -F \= '{print $2}' |sed 's/\#//g'`
	        	sysprofile_check=`cat $BIOS |grep "WorkloadProfile" |awk -F \= '{print $2}'`
	        	HT_check=`cat $BIOS |grep "ProcHyperthreading" |awk -F \= '{print $2}' |sed 's/\#//g'`
	        	Pwr_regu_check=`cat $BIOS |grep "PowerRegulator" |awk -F \= '{print $2}'`
	        	Turbo_check=`cat $BIOS |grep "ProcTurbo" |awk -F \= '{print $2}' |sed 's/\#//g'`
	        	C1E_check=`cat $BIOS |grep "MinProcIdlePower" |awk -F \= '{print $2}'`
	        	CState_check=`cat $BIOS |grep "MinProcIdlePkgState" |awk -F \= '{print $2}'`
				Virtual_check=`cat $BIOS |grep "ProcVirtualization" |awk -F \= '{print $2}' |sed 's/\#//g'`

				### 將BIOS設定寫入Log
	        	echo ""
	        	echo "===  檢查BIOS設定 ===" |sed '/^$/d' |tee >> $BIOS_log
	        	cat $BIOS |grep "RedundantPowerSupply"  |tee >> $BIOS_log
	        	cat $BIOS |grep "WorkloadProfile"  |tee >> $BIOS_log
	        	cat $BIOS |grep "ProcHyperthreading"    |tee >> $BIOS_log
	        	cat $BIOS |grep "PowerRegulator"    |tee >> $BIOS_log
	        	cat $BIOS |grep "ProcTurbo" |tee >> $BIOS_log
	        	cat $BIOS |grep "MinProcIdlePower"  |tee >> $BIOS_log
	        	cat $BIOS |grep "MinProcIdlePkgState"   |tee >> $BIOS_log
				cat $BIOS |grep "Virtual_check" |tee >> $BIOS_log
	        	echo "" |tee >> $BIOS_log
	
				### 檢查BIOS設定

	        	echo "=== 檢查結果 ===" |tee >> $BIOS_log
	        	if [ $Pwr_check == "BalancedMode" ];then
	            	echo "電力設定  OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "電力設定  NO" |sed '/^$/d' |tee >> $BIOS_log
	            	Pwr_change="Change"
					/sbin/ilorest set RedundantPowerSupply=BalancedMode	--selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					wait
	        	fi
	
	        	if [ $sysprofile_check == "Virtualization-MaxPerformance" ];then
	            	echo "運作模式  OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "運作模式  NO" |sed '/^$/d' |tee >> $BIOS_log
	            	Mode_change="Change"
					/sbin/ilorest set WorkloadProfile=Virtualization-MaxPerformance --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					wait
	        	fi
	
	        	if [ $HT_check == "Enabled" ];then
	            	echo "HT        OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "HT        NO" |sed '/^$/d' |tee >> $BIOS_log
	            	Ht_change="Change"
					/sbin/ilorest set ProcHyperthreading=Enabled --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					wait
	        	fi

    	    	if [ $Pwr_regu_check == "StaticHighPerf" ];then
	            	echo "電力原則  OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "電力原則  NO" |sed '/^$/d' |tee >> $BIOS_log
	            	Pwr_regu_change="Change"
					/sbin/ilorest set PowerRegulator=StaticHighPerf --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					wait
	        	fi
	
	        	if [ $Turbo_check == "Enabled" ];then
	            	echo "加速模式  OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "加速模式  NO" |sed '/^$/d' |tee >> $BIOS_log
	            	Turbo_change="Change"
					/sbin/ilorest set ProcTurbo=Enabled --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					wait
	        	fi
	
	        	if [ $CState_check == "NoState" ];then
	            	echo "CState    OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "CState    NO" |sed '/^$/d' |tee >> $BIOS_log
					/sbin/ilorest set MinProcIdlePkgState=NoState --selector=Bios. --commit -u administrator -p $ipmi_pass --url=$ipmi_tmp
					Cstate_change="Change"
	        	fi
	
	        	if [ $C1E_check == "NoCStates" ];then
	            	echo "C1E       OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "C1E       NO" |sed '/^$/d' |tee >> $BIOS_log
	            	C1E_change="Change"
					/sbin/ilorest set MinProcIdlePower=NoCStates --commit --selector=Bios. -u administrator -p $ipmi_pass --url=$ipmi_tmp
	        	fi
	
	        	if [ $Virtual_check == "Enabled" ];then
	            	echo "Virtual   OK" |sed '/^$/d' |tee >> $BIOS_log
	        	else
	            	echo "Virtual   NO" |sed '/^$/d' |tee >> $BIOS_log
	            	Virtual_change="Change"
					/sbin/ilorest set ProcVirtualization=Enabled --commit --selector=Bios. -u administrator -p $ipmi_pass --url=$ipmi_tmp
	        	fi
	
	        	echo "===========================================" |sed '/^$/d' |tee >> $BIOS_log
	
	        	if [ "$Pwr_change" == "Change" -o "$Mode_change" == "Change" -o "$Ht_change" == "Change" -o "$Pwr_regu_change" == "Change" -o "$Turbo_change" == "Change" -o "$C1E_change" == "Change" -o "$Virtual_change" == "Change" -o "$Cstate_change" == "Cstate_change" ];then
					echo ""
	            	echo "***** BIOS 需調整 *****" |tee >> $BIOS_log
	            	### change-bios-10  -> 方法可行, 但json檔需指名iLO版本,不夠彈性 
					sleep 0.2
					wait
	            	BIOS_reboot="YES"
	        	else
	            	BIOS_reboot="NO"
	        	fi
	
	        	if [ $limit == "32" ];then
	            	Con_reboot="NO"
	        	else
					echo "" |tee >> $BIOS_log
	            	echo "NFS Connection Limit需調整" |tee >> $BIOS_log
	            	Con_reboot="YES"
	            	sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcfg-advcfg -s 32 /SunRPC/MaxConnPerIP" |tee >> $BIOS_log
					sleep 0.5
					wait
	        	fi

			 ### 檢查NetApp plugin
            	if [ "$netapp" == "NetAppNasPlugin" ];then
                	NetApp_reboot="NO"
            	else
                	NetApp_reboot="YES"
                	echo "NetApp plugin需安裝" |tee >> $BIOS_log
                	sshpass -p $esxi_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$x "esxcli software vib install -v /vmfs/volumes/ef225d93-ec0ff12b/NetAppNasPlugin.v22.vib" |tee >> $BIOS_log
            	fi
	
	        	if [ $BIOS_reboot == "YES" -o $Con_reboot == "YES" -o $NetApp_reboot == "YES" ];then
	            	echo "" |tee >> $BIOS_log
					echo "***** $x Reboot *****" |tee >> $BIOS_log
					reboot-server
	
	        	elif [ $BIOS_reboot == "NO" -a $Con_reboot == "NO" -a $NetApp_reboot == "NO" ];then
	            	echo "$x 無需調整Ya" |tee >> $BIOS_log
	            	### 搬移機器
	           		echo "$x" > $ok_list
	           		pwsh $move_script |tee >> $BIOS_log
	
	        	else
	            	echo "=== HP-G10 restart ERROR ===" |tee >> $BIOS_log
	        	fi

			else
				time_stamp
	        	echo "Check Maintainance_Mode or Vendor !!!" |tee >> $BIOS_log
	        	echo "===========================================" |tee >> $BIOS_log
	    	fi
		else
			time_stamp
	    	echo "******* SSH_check ERROR *******" |tee >> $BIOS_log
	    	echo "" |tee >> $BIOS_log
		fi	
	done
	control_ok
else
	time_stamp
	echo "=== 程式卡控異常 ===" |tee >> $BIOS_log
	echo ""
fi
