# PowerShell Script: Generate Test Folder Structure
# Usage: Generate-TestFolders.ps1 -RootPath "R:\"

param(
    [string]$RootPath = "C:\TestFolders"
)

# Ensure root path exists
if (-not (Test-Path $RootPath)) {
    New-Item -Path $RootPath -ItemType Directory | Out-Null
}

Write-Host "Creating test folder structure under: $RootPath"

# Create 10 top-level folders
for ($i = 1; $i -le 10; $i++) {
    $topFolder = Join-Path $RootPath ("Folder_{0:D2}" -f $i)
    New-Item -Path $topFolder -ItemType Directory -Force | Out-Null

    $currentFolder = $topFolder

    # Create 20 levels of nested subfolders
    for ($depth = 1; $depth -le 20; $depth++) {
        $subFolder = Join-Path $currentFolder ("Sub_{0:D2}" -f $depth)
        New-Item -Path $subFolder -ItemType Directory -Force | Out-Null

        # Create 25 text files in each folder
        for ($file = 1; $file -le 25; $file++) {
            $filePath = Join-Path $subFolder ("File_{0:D2}.txt" -f $file)
            Set-Content -Path $filePath -Value "This is test file $file in $subFolder"
        }

        # Move one level deeper
        $currentFolder = $subFolder
    }
}

Write-Host "Folder structure created successfully!"
