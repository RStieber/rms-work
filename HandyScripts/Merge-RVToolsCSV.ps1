#This script requires the "ImportExcel" Powershell Module!
#If you do not have it, run "Install-Module ImportExcel" before running the script

Import-Module ImportExcel

$inputPath = (Read-Host "Enter path to RVTools CSV files").Trim("`"").TrimEnd("\")
$outputFileName = "rvTools_Merged.xlsx"

$csvFiles = Get-ChildItem -File -Filter "*.csv" -Path $inputPath

if(Test-Path "$inputPath\$outputFileName") {
    Rename-Item "$inputPath\$outputFileName" -NewName "$outputFileName.$((Get-Date).ToString("yyyyMMddHHmmss"))"
}

foreach($csv in $csvFiles) {
    Import-Csv $csv.FullName | Export-Excel -Path "$inputPath\$outputFileName" -WorksheetName ($csv.BaseName.Replace("RVTools_tab","")) -Append
}
