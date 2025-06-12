<#
.SYNOPSIS
    This script will reset all the needed ID's for a Hyper-V VM that has been cloned via export/import

.DESCRIPTION
    This script will change the VM BIOS GUID and Serial Number in the required places, allowing for truly unique VM GUIDs after an export/import type clone has been done

.EXAMPLE
    ./Set-VMBiosGuidAndSerialNumber.ps1

.NOTES
    This script will need to be run on the host that the VM in question currently resides on
#>

$VMName = Read-Host "Enter VM Name to reset identifiers for"
$MSVM = gwmi -Namespace root\virtualization\v2 -Class msvm_computersystem -Filter "ElementName = '$VMName'"
 
# get current settings object
$MSVMSystemSettings = $null
foreach($SettingsObject in $MSVM.GetRelated('msvm_virtualsystemsettingdata'))
{
    $MSVMSystemSettings = [System.Management.ManagementObject]$SettingsObject
}
 
# assign a new id
$MSVMSystemSettings['BIOSGUID'] = "{$(([System.Guid]::NewGuid()).Guid.ToUpper())}"
$numbers= @()
(1..6) | Foreach { $numbers += (Get-Random -Minimum 1 -Maximum 9999).ToString().PadLeft(4,'0') }
$serial = $null
foreach($num in $numbers) {
    $serial += "$num-"
    }
$serial += (Get-Random -Minimum 1 -Maximum 99).ToString().PadLeft(2,'0')
$MSVMSystemSettings['BaseboardSerialNumber'] = $serial
$MSVMSystemSettings['ChassisAssetTag'] = $serial
$MSVMSystemSettings['ChassisSerialNumber'] = $serial
$MSVMSystemSettings['BIOSSerialNumber'] = $serial

 
$VMMS = gwmi -Namespace root\virtualization\v2 -Class msvm_virtualsystemmanagementservice
# prepare and assign parameters
$ModifySystemSettingsParameters = $VMMS.GetMethodParameters('ModifySystemSettings')
$ModifySystemSettingsParameters['SystemSettings'] = $MSVMSystemSettings.GetText([System.Management.TextFormat]::CimDtd20)
# invoke modification
$VMMS.InvokeMethod('ModifySystemSettings', $ModifySystemSettingsParameters, $null)