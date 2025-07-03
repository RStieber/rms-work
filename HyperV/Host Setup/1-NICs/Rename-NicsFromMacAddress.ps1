$csvLocation = (Read-Host "Please enter the full path to the CSV with NIC Names and MAC Addresses").Trim("`"")

$csv = Import-CSV $csvLocation
$netAdapters = Get-NetAdapter

foreach ($line in $csv) {
    $mac = ($line.MacAddress).ToUpper().Replace(":","-")
    $currentAdapter = $null
    $currentAdapter = $netAdapters | Where {$_.MacAddress -eq $mac}

    if($currentAdapter) {
        Write-Host -ForegroundColor Cyan "Renaming Net Adapter '$($currentAdapter.Name)' ($($mac)) to '$($line.NewNicName)'"
        $null = $currentAdapter | Rename-NetAdapter -PassThru -NewName $line.NewNicName
        }
    else {
        Write-Host -ForegroundColor Yellow "No Net Adapter found with MAC address '$mac', skipping"
    }
}

Write-Host -ForegroundColor Cyan "Disabling IPv6 on all NICs"
Get-NetAdapterBinding -ComponentID "ms_tcpip6" | where Enabled -eq $true | Disable-NetAdapterBinding -ComponentID "ms_tcpip6"