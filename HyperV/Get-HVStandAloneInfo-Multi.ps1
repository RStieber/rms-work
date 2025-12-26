$outPath = Read-Host "Please enter Full output path (.csv extension)"
$hostList = Read-Host "Please enter the FQDN of each host, separated by commas (eg: Host1.fabrikam.com,Host2.fabrikam.com,...)"

$vmOutput = New-Object System.Collections.ArrayList

Write-Host -ForegroundColor Yellow "This may take a few moments, please wait"

$hostsArray = $hostList.Split(",")
foreach($vmHost in $hostsArray) {

    Write-Host -foregroundcolor Cyan "Gathering VM info from '$vmHost' and writing it to '$outPath'"

    $vms = Get-VM -ComputerName $vmHost

    foreach($vm in $vms) {
	    $vhds = Get-VHD -VmId $vm.vmId -ComputerName $vmHost
    
        $vhdTotalProvisionedGb = 0
        $vhdTotalInUseGb = 0
        $vhdTotalRemainingGb = 0
        $numberOfDisks = 0
    
        foreach($vhd in $vhds) {
            $vhdTotalProvisionedGb += $vhd.size/1gb -as [int]
            $vhdTotalInUseGb += $vhd.FileSize/1gb -as [int]
            $vhdTotalRemainingGb += ($vhd.size/1gb - $vhd.fileSize/1gb) -as [int]
            $numberOfDisks++
        }

        $vlans = $null
        $ipAddresses = $null

        if($vm.NetworkAdapters.Count -gt 1) {
            foreach($netAdapter in $vm.NetworkAdapters) {
                $vlans += if($netAdapter.VlanSetting.AccessVlanId -eq 0) { '<native>; ' } else { "$($netAdapter.VlanSetting.AccessVlanId); " }
                if($netAdapter.IPAddresses) {
                    foreach($ip in $netAdapter.IpAddresses) {
                        $ipAddresses += "$ip; "
                        } 
                    }
                else {
                    $ipAddresses += "<none>; "
                }
            }
        }
        else {
            $vlans = if($vm.NetworkAdapters.VlanSetting.AccessVlanId -eq 0) { '<native>; ' } else { "$($vm.NetworkAdapters.VlanSetting.AccessVlanId); " }
            if($vm.NetworkAdapters.IPAddresses) {
                foreach($ip in $vm.NetworkAdapters.IpAddresses) {
                    $ipAddresses += "$ip; "
                    }            
                }
            else {
                $ipAddresses += "<none>; "
            }
        }

        $null = $vmOutput.Add((New-Object PSObject -Property @{'VM_Name' = $vm.Name; 'VM_State' = $vm.State; 'Host_Name'=$vm.ComputerName; 'IsClustered'=$vm.IsClustered.ToString(); 'vCPU'=$vm.ProcessorCount; 'RAM_GB'=($vm.MemoryStartup/1Gb -as [int]); `
                                                  'NumberOfDisks'=$numberOfDisks; 'TotalSizeOnDiskGb'=$vhdTotalProvisionedGb; 'TotalInUseGb'=$vhdTotalInUseGb; 'TotalRemainingGb'=$vhdTotalRemainingGb; `
                                                  'NumberOfNics'=$vm.NetworkAdapters.count; 'VLANs'=$vlans; 'IpAddresses'=$ipAddresses}))
    }
}

$vmOutput | Select VM_Name,VM_state,Host_Name,IsClustered,vCPU,RAM_GB,NumberOfDisks,TotalSizeOnDiskGb,TotalInUseGb,TotalRemainingGb,NumberOfNics,VLANs,IpAddresses | Export-Csv -Path $outPath -NoTypeInformation

Write-Host -ForegroundColor Green "File has been written to '$outPath'"