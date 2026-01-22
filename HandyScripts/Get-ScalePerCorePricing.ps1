#This script requires the "ImportExcel" Powershell Module!
#If you do not have it, run "Install-Module ImportExcel" before running the script

Import-Module ImportExcel

$ProductFamilies = @('Hypercore License and Support','Software License','Fleet Manager Software and License')

Write-Host -ForegroundColor Yellow "Please make sure that all column headers are unique and close the file before importing the price book!"
Write-Host -ForegroundColor Yellow "There tends to be two 'Product: Distributor Description' columns, this script will not work with those duplicated column names"

$excelFile = Import-Excel -Path ((Read-Host "Enter full path to the Scale Pricebook").Trim("`""))

$licensingLines = $excelFile | Where {$_.'Product: Product Family' -in $ProductFamilies}

$scalePricing = New-Object System.Collections.ArrayList

foreach($line in $licensingLines) {
    if($line.'Product: Product Code' -match "HCOS-\w{1}-\d{1}-\d{1,2}C*") {
        $prodCode = $line.'Product: Product Code'
        $licenseYears = $prodCode.TrimStart("HCOS-V-").TrimStart("HCOS-L-").TrimStart("HCOS-S-")
        $licenseYears = [int]($licenseYears.Substring(0,1))
        $licenseCores = [int]($prodCode.Substring($prodCode.LastIndexOf("C")-2).TrimStart("-").TrimEnd("-PS").TrimEnd("-SS").TrimEnd("C"))

        $pricePerCore = ([Math]::Round(($line.'List Price'/$licenseCores/$licenseYears),2))

        $null = $scalePricing.Add((New-Object PSObject -Property @{'ProductCode' = $prodCode; 'ProductName' = $line.'Product: Product Name'; 'ProductDescription' = $line.'Product: Product Description'; 'ListPrice' = $line.'List Price'.ToString("C2"); 'PricePerCore' = "`$$($pricePerCore.ToString("N2"))"}))
    }
    else {
        $null = $scalePricing.Add((New-Object PSObject -Property @{'ProductCode' = $prodCode; 'ProductName' = $line.'Product: Product Name'; 'ProductDescription' = $line.'Product: Product Description'; 'ListPrice' = $line.'List Price'.ToString("C2"); 'PricePerCore' = "N/A"}))
    }
}

$exportPath = (Read-Host "Enter Scale pricing export full path").Trim("`"")

Write-Host -ForegroundColor Cyan "File being exported to '$exportPath\Scale_Pricing_Simplified.xlsx'"
$scalePricing | Select ProductCode,ProductName,ListPrice,PricePerCore,ProductDescription | Export-Excel -Path "$exportPath\Scale_Pricing_Simplified.xlsx"