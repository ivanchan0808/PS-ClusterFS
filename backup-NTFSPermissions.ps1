# PowerShell Script: Export NTFS Permissions with icacls
# Usage: Get-NTFSPermissions.ps1 -RootFolder "R:\test"

param(
    [Parameter(Mandatory = $true)]
    [string]$RootFolder,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "Backup_NTFSPermissions_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
)

Write-Host "Exporting NTFS permissions from: $RootFolder"
Write-Host "Output will be saved to: $OutputFile"

try {
    # Run icacls recursively and export to file
    # /T Performs the operation on all specified files in the current directory and its subdirectories.
    # /C Continues the operation even if file errors occur. Error messages are still shown.
    icacls $RootFolder /save $OutputFile /T /C 

    Write-Host "Export completed successfully."
    Write-Host "Result file: $OutputFile"
}
catch {
    Write-Host "Error occurred: $_"
}
