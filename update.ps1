# -----------------------------
# Main Update Script (UpdateAndRun.ps1)
# -----------------------------
Write-Host "Fetching the latest update from GitHub..."
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Define paths and URLs
$targetFolder = "C:\DispatchTracker"
$zipFile      = Join-Path $targetFolder "main.zip"
$vpnScript    = Join-Path $targetFolder "vpn.ps1"

$githubURL    = "https://github.com/Track1698/Extension-for-dispatchers/archive/refs/heads/main.zip"
$vpnURL       = "https://raw.githubusercontent.com/Track1698/scripts/main/vpn.ps1"

# Function to download a file
Function Download-File {
    param (
        [string]$url,
        [string]$output
    )
    Write-Host "Downloading from $url..."
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
    Write-Host "Download complete: $output"
}

# Ensure target directory exists
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

# Download the GitHub repo ZIP
Download-File -url $githubURL -output $zipFile

# Extract the ZIP file to the target folder
Write-Host "Extracting ZIP file..."
Expand-Archive -Path $zipFile -DestinationPath $targetFolder -Force
Write-Host "Extraction complete."

# Remove the ZIP file after extraction
Remove-Item -Path $zipFile
Write-Host "Removed ZIP file: $zipFile"

# Move files out of nested folder (e.g., "Extension-for-dispatchers-main") to target folder
$extractedFolder = Join-Path $targetFolder "Extension-for-dispatchers-main"
if (Test-Path $extractedFolder) {
    Get-ChildItem -Path $extractedFolder -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($extractedFolder.Length)
        $destination = Join-Path $targetFolder $relativePath
        if ($_.PSIsContainer) {
            if (-not (Test-Path $destination)) {
                New-Item -ItemType Directory -Path $destination | Out-Null
            }
        }
        else {
            Move-Item -Path $_.FullName -Destination $destination -Force
        }
    }
    Remove-Item -Path $extractedFolder -Recurse -Force
    Write-Host "Moved extracted files to $targetFolder and removed folder $extractedFolder."
}

# Download vpn.ps1 from GitHub
Download-File -url $vpnURL -output $vpnScript

# -----------------------------
# Device Type Detection Section
# -----------------------------

# Function: Determine device type using chassis info
function Get-ChassisTypeInfo {
    $enclosure = Get-WmiObject -Class Win32_SystemEnclosure -ErrorAction SilentlyContinue
    if ($enclosure -and $enclosure.ChassisTypes) {
        $types = $enclosure.ChassisTypes
        if ($types -contains 8 -or $types -contains 9 -or $types -contains 10 -or $types -contains 14) {
            return "Laptop"
        }
        elseif ($types -contains 3 -or $types -contains 4 -or $types -contains 5) {
            return "Desktop"
        }
        else {
            return "Unknown"
        }
    }
    else {
        return "Unknown"
    }
}

# Function: Determine device type using battery info
function Get-BatteryInfo {
    $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        return "Laptop"
    }
    else {
        return "Desktop"
    }
}

$chassisResult = Get-ChassisTypeInfo
$batteryResult = Get-BatteryInfo

Write-Host "Chassis type detection: $chassisResult"
Write-Host "Battery detection: $batteryResult"

if ($chassisResult -eq $batteryResult -and $chassisResult -ne "Unknown") {
    $deviceType = $chassisResult
    Write-Host "Device type determined as: $deviceType"
}
else {
    Write-Host "Conflicting device type information detected:"
    Write-Host "1) Chassis type suggests: $chassisResult"
    Write-Host "2) Battery presence suggests: $batteryResult"
    $choice = Read-Host "Please choose the correct device type (enter 'Laptop' or 'Desktop')"
    switch ($choice.ToLower()) {
        "laptop"  { $deviceType = "Laptop"; Write-Host "Device type set as: Laptop" }
        "desktop" { $deviceType = "Desktop"; Write-Host "Device type set as: Desktop" }
        default   { Write-Host "Invalid selection. Unable to determine device type."; exit }
    }
}

# Set VPN arguments based on the determined device type
$splat = @{
    DeviceType = $deviceType
    Arg1       = if ($deviceType -eq "Laptop") { 3 } else { 4 }
}
if ($deviceType -eq "Laptop") {
    $splat.Arg2 = "AUTO"
    Write-Host "Passing arguments for Laptop: $($splat.Arg1) and $($splat.Arg2)"
}
else {
    Write-Host "Passing argument for Desktop: $($splat.Arg1)"
}

# Execute vpn.ps1 with parameters using splatting
Write-Host "Executing vpn.ps1 with parameters..."
& $vpnScript @splat

pause
