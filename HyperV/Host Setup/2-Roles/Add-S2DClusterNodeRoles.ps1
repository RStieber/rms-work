Write-Host -ForegroundColor Cyan "Installing Failover Clustering, File Server, Datacenter Bridging, and Hyper-V. This server will automatically restart after they are installed."
Install-WindowsFeature Failover-Clustering -IncludeManagementTools -Confirm:$false
Install-WindowsFeature "Data-Center-Bridging" -Confirm:$false -Restart:$false
Install-WindowsFeature "FS-FileServer" -Confirm:$false -Restart:$false
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Confirm:$false -Restart:$false
Restart-Computer