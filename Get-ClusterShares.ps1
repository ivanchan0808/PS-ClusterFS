# PowerShell Script to Gather Windows Cluster File Server Settings
# This script collects information about clustered file servers (both general and scale-out) 
# in a Windows Failover Cluster, including their shares and detailed settings.
# It must be run on a cluster node with administrative privileges.
# Modules required: FailoverClusters and SmbShare (usually available on Windows Server).
# Output is saved to a text file by default (ClusterSettings.txt in the script directory).

# Import necessary modules
Import-Module FailoverClusters -ErrorAction SilentlyContinue
Import-Module SmbShare -ErrorAction SilentlyContinue

# Define the default output file path (same directory as the script)
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "ClusterSettings.txt"

# Function to write to both console and file
function Write-Log {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Message
    )
    Write-Output $Message
    $Message | Out-File -FilePath $outputFile -Append -Encoding UTF8
}

# Check if required modules are loaded
if (-not (Get-Module -Name FailoverClusters, SmbShare)) {
    Write-Log "Required modules (FailoverClusters and/or SmbShare) are not available. Please ensure they are installed."
    exit
}

# Get the current cluster
try {
    Write-Log "Executing command: Get-Cluster"
    $cluster = Get-Cluster -ErrorAction Stop
    Write-Log "Cluster Name: $($cluster.Name)"
    Write-Log "Cluster Nodes: $((Get-ClusterNode | Select-Object -ExpandProperty Name) -join ', ')"
    Write-Log "-----------------------------------"
} catch {
    Write-Log "Unable to retrieve cluster information: $($_.Exception.ToString())"
    exit
}

# List all available SMB shares for debugging
try {
    Write-Log "Executing command: Get-SmbShare"
    $allShares = Get-SmbShare -ErrorAction Stop
    Write-Log "All Available SMB Shares on the System (Debug):"
    Write-Log "Number of All Shares Found: $($allShares.Count)"
    foreach ($share in $allShares) {
        Write-Log "  Share Name: $($share.Name), ScopeName: $($share.ScopeName), Path: $($share.Path)"
    }
    Write-Log "-----------------------------------"
} catch {
    Write-Log "Unable to retrieve all SMB shares: $($_.Exception.ToString())"
}

# Get all file server resources (including Scale-Out File Servers)
try {
    Write-Log "Executing command: Get-ClusterResource | Where-Object { \$_.ResourceType.Name -in @('File Server', 'Scale Out File Server') }"
    $fileServers = Get-ClusterResource | Where-Object { $_.ResourceType.Name -in @("File Server", "Scale Out File Server") }
    Write-Log "Number of File Server Resources Found: $($fileServers.Count)"
} catch {
    Write-Log "Unable to retrieve file server resources: $($_.Exception.ToString())"
    exit
}

if ($fileServers.Count -eq 0) {
    Write-Log "No clustered file server resources found."
} else {
    foreach ($fs in $fileServers) {
        # Clean the resource name by removing backslashes and extracting content within parentheses
        $cleanFsName = $fs.Name -replace '\\\\', ''
        if ($cleanFsName -match '\((.*?)\)') {
            $cleanFsName = $matches[1]  # Extract the content within parentheses, e.g., 'aska_share'
        }
        Write-Log "File Server Resource: $($fs.Name)"
        Write-Log "Cleaned Resource Name: $cleanFsName"
        Write-Log "Type: $($fs.ResourceType.Name)"
        Write-Log "State: $($fs.State)"
        Write-Log "Owner Group: $($fs.OwnerGroup.Name)"
        Write-Log "Owner Node: $($fs.OwnerNode.Name)"

        # Get resource parameters using the specified format
        try {
            Write-Log "Executing command: Get-ClusterResource -Name '$cleanFsName' | Get-ClusterParameter"
            $params = Get-ClusterResource -Name $cleanFsName -ErrorAction Stop | Get-ClusterParameter -ErrorAction Stop
            if ($params) {
                Write-Log "Parameters:"
                foreach ($param in $params) {
                    Write-Log "  $($param.Name): $($param.Value)"
                }
            } else {
                Write-Log "  No parameters found for this resource."
            }
        } catch {
            Write-Log "  Unable to retrieve parameters for resource '$cleanFsName': $($_.Exception.ToString())"
        }

        # Extract the virtual name (Client Access Point)
        $fsName = ($params | Where-Object { $_.Name -eq "Name" }).Value
        if (-not $fsName) {
            Write-Log "  Unable to retrieve Virtual Name (Scope). Using cleaned resource name as fallback: $cleanFsName"
            $fsName = $cleanFsName
        } else {
            Write-Log "Virtual Name (Scope): $fsName"
        }

        # Get dependent resources (e.g., disks or IPs)
        try {
            Write-Log "Executing command: Get-ClusterResourceDependency -Resource '$cleanFsName'"
            $dependencies = Get-ClusterResourceDependency -Resource $cleanFsName -ErrorAction Stop
            if ($dependencies -and $dependencies.DependencyExpression) {
                Write-Log "Dependencies:"
                # Parse dependency expression to extract resource names
                $depNames = $dependencies.DependencyExpression -replace '[()]', '' -split '[\[\]]' | Where-Object { $_ }
                foreach ($depName in $depNames) {
                    $depResource = Get-ClusterResource -Name $depName.Trim() -ErrorAction SilentlyContinue
                    if ($depResource) {
                        Write-Log "  $($depResource.Name) (Type: $($depResource.ResourceType.Name), State: $($depResource.State))"
                    } else {
                        Write-Log "  $depName (Unable to retrieve resource details)"
                    }
                }
            } else {
                Write-Log "  No dependencies found for this resource."
            }
        } catch {
            Write-Log "  Unable to retrieve dependencies: $($_.Exception.ToString())"
        }

        # Try unique ScopeName values, prioritizing 'aska_share'
        $scopeNames = @($fsName, $cluster.Name, $fs.OwnerGroup.Name, $fs.OwnerNode.Name) | Select-Object -Unique
        Write-Log "Attempting to retrieve SMB shares for ScopeNames: $($scopeNames -join ', ')"
        foreach ($scope in $scopeNames) {
            try {
                Write-Log "Executing command: Get-SmbShare -ScopeName '$scope'"
                $shares = Get-SmbShare -ScopeName $scope -ErrorAction Stop
                Write-Log "Number of Shares Found for Scope '$scope': $($shares.Count)"
                if ($shares) {
                    Write-Log "Shares for Scope '$scope':"
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
                                Write-Log "Executing command: Get-SmbShareAccess -Name '$($share.Name)' -ScopeName '$scope'"
                                $accessEntries = Get-SmbShareAccess -Name $share.Name -ScopeName $scope -ErrorAction Stop
                                if ($accessEntries) {
                                    Write-Log "    SMB Permissions:"
                                    foreach ($entry in $accessEntries) {
                                        Write-Log "      Account: $($entry.AccountName), Access Right: $($entry.AccessRight), Access Control Type: $($entry.AccessControlType)"
                                    }
                                } else {
                                    Write-Log "    No SMB permissions found or access error."
                                }
                            } catch {
                                Write-Log "    Unable to retrieve SMB share access for share '$($share.Name)' and scope '$scope': $($_.Exception.ToString())"
                            }
                        } catch {
                            $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error: $($_.Exception.ToString())" }
                            Write-Log "  Error processing share '$($share.Name)' for scope '$scope': $errorMessage"
                            continue
                        }
                    }
                } else {
                    Write-Log "No shares found for Scope '$scope'."
                }
            } catch {
                $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error: $($_.Exception.ToString())" }
                Write-Log "Unable to retrieve SMB shares for scope '$scope': $errorMessage"
            }
        }

        Write-Log "-----------------------------------"
    }
}