$dnsSuffix = Read-Host "Enter DNS Suffix for Workgroup cluster"

Write-Host -ForegroundColor Cyan "Setting DNS suffix on OS vNIC"
$null = Get-NetAdapter | Where {$_.Name -eq "vEthernet (OS_Mgmt_vNIC)"} | Set-DnsClient -ConnectionSpecificSuffix $dnsSuffix

Write-Host -ForegroundColor Cyan "Disabling the 'Register this Connection with DNS' setting on host and cluster vNICs"
$null = Get-NetAdapter | Where {$_.Name -eq "vEthernet (OS_Mgmt_vNIC)"} | Set-DNSClient -RegisterThisConnectionsAddress $False
$null = Get-NetAdapter | Where {$_.Name -eq "vEthernet (Cluster_vNIC)"} | Set-DNSClient -RegisterThisConnectionsAddress $False

Write-Host -ForegroundColor Cyan "Setting DNS suffix on host"
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" -Name "NV Domain" -Value $dnsSuffix
Set-DnsClientGlobalSetting -SuffixSearchList $dnsSuffix

#remove this if cert-based authentication is ever figured out and uncomment the yes/no below
Write-Host -ForegroundColor Yellow "Workgroup Clustering requires a user with the same username and password created on all cluster nodes. You will be prompted for credentials after continuing; MAKE SURE THEY ARE THE SAME ACROSS ALL CLUSTER NODES!"
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
$newUser = Get-Credential -Message "Local User and Password"

Write-Host -ForegroundColor Cyan "`r`nCreating local user and adding to administrators group"
$null = New-LocalUser -Name $newUser.UserName -Password $newUser.Password -FullName $newUser.UserName -Description "WG Cluster shared user"
$null = Add-LocalGroupMember -Group "Administrators" -Member $newUser.UserName

Write-Host -ForegroundColor Cyan "Setting Local Account Token Filter Policy to 1"
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0x1 /f

<# Commenting this yes/no out for now -- we will be using user-based authentication, where usernames and passwords should match across hosts
$yesNo = Read-Host "Are you going to cluster these hosts using certificates? (Y/N)"
if($yesNo.ToUpper() -eq "N") {
    Write-Host -ForegroundColor Yellow "Workgroup Clustering requires a user with the same username and password created on all cluster nodes. You will be prompted for credentials after continuing; MAKE SURE THEY ARE THE SAME ACROSS ALL CLUSTER NODES!"
    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    $newUser = Get-Credential -Message "Local User and Password"

    Write-Host -ForegroundColor Cyan "Creating local user and adding to administrators group"
    $null = New-LocalUser -Name $newUser.UserName -Password $newUser.Password -FullName $newUser.UserName -Description "WG Cluster shared user"
    $null = Add-LocalGroupMember -Group "Administrators" -Member $newUser.UserName

    Write-Host -ForegroundColor Cyan "Setting Local Account Token Filter Policy to 1"
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0x1 /f
    }
elseif($yesNo.ToUpper() -eq "Y") {
    Write-Host -ForegroundColor Yellow "Certificates require a PKI to be in place; this script will create the request for you"
    $serverShortName = $env:COMPUTERNAME
    $serverFQDN = "$serverShortName.$dnsSuffix"
    $clusterName = Read-Host "Please enter the short name of the Cluster you will be creating with these hosts"
    $clusterFQDN = "$clusterName.$dnsSuffix"
    $tempPath = "C:\Host Setup\"

    if(!(Test-Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath
    }

    Write-Host -ForegroundColor Cyan "Creating .inf file for cert request and saving it to '$($tempPath+$serverShortName).inf'"
    (Get-Content -Path .\certRequestTemplate.inf).Replace("<serverShortName>",$serverShortName).Replace("<serverFQDN>",$serverFQDN).Replace("<clusterShortName>",$clusterName).Replace("<clusterFQDN>",$clusterFQDN) | Out-File "$($tempPath+$serverShortName).inf"

    Write-Host -ForegroundColor Cyan "Creating .req file to fulfill from PKI and saving it to '$($tempPath+$serverShortName).req' -- you will need this file!"
    certreq.exe -new "$($tempPath+$serverShortName).inf" "$($tempPath+$serverShortName).req"
}
#>

Write-Host -ForegroundColor Cyan "Enabling PS Remoting"
Enable-PSRemoting

$clusterHosts = Read-Host "Enter host and cluster short-names as a comma-separated list (ex: Host1,Host2,Host3,Cluster1)"
Write-Host -ForegroundColor Cyan "Adding hosts to WinRM Trusted Hosts list"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $clusterHosts.ToString() -Confirm:$false

Write-Host -ForegroundColor Yellow "The next step is to set the workgroup for this node; workgroups can only be alpha-numeric, no special characters!"
$workgroupName = Read-Host "Enter the workgroup name for this server; this must match across all cluster nodes!"
Add-Computer -WorkgroupName $workgroupName -Restart:$false -Confirm:$false

$yesNo = Read-Host "Server needs to restart; do you want to restart now? (Y/N)"
if($yesNo.ToUpper() -eq "Y") {
    Restart-Computer -Force -Confirm:$false
}