<#
.SYNOPSIS
    This script will create X number of VMs based on the inputs from the user, leveraging another script to properly clone VMs in Hyper-V

.DESCRIPTION
    Given inputs of server prefix, number of servers, and host name, create # of servers on the host with the naming scheme of <prefix>-#, using the "Clone-HyperVVM-cli.ps1" script

.PARAMETER ClonePrefix
    Required; Prefix for newly cloned VMs. Naming scheme will be <ClonePrefix>-#

.PARAMETER NumberOfServers
    Required; Number of clones to create

.PARAMETER ServerNumberStart
    Required; Number to start server creation at. Ese if VMs exist with <ClonePrefix>-# naming scheme, start at the next highest available number

.PARAMETER HyperVServerName
    Optional; Name of the Hyper-V server to clone the VM from/to. If left blank, it will default to the local server

.PARAMETER VmTemplateName
    Required; Name of the VM to be cloned

.PARAMETER TemplateOnCluster
    Optional Switch; Use of this this switch if the template is part of a Failover Cluster, the script will add the clone to the cluster after creation

.PARAMETER DeleteExport
    Optional Switch; Use of this switch will delete the VM Export used to import for the new VM

.EXAMPLE
    ./Create-MultipleVms.ps1 -ClonePrefix "HvServer" -Number 3 -VmTemplateName "zzServer2025" -DeleteExport

.NOTES
    RSAT for Hyper-V and possibly Failover Cluster Manager if the VM or template is in a cluster
    Clone-HyperVVm-cli.ps1 in the same directory as this script

#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$ClonePrefix,
    [Parameter(Mandatory=$true)]
    [int]$NumberOfServers,
    [Parameter()]
    [int]$ServerNumberStart = 1,
    [Parameter()]
    [string]$HyperVServerName = $null,
    [Parameter(Mandatory=$true)]
    [string]$VmTemplateName,
    [Parameter()]
    [switch]$TemplateOnCluster,
    [Parameter()]
    [switch]$DeleteExport
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$cloneScriptPath = "$PSScriptRoot\Clone-HyperVVm-cli.ps1"

for($i = 1; $i -le $NumberOfServers; $i++) {
    $cloneName = "$ClonePrefix-$ServerNumberStart"
    $ServerNumberStart++
    Write-Host -ForegroundColor Cyan "Creating server name '$cloneName' from template '$VmTemplateName'..."
    if($i -eq $numberOfServers -and $i -ne 1) {
        & $cloneScriptPath -VmTemplateName $VmTemplateName -HyperVServerName $HyperVServerName -TemplateOnCluster:$templateOnCluster -NewVmName $cloneName -DeleteExport:$DeleteExport -ReuseExistingExport
        }
    elseif ($i -eq 1) {
        & $cloneScriptPath -VmTemplateName $VmTemplateName -HyperVServerName $HyperVServerName -TemplateOnCluster:$templateOnCluster -NewVmName $cloneName
    }
    else {
        & $cloneScriptPath -VmTemplateName $VmTemplateName -HyperVServerName $HyperVServerName -TemplateOnCluster:$templateOnCluster -NewVmName $cloneName -ReuseExistingExport
    }
}

Write-Host -ForegroundColor Green "Creation of $NumberOfServers VMs complete!"