# PowerShell Script: Export NTFS Permissions with icacls
# Usage: Get-NTFSPermissions.ps1 -RootFolder "R:\test"

param(
    [Parameter(Mandatory = $true)]
    [string]$RootFolder,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "NTFSPermissions_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
)

Write-Host "Exporting NTFS permissions from: $RootFolder"
Write-Host "Output will be saved to: $OutputFile"

try {
    # Run icacls recursively and export to file
    icacls $RootFolder /T /C > $OutputFile 2>&1

    Write-Host "Export completed successfully."
    Write-Host "Result file: $OutputFile"
}
catch {
    Write-Host "Error occurred: $_"
}
