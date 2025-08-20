# Convert FileServer-Settings.txt (Get-SmbShare report) into New-SmbShare commands
# Usage: .\Convert-StandaloneShares.ps1 -InputFile "FileServer-Settings.txt" -OutputFile "create-standalone-share.ps1"

param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "create-standalone-share.ps1"
)

$lines = Get-Content $InputFile
$results = @()

$shareName = ""
$path = ""
$description = ""
$folderEnum = ""
$cachingMode = ""
$concurrentLimit = 0
$continuouslyAvailable = $false
$encryptData = $false
$permissions = @()

foreach ($line in $lines) {
    if ($line -match "Processing Share:\s+(.+)") {
        # Save previous share if exists
        if ($shareName -ne "") {
            $results += [pscustomobject]@{
                Name   = $shareName
                Path   = $path
                Desc   = $description
                Enum   = $folderEnum
                Cache  = $cachingMode
                Limit  = $concurrentLimit
                CA     = $continuouslyAvailable
                Encrypt= $encryptData
                Perms  = $permissions
            }
        }

        # Reset
        $shareName = $Matches[1].Trim()
        $path = ""
        $description = ""
        $folderEnum = ""
        $cachingMode = ""
        $concurrentLimit = 0
        $continuouslyAvailable = $false
        $encryptData = $false
        $permissions = @()
    }
    elseif ($line -match "Path:\s+(.+)") {
        $path = $Matches[1].Trim()
    }
    elseif ($line -match "Description:\s+(.+)") {
        $description = $Matches[1].Trim()
    }
    elseif ($line -match "Folder Enumeration Mode:\s+(.+)") {
        $folderEnum = $Matches[1].Trim()
    }
    elseif ($line -match "Caching Mode:\s+(.+)") {
        $cachingMode = $Matches[1].Trim()
    }
    elseif ($line -match "Concurrent User Limit:\s+(\d+)") {
        $concurrentLimit = [int]$Matches[1]
    }
    elseif ($line -match "Continuously Available:\s+(True|False)") {
        $continuouslyAvailable = [bool]::Parse($Matches[1])
    }
    elseif ($line -match "Encrypt Data:\s+(True|False)") {
        $encryptData = [bool]::Parse($Matches[1])
    }
    elseif ($line -match "Account:\s+(.+), Access Right:\s+(.+), Access Control Type:\s+(.+)") {
        $permissions += [pscustomobject]@{
            Account = $Matches[1].Trim()
            Right   = $Matches[2].Trim()
            Type    = $Matches[3].Trim()
        }
    }
}

# Save last share
if ($shareName -ne "") {
    $results += [pscustomobject]@{
        Name   = $shareName
        Path   = $path
        Desc   = $description
        Enum   = $folderEnum
        Cache  = $cachingMode
        Limit  = $concurrentLimit
        CA     = $continuouslyAvailable
        Encrypt= $encryptData
        Perms  = $permissions
    }
}

# Write output script
"### Auto-generated script to recreate standalone SMB shares ###" | Out-File $OutputFile

foreach ($s in $results) {
    # Skip default/system shares
    if ($s.Name -match '[$]$|^ADMIN\$|^IPC\$') { continue }

    $cmd = "New-SmbShare -Name `"$($s.Name)`" -Path `"$($s.Path)`" -FolderEnumerationMode $($s.Enum) -CachingMode $($s.Cache) -ConcurrentUserLimit $($s.Limit)"
    if ($s.Encrypt) { $cmd += " -EncryptData" }
    if ($s.CA) { $cmd += " -ContinuouslyAvailable" }
    if ($s.Desc) { $cmd += " -Description `"$($s.Desc)`"" }

    Add-Content -Path $OutputFile -Value $cmd

    foreach ($p in $s.Perms) {
        $permCmd = "Grant-SmbShareAccess -Name `"$($s.Name)`" -AccountName `"$($p.Account)`" -AccessRight $($p.Right) -Force"
        Add-Content -Path $OutputFile -Value $permCmd
    }

    Add-Content -Path $OutputFile -Value "`n"
}

Write-Host "? Conversion complete. Script saved to $OutputFile"
