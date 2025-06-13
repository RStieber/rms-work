Write-Host -ForegroundColor Yellow "**WARNING** You may lose RDP connectivity until you create a virtual NIC for the OS. Make sure you have LOM access before running this script!!"
$answer = Read-Host "Do you want to continue? (Y/N)"

if($answer.ToUpper() -eq "Y") {
    Import-Module Hyper-V

    $nics = Read-Host "Enter Ethernet Adapter names to include in the VM switch as a comma separated list (ex: VM 1,VM 2,VM 3)"
    $ip = Read-Host "Host static IP address"
    $cidr = Read-Host "CIDR notation for subnet size (ex: enter 24 for 255.255.255.0 netmask)"
    $gateway = Read-Host "Host default gateway address"
    $vlan = Read-Host "VLAN for host (optional, leave blank if none)"
    $dns1 = Read-Host "First DNS server IP address"
    $dns2 = Read-Host "Second DNS server IP address (optional, leave blank if none)"

    Write-Host -ForegroundColor Cyan "Creating VmSwitch..."
    $null = New-VMSwitch -Name "VmSwitch" -AllowManagementOS $false -NetAdapterName $nics.Split(",") -EnableEmbeddedTeaming $true

    Write-Host -ForegroundColor Cyan "Creating OS_Mgmt_vNIC from VmSwitch..."
    $null = Add-VMNetworkAdapter -Name "OS_Mgmt_vNIC" -SwitchName "VmSwitch" -ManagementOS
    if($vlan) {
        $null = Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "OS_Mgmt_vNIC" -Access -VlanId $vlan -Confirm:$false
    }

    Write-Host -ForegroundColor Cyan "Setting OS_Mgmt_vNIC IP address..."
    $netAdapter = Get-NetAdapter | Where {$_.Name -eq "vEthernet (OS_Mgmt_vNIC)"}    
    $null = $netAdapter | New-NetIPAddress -IPAddress $ip -PrefixLength $cidr -DefaultGateway $gateway
    $null = $netAdapter | Set-DnsClientServerAddress -ServerAddresses $dns1,$dns2
}
