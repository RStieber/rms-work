Function Get-HyperVInfo {
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param(
	[string]$OutputPath
	)

	Get-VM | ForEach-Object {
		$vhd = Get-VHD -ComputerName $_.ComputerName -VmId $_.VmId
		$networkAdapter = Get-VMNetworkAdapter -VM $_

		$vhd | Add-Member -NotePropertyName "Name" -NotePropertyValue $_.Name
		$vhd | Add-Member -NotePropertyName "State" -NotePropertyValue $_.State
		$vhd | Add-Member -NotePropertyName "ProcessorCount" -NotePropertyValue $_.ProcessorCount
		$vhd | Add-Member -NotePropertyName "MemoryStartup" -NotePropertyValue $_.MemoryStartup
		$vhd | Add-Member -NotePropertyName "NetworkAdapters" -NotePropertyValue $networkAdapter.IPAddresses
		$vhd | Add-Member -NotePropertyName "AccessVlanId" -NotePropertyValue ($networkAdapter | Get-VMNetworkAdapterVlan).AccessVlanId
		$vhd
		} | Select-Object @{label='VM Name';expression={$_.Name}}, @{label='VM State';expression={$_.State}}, `
	@{label='vCPU';expression={$_.ProcessorCount}}, `
	@{label='vMem (GB)';expression={$_.MemoryStartup/1gb -as [int]}}, `
	@{label='IP Addresses';expression={$_.NetworkAdapters}}, @{label='Host Name';expression={$_.ComputerName}}, `
	@{label='VLAN Id';expression={$_.AccessVlanId}}, Path, VhdFormat, VhdType, `
	@{label='Size On Physical Disk (GB)';expression={$_.FileSize/1gb -as [int]}}, `
	@{label='Max Disk Size (GB)';expression={$_.Size/1gb -as [int]}}, `
	@{label='Remaining Space (GB)';expression={($_.Size/1gb - $_.FileSize/1gb) -as [int]}}, `
	@{label='Disk Identifier';expression={$_.DiskIdentifier}} `
	| Export-Csv -Path $outputPath -NoTypeInformation -Force

	}

$outPath = Read-Host "Please enter Full output path (.csv extension)"

Get-HyperVInfo -OutputPath $outPath.Trim("`"")