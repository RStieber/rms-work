Write-Host -ForegroundColor Yellow "**WARNING** Running this script may disconnect RDP sessions. Make sure you have LOM access before running this script!!"
$answer = Read-Host "Do you want to continue? (Y/N)"

if($answer.ToUpper() -eq "Y") {
    Import-Module Hyper-V

    $nics = Read-Host "Enter Ethernet Adapter names to include in the Cluster switch as a comma separated list (ex: Cluster 1,Cluster 2)"
    $ip = Read-Host "Host's Cluster communication IP address"
    $cidr = Read-Host "CIDR notation for subnet size (ex: enter 24 for 255.255.255.0 netmask)"
    $gateway = Read-Host "Cluster network default gateway address (optional, leave blank if none)"
    $vlan = Read-Host "VLAN for cluster (optional, leave blank if none)"

    Write-Host -ForegroundColor Cyan "Creating ClusterSwitch..."
    $null = New-VMSwitch -Name "ClusterSwitch" -AllowManagementOS $false -NetAdapterName $nics.Split(",") -EnableEmbeddedTeaming $true

    Write-Host -ForegroundColor Cyan "Creating Cluster_vNIC from ClusterSwitch..."
    $null = Add-VMNetworkAdapter -Name "Cluster_vNIC" -SwitchName "ClusterSwitch" -ManagementOS
    if($vlan) {
        $null = Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "Cluster_vNIC" -Access -VlanId $vlan -Confirm:$false
    }

    Write-Host -ForegroundColor Cyan "Setting Cluster_vNIC IP address..."
    $netAdapter = Get-NetAdapter | Where {$_.Name -eq "vEthernet (Cluster_vNIC)"}    
    if($gateway) {
        $null = $netAdapter | New-NetIPAddress -IPAddress $ip -PrefixLength $cidr -DefaultGateway $gateway
    }
    else {
        $null = $netAdapter | New-NetIPAddress -IPAddress $ip -PrefixLength $cidr
    }

    Write-Host -ForegroundColor Cyan "Disabling IPv6 on all NICs"
    Get-NetAdapterBinding -ComponentID "ms_tcpip6" | where Enabled -eq $true | Disable-NetAdapterBinding -ComponentID "ms_tcpip6"
}