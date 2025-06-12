Write-Host -ForegroundColor Cyan "Installing Hyper-V. This server will automatically restart after role is installed."
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Confirm:$false -Restart:$false
Restart-Computer