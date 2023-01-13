### Made by       : DC-SI-SEP-Juro 
### First version : 2023/01/12
### Description	  : disconnect ESXI then reconnect to solve the IP issue.


$user='USER_NAME@vsphere.local'
$passwd=cat /PATH/TO/YOUR/PASSWORD
$server='VC_IP'

echo "****** 開始連接$server ******"
Connect-VIServer -Server $server -User $user -Password $passwd |out-null
echo " "

foreach ($a in $(Get-VMHost -State Connected))
{
	echo "=== $a 重連中 ==="
	get-vmhost -name $a |Set-VMHost -State disconnected
	start-sleep -s 10
	get-vmhost -name $a |Set-VMHost -State connected
	start-sleep -s 10
	echo ""
}


Disconnect-VIServer -Server $server -Confirm:$false |out-null
echo "--------------"
echo "|Process done|"
echo "--------------"
echo " "
