<#
.SYNOPSIS
    This script will clone a Hyper-V VM via export and import

.DESCRIPTION
    This script will request information from the user, such as source VM name, source host, and will export it to the host's default VM storage location. It will then import that VM
    with a new name (gathered from the user) and will also rename the disks with VmName_SCSI Controller #_Disk #

.PARAMETER Param
    Description of the first parameter the script takes.

.EXAMPLE
    ./CloneHyperVVms.ps1

.NOTES
    RSAT for Hyper-V and possibly Failover Cluster Manager if the user specifies that the VM Template is on a Failover Cluster

#>

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Host -ForegroundColor Yellow "!! WARNING: In order to clone a VM with this script, the source VM needs to be powered off! You will also need Administrative permissions on the Hyper-V host were the source VM lives!"
Write-Host -ForegroundColor Yellow "You will also need to have Hyper-V and possibly Failover Cluster RSAT installed where this script is running."

if(!(Get-Module -Name Hyper-V -ListAvailable)) {
    Write-Host -ForegroundColor Red "This script requires the Hyper-V Management tools and powershell module to run; they are not present on this server. Exiting Script"
    exit
}
else {
    Import-Module Hyper-V
}

if($TemplateOnCluster -and !(Get-Module -Name FailoverClusters -ListAvailable)) {
    Write-Host -ForegroundColor Red "Running this script with "-TemplateOnCluster" specified requires the Failover Cluster Management tools and powershell module to run; they are not present on this server. Exiting Script"
    exit
}
elseif ($TemplateOnCluster) {
    Import-Module FailoverClusters
}

#read info from the user
$hvHost = $null
$hvHost = Read-Host "Enter host or cluster FQDN where the template resides (blank will use this host)"
$cloneSource = Read-Host "Enter the name of the VM you wish to clone"
if($hvHost -ne $null -or $hvHost -ne "") {
    $clusterAnswer = Read-Host "Is this template hosted in a Hyper-V Failover cluster? (Y/N)"
    }
$newVMName = Read-Host "Enter the name of the new VM"
$cluster = $false

if($hvHost -eq $null -or $hvHost -eq "") {
    $hvHost = $env:ComputerName
}

#get the hyper-v host directly from the cluster name
if($clusterAnswer.ToUpper() -eq "Y") {
    $cluster = $true
}

if($cluster) {
    $hvHost = (Get-ClusterGroup -Name $cloneSource.ToString() -Cluster $hvHost).OwnerNode.Name
}

#start the export process by attempting to get the VM the user specified
$vm = $null
$vm = Get-VM -Name $cloneSource -ComputerName $hvHost

if(!$vm) {
    Write-Host -ForegroundColor Red "Source VM with name '$cloneSource' could not be found, please make sure the name is exactly as it displays in Failover Cluster Manager or Hyper-V Manager!"
    exit
}

if($vm.State -ne "Off") {
    Write-Host -ForegroundColor Red "VM Template '$VmTemplateName' is not powered off, cloning cannot continue!  Exiting script"
    exit
}

#gather VM and Disk path placement defaults and set up export path
$hostObject = Get-VMHost $hvHost
$vmPath = $hostObject.VirtualMachinePath
$diskPath = $hostObject.VirtualHardDiskPath
$exportPath = "$($vmPath.TrimEnd('\'))\Exports"

#check for existing export of the source VM
$existingVmcx = $null

#we're going to try/catch this, we don't need it to be there if it's not
try {
    $existingVmcx = Get-ChildItem -Recurse -Path "$exportPath\$cloneSource" -Filter "*.vmcx"
    }
catch { }

#check with the user if they want to delete the existing export and re-export or re-use what's there
$reuseExisting = $false
if($existingVmcx) {
    Write-Host -ForegroundColor Red "An export or VM already lives at '$exportPath'! If you choose to delete it, this script will re-export it; if you choose to re-use it, all files stay intact."
    $deleteOrReuse = Read-Host "Do you want to delete the existing export or reuse it? (D/R)"
    if($deleteOrReuse.ToUpper() -ne "D" -and $deleteOrReuse.ToUpper() -ne "R") {
        Write-Host -ForegroundColor Yellow "Invalid selection, script is existing to prevent accidental deletion or issues with existing export."
        exit
    }
    elseif($deleteOrReuse.ToUpper() -eq "D") {
        Write-Host -ForegroundColor Yellow "Removing existing export!"
        Remove-Item -Path "$exportPath\$cloneSource" -Recurse -Force
    }
    else {
        $reuseExisting = $true
    }
}

#set up storage paths for new VM
$diskPath = "$vmPath\$newVMName\Virtual Hard Disks"
$vmPath = "$vmPath\$newVMName"

Write-Host -ForegroundColor Cyan "Starting cloning process..."

#export VM if the user said not to reuse the existing one
if(!$reuseExisting) {
    Write-Host -ForegroundColor Cyan "--Exporting source VM..."

    $null = Export-VM -ComputerName $hvHost -Name $cloneSource -Path $exportPath
    }

#get the exported/existing vmcx file for import
$exportVmPath = "$exportPath\$cloneSource\Virtual Machines"
$exportVmxFile = Get-ChildItem -Path $exportVmPath -Filter "*.vmcx"

#import VM to previously set up vm and vhdx paths
if($reuseExisting) {
    Write-Host -ForegroundColor Cyan "--Importing VM from existing export, please wait as this may take a few minutes..."
    }
else {
    Write-Host -ForegroundColor Cyan "--Importing VM from new export, please wait as this may take a few minutes..."
}

$importedVM = Import-VM -ComputerName $hvHost -Path $exportVmxFile.FullName -Copy -GenerateNewId -VirtualMachinePath $vmPath -VhdDestinationPath $diskPath

Sleep -Seconds 5

#Imports do not rename the VM or the disks; we're going to do that now
Write-Host -ForegroundColor Cyan "--Import complete, renaming VM and its Virtual disks..."
$null = Rename-VM -VM $importedVM -NewName $newVMName

$importedVM = Get-VM $newVMName -ComputerName $hvHost

$vmDisks = $importedVM | Get-VMHardDiskDrive

foreach($disk in $vmDisks) {
    $newDiskShortName = "$($newVMName)_$($disk.ControllerNumber)_$($disk.ControllerLocation).vhdx"
    $newNameFullPath = "$diskPath\$newDiskShortName"
    $item = Rename-Item -Path $disk.Path -NewName "$newDiskShortName"
    $disk | Set-VMHardDiskDrive -Path $newNameFullPath
}


#when importing and choosing to generate new ID, it only changes the VM ID and not the BIOS Guid or Serial Numbers; force this to take place
#to prevent issues for any application or anything that tracks/uses serial numbers
Write-Host -ForegroundColor Cyan '--Resetting VM UUID and Serial Numbers'

$MSVM = gwmi -Namespace root\virtualization\v2 -Class msvm_computersystem -Filter "ElementName = '$newVMName'" -ComputerName $hvHost
 
# get current settings object
$MSVMSystemSettings = $null
foreach($SettingsObject in $MSVM.GetRelated('msvm_virtualsystemsettingdata'))
{
    $MSVMSystemSettings = [System.Management.ManagementObject]$SettingsObject
}
 
# assign a new bios guid
$biosGuid = "{$(([System.Guid]::NewGuid()).Guid.ToUpper())}"
$MSVMSystemSettings['BIOSGUID'] = $biosGuid

#hyper-v has a very specific way it wants serial numbers; generate a new random number quick that is 6x four-digit numbers with dashes between and ends in a two-digit number
$numbers= @()
(1..6) | Foreach { $numbers += (Get-Random -Minimum 1 -Maximum 9999).ToString().PadLeft(4,'0') }
$serial = $null
foreach($num in $numbers) {
    $serial += "$num-"
    }
$serial += (Get-Random -Minimum 1 -Maximum 99).ToString().PadLeft(2,'0')

#set all the serial numbers and tags -- these are all the same by default so setting them all the same here isn't an issue
$MSVMSystemSettings['BaseboardSerialNumber'] = $serial
$MSVMSystemSettings['ChassisAssetTag'] = $serial
$MSVMSystemSettings['ChassisSerialNumber'] = $serial
$MSVMSystemSettings['BIOSSerialNumber'] = $serial
 
$VMMS = gwmi -Namespace root\virtualization\v2 -Class msvm_virtualsystemmanagementservice -ComputerName $hvHost

# prepare and assign parameters
$ModifySystemSettingsParameters = $VMMS.GetMethodParameters('ModifySystemSettings')
$ModifySystemSettingsParameters['SystemSettings'] = $MSVMSystemSettings.GetText([System.Management.TextFormat]::CimDtd20)

# invoke modification
$wmiresult = $VMMS.InvokeMethod('ModifySystemSettings', $ModifySystemSettingsParameters, $null)

if($wmiresult.ReturnValue -ne 0) {
    Write-Host -ForegroundColor Red "!! Resetting UUID ($biosGuid) and/or Serial Number ($serial) failed; this will not stop VMs from working, but may casue issues with programs that report on serial number"
}

if($cluster) {
    Write-Host -ForegroundColor Cyan "--Adding VM to Cluster"
    $importedVM = Get-VM $newVMName -ComputerName $hvHost
    $null = Add-ClusterVirtualMachineRole -VMId $importedVM.VMId -Name $newVMName
}

Write-Host -ForegroundColor Green "Clone is complete!"

#clean up if the user wants to
$yesNo = Read-Host "Do you want to delete the export of your template? Your Template and New VM will remain untouched. (Y/N)"

if($yesNo.ToUpper() -eq "Y") {
    Write-Host -ForegroundColor Yellow "Removing export!"
    Remove-Item -Path "$exportPath\$cloneSource" -Recurse -Force
}