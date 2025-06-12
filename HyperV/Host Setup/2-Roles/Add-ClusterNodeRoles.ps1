Write-Host -ForegroundColor Cyan "Installing Failover Clustering, Multipath IO (MPIO), and Hyper-V. This server will automatically restart after they are installed."
Install-WindowsFeature Failover-Clustering -IncludeManagementTools -Confirm:$false
Add-WindowsFeature -Name Multipath-IO -Confirm:$false
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Confirm:$false -Restart:$false
Restart-Computer