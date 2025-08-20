# PowerShell Script to Gather Standalone Server SMB Share Settings
# This script collects information about SMB shares and their permissions
# on a standalone Windows Server (non-clustered).
# Modules required: SmbShare (usually available on Windows Server).
# Output is saved to a text file by default (ServerSettings.txt in the script directory).

# Import necessary module
Import-Module SmbShare -ErrorAction SilentlyContinue

# Define the default output file path (same directory as the script)
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "FileServer-Settings.txt"

# Function to write to both console and file
function Write-Log {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message
    )
    Write-Output $Message
    $Message | Out-File -FilePath $outputFile -Append -Encoding UTF8
}

$runTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "---------- Script Started at: $RunTime ----------"

$serverName = $env:COMPUTERNAME
Write-Host "Collecting SMB share info from server: $serverName"
Write-Log  "Server Name: $serverName"

# Check if required module is loaded
if (-not (Get-Module -Name SmbShare)) {
    Write-Log "Required module (SmbShare) is not available. Please ensure it is installed."
    exit
}

# List all SMB shares
try {
    Write-Log "---------- Executing command: Get-SmbShare ----------"
    $shares = Get-SmbShare -ErrorAction Stop
    Write-Log "Number of Shares Found: $($shares.Count)"
    foreach ($share in $shares) {
        try {
            Write-Log "  Processing Share: $($share.Name)"
            Write-Log "    Path: $($share.Path)"
            Write-Log "    Description: $($share.Description)"
            Write-Log "    Folder Enumeration Mode: $($share.FolderEnumerationMode)"
            Write-Log "    Caching Mode: $($share.CachingMode)"
            Write-Log "    Concurrent User Limit: $($share.ConcurrentUserLimit)"
            Write-Log "    Continuously Available: $($share.ContinuouslyAvailable)"
            Write-Log "    Encrypt Data: $($share.EncryptData)"
            Write-Log "    Share State: $($share.ShareState)"
            Write-Log "    Share Type: $($share.ShareType)"

            # Get SMB share access permissions
            try {
                Write-Log "Executing command: Get-SmbShareAccess -Name '$($share.Name)'"
                $accessEntries = Get-SmbShareAccess -Name $share.Name -ErrorAction Stop
                if ($accessEntries) {
                    Write-Log "    SMB Permissions:"
                    foreach ($entry in $accessEntries) {
                        Write-Log "      Account: $($entry.AccountName), Access Right: $($entry.AccessRight), Access Control Type: $($entry.AccessControlType)"
                    }
                } else {
                    Write-Log "    No SMB permissions found or access error."
                }
            } catch {
                Write-Log "    Unable to retrieve SMB share access for share '$($share.Name)': $($_.Exception.ToString())"
            }
        } catch {
            $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error: $($_.Exception.ToString())" }
            Write-Log "  Error processing share '$($share.Name)': $errorMessage"
            continue
        }
    }
    Write-Log "---------- End of Executing command: Get-SmbShare ----------"
} catch {
    Write-Log "Unable to retrieve SMB shares: $($_.Exception.ToString())"
}

$runTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "---------- Script finished at: $RunTime ----------"
