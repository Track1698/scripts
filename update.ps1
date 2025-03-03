# -----------------------------
# Main Update Script (UpdateAndRun.ps1)
# -----------------------------

Write-Host "Fetching the latest update from GitHub..."
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Define paths
$targetFolder = "C:\DispatchTracker"
$zipFile      = Join-Path $targetFolder "main.zip"
$vpnScript    = Join-Path $targetFolder "vpn.ps1"

# GitHub repo ZIP URL
$githubURL    = "https://github.com/Track1698/Extension-for-dispatchers/archive/refs/heads/main.zip"

# Google Drive direct download URL for vpn.ps1
$vpnURL = "https://drive.google.com/uc?export=download&id=1HBYc3fkYmN2HCZBkwY7vkLwaCmNwtMgK"

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
Write-Host "Fetching GitHub updates complete."

# Download vpn.ps1 from Google Drive
Download-File -url $vpnURL -output $vpnScript

# Execute the downloaded vpn.ps1 script
Write-Host "Executing vpn.ps1..."
& $vpnScript

Write-Host "Update and VPN script execution complete."

# -----------------------------
# VPN Script (vpn.ps1)
# -----------------------------
# Self-elevate if not running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

Write-Host "Running VPN script with administrator privileges..."

# Function to determine type based on chassis type
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

# Function to determine type based on battery presence
function Get-BatteryInfo {
    $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        return "Laptop"
    }
    else {
        return "Desktop"
    }
}

# Get results from both methods
$chassisResult = Get-ChassisTypeInfo
$batteryResult = Get-BatteryInfo

Write-Host "Chassis type detection: $chassisResult"
Write-Host "Battery detection: $batteryResult"

# Determine device type
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

# Pass arguments based on the determined device type
switch ($deviceType) {
    "Laptop" {
        $arg1 = 3
        $arg2 = "AUTO"
        Write-Host "Passing arguments for Laptop: $arg1 and $arg2"
        # For example, call your VPN connection function or external process:
        # Invoke-VPN -Param1 $arg1 -Param2 $arg2
    }
    "Desktop" {
        $arg1 = 4
        Write-Host "Passing argument for Desktop: $arg1"
        # For example, call your VPN connection function or external process:
        # Invoke-VPN -Param1 $arg1
    }
    default {
        Write-Host "Device type not recognized. No arguments will be passed."
    }
}

pause
