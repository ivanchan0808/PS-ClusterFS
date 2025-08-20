# Convert ClusterSettings.txt (Get-SmbShare report) into cluster-aware New-SmbShare commands
# Usage: .\Convert-ClusterShares.ps1 -InputFile "ClusterSettings.txt" -OutputFile "RecreateClusterShares.ps1"

param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "RecreateClusterShares.ps1"
)

$lines   = Get-Content $InputFile
$results = @()

$scopeName = ""
$shareName = ""
$path = ""
$description = ""
$encryptData = $false
$continuouslyAvailable = $false
$permissions = @()

foreach ($line in $lines) {
    if ($line -match "Shares for Scope '(.+)'") {
        $scopeName = $Matches[1].Trim()
    }
    elseif ($line -match "Processing Share: (.+)") {
        # Save previous share if exists
        if ($shareName -ne "") {
            $results += [pscustomobject]@{
                Scope  = $scopeName
                Name   = $shareName
                Path   = $path
                Desc   = $description
                EncryptData = $encryptData
                CA     = $continuouslyAvailable
                Perms  = $permissions
            }
        }

        # Reset for new share
        $shareName = $Matches[1].Trim()
        $path = ""
        $description = ""
        $encryptData = $false
        $continuouslyAvailable = $false
        $permissions = @()
    }
    elseif ($line -match "Path:\s+(.+)") {
        $path = $Matches[1].Trim()
    }
    elseif ($line -match "Description:\s+(.+)") {
        $description = $Matches[1].Trim()
    }
    elseif ($line -match "Encrypt Data:\s+(True|False)") {
        $encryptData = [bool]::Parse($Matches[1])
    }
    elseif ($line -match "Continuously Available:\s+(True|False)") {
        $continuouslyAvailable = [bool]::Parse($Matches[1])
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
        Scope  = $scopeName
        Name   = $shareName
        Path   = $path
        Desc   = $description
        EncryptData = $encryptData
        CA     = $continuouslyAvailable
        Perms  = $permissions
    }
}

# Generate PowerShell commands
"### Auto-generated script to recreate cluster SMB shares ###" | Out-File $OutputFile

foreach ($s in $results) {
    # Skip system/hidden shares
    if ($s.Name -match '[$]$|ClusterStorage\$') { continue }

    $cmd = "New-SmbShare -Name `"$($s.Name)`" -Path `"$($s.Path)`" -ScopeName `"$($s.Scope)`""
    if ($s.Desc) { $cmd += " -Description `"$($s.Desc)`"" }
    if ($s.EncryptData) { $cmd += " -EncryptData" }
    if ($s.CA) { $cmd += " -ContinuouslyAvailable" }
    
    Add-Content -Path $OutputFile -Value $cmd

    foreach ($p in $s.Perms) {
        $permCmd = "Grant-SmbShareAccess -Name `"$($s.Name)`" -ScopeName `"$($s.Scope)`" -AccountName `"$($p.Account)`" -AccessRight $($p.Right) -Force"
        Add-Content -Path $OutputFile -Value $permCmd
    }

    Add-Content -Path $OutputFile -Value "`n"
}

Write-Host "Conversion complete. Script saved to $OutputFile"
