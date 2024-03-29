import-Module VMware.VimAutomation.Core
#環境變數，執行前請先確認
$server = "VC_IP"
$log='/tmp/vmhost-usage.log'
$datetime=Get-Date -Format "yyyy.MM.dd"
$file="/tmp/OA-${datetime}-$server.csv"
$PASSW=ConvertTo-SecureString -String $env:DomainUserPassword -AsPlainText -Force
$Cred=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $env:DomainUser, $PASSW ### 登入VC用的帳密 ###
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

### 先清空舊資訊
echo "+) 清空舊資訊...."
rm -rf /tmp/OA-*-$server.csv
echo -n ""> $file

### 連接VC
Connect-VIServer -Server $server -Credential $Cred -Force |Out-Null
echo "+) $server 已登入" 
echo ""
Get-date -UFormat "%Y-%m-%d %r" >> $log
echo "======================" >> $log

### main
$vmhost=Get-VMHost |where {$_.PowerState -eq 'PoweredOn'}
foreach ($a in $vmhost)
{
  	echo "抓取 $a 資訊"
    ### 取得ESXi資訊
    $name = $a.Name
    $host_CPU = [math]::round((Get-VMHost -name $a | Measure-Object -Property NumCpu -Sum).sum)*2
    $host_MEM = [math]::round((Get-VMHost -name $a | Measure-Object -Property MemoryTotalGB -Sum).sum) 

    ### CPU總和
    $sum_CPU = (Get-VMHost -Name $a | Get-VM | Where-Object {$_.PowerState -eq 'PoweredOn'} | Measure-Object -Property NumCPU -Sum).Sum
    if ([string]::IsNullOrEmpty($sum_CPU)) 
    {
        $sum_CPU = 0
    }
    #echo $sum_CPU
    
    ### MEM總和(取到整數位)
    $sum_MEM = [math]::round((Get-VMHost -Name $a | Get-VM | Where-Object {$_.PowerState -eq 'PoweredOn'} | Measure-Object MemoryGB -Sum).Sum)
    if ([string]::IsNullOrEmpty($sum_MEM)) 
    {
        $sum_MEM = 0
    }
    #echo $sum_MEM
    
    ### 輸出
    $output = Write-Output "$name,$host_CPU,$sum_CPU,$host_MEM,$sum_MEM" |sed 's/[[:space:]]//g'
    $output >> $file
    if ($sum_MEM -ge $host_MEM) { echo "$name-MEM超用" >> $log}   
}

echo "" >> $log
echo "" >> $log

### 登出VC
Disconnect-VIServer -Server $server -Confirm:$false |out-null
echo "+) 已登出 $server" 
