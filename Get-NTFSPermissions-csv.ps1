# PowerShell Script: Export NTFS Permissions with icacls to CSV (streaming mode)
# Usage: .\Get-NTFSPermissions.ps1 -RootFolder "C:\Windows"

param(
    [Parameter(Mandatory = $true)]
    [string]$RootFolder,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "NTFSPermissions_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Write-Host "Exporting NTFS permissions from: $RootFolder"
Write-Host "Output will be saved to: $OutputFile"

try {
    # Create CSV header first
    "Path,Identity,Rights" | Out-File -FilePath $OutputFile -Encoding UTF8

    # Run icacls recursively and capture output as strings
    $icaclsOutput = icacls $RootFolder /T /C 2>&1 | ForEach-Object { $_.ToString() }

    $currentPath = ""
    foreach ($line in $icaclsOutput) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match "^[A-Z]:\\") {
            # First line: path and maybe inline permissions
            $tokens = $line.Trim() -split "\s+", 2
            $currentPath = $tokens[0]

            if ($tokens.Count -gt 1) {
                $permLine = $tokens[1]
                if ($permLine -match "(.+?):(.+)") {
                    "$currentPath,""$($matches[1].Trim())"",""$($matches[2].Trim())""" |
                        Out-File -FilePath $OutputFile -Encoding UTF8 -Append
                }
            }
        }
        else {
            # Indented permission line (path continues from last one)
            if ($line -match "(.+?):(.+)") {
                "$currentPath,""$($matches[1].Trim())"",""$($matches[2].Trim())""" |
                    Out-File -FilePath $OutputFile -Encoding UTF8 -Append
            }
        }
    }

    Write-Host "Export completed successfully."
    Write-Host "Result file: $OutputFile"

    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "Script finished at: $endTime"
}
catch {
    Write-Host "Error occurred: $_"
    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "Script exited with error at: $endTime"
}
