$serverName = Read-Host "Enter name for server"
Rename-Computer -NewName $serverName -Restart:$false

"Setting Hypervisor Launch Type to Auto"
bcdedit /set hypervisorlaunchtype auto

"Activating Windows from local host"
slmgr /ipk WWVGQ-PNHV9-B89P4-8GGM9-9HPQ4

$yesNo = Read-Host "Upgrade to Server 2025 Datacenter? (Y/N)"

if($yesNo.ToUpper() -eq "Y") {
    $datacenterKey = Read-host "Please enter the Server 2025 Datacenter key"
    "Updating to Server 2025 Datacenter; server will restart after this"
    dism /online /set-edition:serverdatacenter /productkey:$datacenterKey /accepteula /quiet
}