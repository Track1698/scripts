# Define paths and URL components
$targetFolder = "C:\DispatchTracker"
$updateScript = Join-Path $targetFolder "update.ps1"
$downloadURL = "https://raw.githubusercontent.com/Track1698/scripts/main/update.ps1"

# Ensure target directory exists
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

Write-Host "Downloading update script..."
Invoke-WebRequest -Uri $downloadURL -OutFile $updateScript -UseBasicParsing
Write-Host "Download complete: $updateScript"

Write-Host "Executing update script..."
& $updateScript

Write-Host "Update script executed. Removing the update file..."
Remove-Item -Path $updateScript

pause
