$vmNames = Read-Host "Enter VM name (comma separate for more than 1 VM)"

foreach($vmName in $vmNames.Split(",")) {
    $vm = Get-VM $vmName

    $nicsToAdd = 0
    $nicsToAdd = Read-Host "Enter # of NICs to add to $vmName"

    for($i = 1; $i -le $nicsToAdd; $i++) {
        $nic = $null
        $nic = $vm | Add-VMNetworkAdapter -SwitchName "VmSwitch" -Passthru
    
        $vlanID = $null
        $vlanID = Read-Host "Enter VLAN ID for new NIC #$i on $vmName (enter for no VLAN)"
        if($vlanID) {
            $nic | Set-VMNetworkAdapter -MacAddressSpoofing On -AllowTeaming On
            $nic | Set-VMNetworkAdapterVlan -VlanId $vlanID -Access
        }
        else {
            $nic | Set-VMNetworkAdapter -MacAddressSpoofing On -AllowTeaming On
        }    
    }

    $vm | Set-VM -MemoryStartupBytes (8192*1024*1024)
    $vm | Set-VMProcessor -ExposeVirtualizationExtensions $true
}