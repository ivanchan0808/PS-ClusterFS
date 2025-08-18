# PowerShell Script to Gather Windows Cluster File Server Settings
# This script collects information about clustered file servers (both general and scale-out) 
# in a Windows Failover Cluster, including their shares and detailed settings.
# It must be run on a cluster node with administrative privileges.
# Modules required: FailoverClusters and SmbShare (usually available on Windows Server).

# Import necessary modules
Import-Module FailoverClusters -ErrorAction SilentlyContinue
Import-Module SmbShare -ErrorAction SilentlyContinue

# Check if required modules are loaded
if (-not (Get-Module -Name FailoverClusters, SmbShare)) {
    Write-Output "Required modules (FailoverClusters and/or SmbShare) are not available. Please ensure they are installed."
    exit
}

# Get the current cluster
$cluster = Get-Cluster -ErrorAction SilentlyContinue
if (-not $cluster) {
    Write-Output "Unable to retrieve cluster information. Ensure you are running this on a cluster node with appropriate permissions."
    exit
}
Write-Output "Cluster Name: $($cluster.Name)"
Write-Output "Cluster Nodes: $((Get-ClusterNode | Select-Object -ExpandProperty Name) -join ', ')"
Write-Output "-----------------------------------"

# Get all file server resources (including Scale-Out File Servers)
$fileServers = Get-ClusterResource | Where-Object { $_.ResourceType.Name -in @("File Server", "Scale Out File Server") }

if ($fileServers.Count -eq 0) {
    Write-Output "No clustered file server resources found."
} else {
    foreach ($fs in $fileServers) {
        # Clean the resource name by removing backslashes and extracting content within parentheses
        $cleanFsName = $fs.Name -replace '\\\\', ''
        if ($cleanFsName -match '\((.*?)\)') {
            $cleanFsName = $matches[1]  # Extract the content within parentheses, e.g., 'aska_share'
        }
        Write-Output "File Server Resource: $($fs.Name)"
        Write-Output "Cleaned Resource Name: $cleanFsName"
        Write-Output "Type: $($fs.ResourceType.Name)"
        Write-Output "State: $($fs.State)"
        Write-Output "Owner Group: $($fs.OwnerGroup.Name)"
        Write-Output "Owner Node: $($fs.OwnerNode.Name)"

        # Get resource parameters using the specified format
        try {
            $params = Get-ClusterResource -Name $cleanFsName -ErrorAction Stop | Get-ClusterParameter -ErrorAction Stop
            if ($params) {
                Write-Output "Parameters:"
                foreach ($param in $params) {
                    Write-Output "  $($param.Name): $($param.Value)"
                }
            } else {
                Write-Output "  No parameters found for this resource."
            }
        } catch {
            Write-Output "  Unable to retrieve parameters for resource '$cleanFsName': $($_.Exception.Message)"
        }

        # Extract the virtual name (Client Access Point)
        $fsName = ($params | Where-Object { $_.Name -eq "Name" }).Value
        if (-not $fsName) {
            Write-Output "  Unable to retrieve Virtual Name (Scope). Using cleaned resource name as fallback: $cleanFsName"
            $fsName = $cleanFsName
        } else {
            Write-Output "Virtual Name (Scope): $fsName"
        }

        # Get dependent resources (e.g., disks or IPs)
        try {
            $dependencies = Get-ClusterResourceDependency -Resource $cleanFsName -ErrorAction Stop
            if ($dependencies -and $dependencies.DependencyExpression) {
                Write-Output "Dependencies:"
                # Parse dependency expression to extract resource names
                $depNames = $dependencies.DependencyExpression -replace '[()]', '' -split '[\[\]]' | Where-Object { $_ }
                foreach ($depName in $depNames) {
                    $depResource = Get-ClusterResource -Name $depName.Trim() -ErrorAction SilentlyContinue
                    if ($depResource) {
                        Write-Output "  $($depResource.Name) (Type: $($depResource.ResourceType.Name), State: $($depResource.State))"
                    } else {
                        Write-Output "  $depName (Unable to retrieve resource details)"
                    }
                }
            } else {
                Write-Output "  No dependencies found for this resource."
            }
        } catch {
            Write-Output "  Unable to retrieve dependencies: $($_.Exception.Message)"
        }

        # Get SMB shares for this file server
        try {
            $shares = Get-SmbShare -ScopeName $fsName -ErrorAction Stop
            if ($shares) {
                Write-Output "Shares:"
                foreach ($share in $shares) {
                    Write-Output "  Share Name: $($share.Name)"
                    Write-Output "    Path: $($share.Path)"
                    Write-Output "    Description: $($share.Description)"
                    Write-Output "    Folder Enumeration Mode: $($share.FolderEnumerationMode)"
                    Write-Output "    Caching Mode: $($share.CachingMode)"
                    Write-Output "    Concurrent User Limit: $($share.ConcurrentUserLimit)"
                    Write-Output "    Continuously Available: $($share.ContinuouslyAvailable)"
                    Write-Output "    Encrypt Data: $($share.EncryptData)"
                    Write-Output "    Share State: $($share.ShareState)"
                    Write-Output "    Share Type: $($share.ShareType)"

                    # Get SMB share access permissions
                    $accessEntries = Get-SmbShareAccess -Name $share.Name -ScopeName $fsName -ErrorAction SilentlyContinue
                    if ($accessEntries) {
                        Write-Output "    SMB Permissions:"
                        foreach ($entry in $accessEntries) {
                            Write-Output "      Account: $($entry.AccountName), Access Right: $($entry.AccessRight), Access Control Type: $($entry.AccessControlType)"
                        }
                    } else {
                        Write-Output "    No SMB permissions found or access error."
                    }

                    # Attempt to get NTFS permissions on the share path (folder details)
                    try {
                        $acl = Get-Acl -Path $share.Path -ErrorAction Stop
                        Write-Output "    NTFS Permissions (Folder Details):"
                        foreach ($ace in $acl.Access) {
                            Write-Output "      Identity: $($ace.IdentityReference), Rights: $($ace.FileSystemRights), Type: $($ace.AccessControlType), Inherited: $($ace.IsInherited)"
                        }
                    } catch {
                        Write-Output "    Unable to access NTFS permissions for path '$($share.Path)'. Ensure the disk is online on this node."
                    }

                    Write-Output ""
                }
            } else {
                Write-Output "No shares found for this file server."
            }
        } catch {
            Write-Output "Unable to retrieve SMB shares for scope '$fsName': $($_.Exception.Message)"
        }

        Write-Output "-----------------------------------"
    }
}