### Made by       : SYS-Juro
### First version : 2020/8/19
### Update date	  : 2022/01/27
### Description   : Change firewall rule to let auto_update-server in

$log='/Path/To/Your/Log'
$list='/Path/To/Your/List'

echo "===================" |tee >> $log
date |awk '{print $6,$2,$3,$4}' |sed 's/月//g' |tee >> $log
echo "===================" |tee >> $log
echo ""

$user='USER@domain'
$passwd=cat /Path/To/Your/Password
$server='vCenter_IP'
$key1='JU45U-6LLEL-*****-VJC7M-9CCLW'
$key2='5C2DM-20J1N-*****-UACE2-23XNL'

Connect-VIserver -Server $server -User $user -Password $passwd |out-null
foreach($x in get-content $list)
{
	$esxcli=Get-Esxcli -VMhost $x
	$esxcli.network.firewall.ruleset.set($false,$true,"sshServer") |Out-Null
	$esxcli.network.firewall.ruleset.allowedip.add("10.10.10.10","sshServer") |Out-Null
	$esxcli.network.firewall.ruleset.allowedip.add("10.10.10.11","sshServer") |Out-Null
	$esxcli.network.firewall.ruleset.allowedip.add("10.10.10.12","sshServer") |Out-Null

	### Check NFS limit
	$tmp=Get-VMHost -Name $x -Server $server |Get-AdvancedSetting -Name SunRPC.MaxConnPerIP
	$num=echo $tmp |grep "SunRPC.MaxConnPerIP" |awk '{print $2}'

	if("$num" -ne 32) ### For DRD infra
	{
    	Get-VMHost -Name $x -Server $server |Get-AdvancedSetting -Name SunRPC.MaxConnPerIP |Set-AdvancedSetting -Value 32 -Confirm:$False |tee >> $log
	}

	### Check HT
	$tmp2=Get-AdvancedSetting -Entity $x -server $server -Name vmkernel.boot.hyperthreading 
	$ht=echo $tmp2 |grep 'VMkernel.Boot' |awk '{print $2}'
	if("$ht" -ne 'True')
	{
		Get-AdvancedSetting -Entity $x -server $server -Name vmkernel.boot.hyperthreading |Set-AdvancedSetting -Value "True" -Confirm:$false |tee >> $log
	}

	### NTP
	$policy=Get-VMHost -Name $x |Get-VMHostService |Where-Object {$_.key -eq "ntpd"} |select Policy
	$status=Get-VMHost -Name $x |Get-VMHostService |Where-Object {$_.key -eq "ntpd"} |select Running
	$fw=Get-VMHost -Name $x | Get-VMHostFirewallException | Where-Object {$_.Name -eq "NTP client"} |select Enabled
	if ($policy -match 'off' -or $fw -match 'False' -or $status -match 'False')
	{
    	Get-VMHost -server $server -Name $x |Get-VMHostService |Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false |out-null
    	Get-VMHost -server $server -Name $x |Get-VMHostService |Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "on" |out-null
    	Get-VMHost -server $server -Name $x |Get-VMHostFirewallException | Where-Object {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true |out-null
    	Get-VMHost -server $server -Name $x |Get-VMHostService |Where-Object {$_.key -eq "ntpd"} | Start-VMHostService
	}

	### Key
	$host_key=Get-VMHost -Name $x |select LicenseKey
	if ( $host_key -match "$key1" -or $host_key -match "$key2" )
	{
		echo "" |tee >> $log
		echo "=== $x OK ===" |tee >> $log
		echo "" |tee >> $log
	}
	else 
	{
		Set-VMHost -VMHost $x -LicenseKey $key |out-null
		echo "" |tee >> $log
		echo "=== $x OK ===" |tee >> $log
		echo "" |tee >> $log
	}
}
echo "" |tee >> $log
echo "" |tee >> $log
Disconnect-VIServer -Server $server -Confirm:$false |out-null

