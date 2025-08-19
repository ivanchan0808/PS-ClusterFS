# PowerShell Script: Export NTFS Permissions for All SMB Shares
# Usage: .\Get-NTFSPermissions.ps1
# Optional: .\Get-NTFSPermissions.ps1 -ShareName "Share1","Share2"

param(
    [Parameter(Mandatory = $false)]
    [string[]]$ShareName,

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = ".\NTFS_Exports"
)

Write-Host "Enumerating SMB shares..." -ForegroundColor Cyan

try {
    # Ensure output folder exists
    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    # Get SMB shares (exclude default hidden shares like C$, ADMIN$)
    $shares = Get-SmbShare | Where-Object { $_.Name -notmatch "^\w+\$$" }

    if ($ShareName) {
        $shares = $shares | Where-Object { $ShareName -contains $_.Name }
    }

    if (-not $shares) {
        Write-Host "No SMB shares found matching criteria." -ForegroundColor Yellow
        exit
    }

    foreach ($share in $shares) {
        $rootPath   = $share.Path
        $exportFile = Join-Path $OutputFolder ("NTFSPermissions_{0}_{1}.txt" -f $share.Name, (Get-Date -Format "yyyyMMdd_HHmmss"))

        Write-Host "Exporting NTFS permissions for share [$($share.Name)] at path [$rootPath]" -ForegroundColor Green
        Write-Host "Output -> $exportFile"

        try {
            # Run icacls recursively on share path
            icacls $rootPath /T /C > $exportFile 2>&1
            Write-Host "Export completed for $($share.Name)." -ForegroundColor Cyan
        }
        catch {
            Write-Host "Error exporting permissions for $($share.Name): $_" -ForegroundColor Red
        }
    }

    Write-Host "`nAll exports completed. Files saved in: $OutputFolder" -ForegroundColor Cyan
}
catch {
    Write-Host "Fatal error: $_" -ForegroundColor Red
}
