# Define paths and URL components
$targetFolder = "C:\DispatchTracker"
$updateScript = Join-Path $targetFolder "update.ps1"
$driveFileID  = "1QHE-5AsrGIylvyQBuUPpiDDi92p5xUWG"

# Append a confirmation parameter to force download
$downloadURL = "https://drive.google.com/uc?export=download&confirm=t&id=$driveFileID"

# Ensure target directory exists
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

Write-Host "Downloading update script..."
Invoke-WebRequest -Uri $downloadURL -OutFile $updateScript -UseBasicParsing
Write-Host "Download complete: $updateScript"

# Verify the download to check if it's not an HTML page
$content = Get-Content -Raw -Path $updateScript
if ($content -match '<!DOCTYPE html>') {
    Write-Host "Warning: The downloaded file appears to be HTML. The download may have failed." -ForegroundColor Yellow
} else {
    Write-Host "The file appears to be valid."
    Write-Host "Executing update script..."
    & $updateScript
}

pause
