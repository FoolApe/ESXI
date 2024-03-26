#!/bin/bash
list="$PWD/esxi_list"
line=$(cat $PWD/esxi_list |wc -l)
vib=$(ls $PWD/*.vib)
time_log=`date +"%F %T"`
log_path="$PWD/logs/"
[[ -d "$log_path" ]] || mkdir $log_path


for (( i=1; i<=$line; i++ ))
do
        esxi_ip=$(cat $list |awk '{print $1}' |awk "NR==$i")
        #scp via
        scp -rp "${vib}" root@"${esxi_ip}":/tmp
#       [[ "$?" -eq "0" ]] && echo ${time_log} scp_sussece >> ${log_path}esxi.log ||  echo ${time_log} scp_fail >> ${log_path}esxi.log
        if [ "$?" -eq "0" ] ;then
                echo ${time_log} scp_sussece >> ${log_path}esxi.log
        else
                echo ${time_log} scp_fail >> ${log_path}esxi.log
                break
        fi
        #install and reboot
        ssh -T  root@"${esxi_ip}" "esxcli software vib install -v /tmp/NVIDIA*.vib --maintenance-mode" >> ${log_path}esxi.log
#       [[ "$?" -eq "0" ]] && ssh -T root@"${esxi_ip}" "esxcli system shutdown reboot --reason=testing" || echo ${time_log} NVIDIA install faill >> ${log_path}esxi.log
        if [ "$?" -eq "0" ] ;then
                ssh -T root@"${esxi_ip}" "esxcli system shutdown reboot --reason=testing" >> ${log_path}esxi.log
        else
                echo ${time_log} NVIDIA install faill >> ${log_path}esxi.log
                break
        fi
        sleep 10m
        #disable ECC
        ssh -T  root@"${esxi_ip}" "nvidia-smi -e 0" >> ${log_path}esxi.log
        #[[ "$?" -eq "0" ]] && ssh -T root@"${esxi_ip}" "esxcli system shutdown reboot --reason=testing" || echo ${time_log} ECC set faill >> ${log_path}esxi.log
        if [ "$?" -eq "?" ] ;then
                ssh -T root@"${esxi_ip}" "esxcli system shutdown reboot --reason=testing" >> ${log_path}esxi.log
        else
                echo ${time_log} ECC set faill >> ${log_path}esxi.log
                break
        fi

done
