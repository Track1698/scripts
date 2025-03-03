# Self-elevate if not running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Re-launch the script with administrator privileges
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
    exit
}
# vpn.ps1

# Set debug mode if needed.
$DEBUG_MODE = $true

# Global variables
$Gateway = "192.168.1.199"
$Mask = "255.255.255.255"
$NetworkIPList = "\\sAdmin\sr\Scripts\iplist.txt"
$DownloadedIPList = $false
$DownloadedFilePath = "$PSScriptRoot\iplist_downloaded.txt"

# Function to retrieve the list of IP addresses
function Get-IPList {
    if (Test-Path $NetworkIPList) {
        Write-Host "Using IP list from network share: $NetworkIPList"
        return Get-Content $NetworkIPList | Where-Object { $_.Trim() -ne "" }
    }
    else {
        Write-Host "Network share not available. Attempting to download IP list from GitHub..."
        try {
            # Use the GitHub raw URL for iplist.txt
            $url = "https://raw.githubusercontent.com/Track1698/scripts/main/iplist.txt"
            Invoke-WebRequest -Uri $url -OutFile $DownloadedFilePath -UseBasicParsing
            $global:DownloadedIPList = $true
            Write-Host "Downloaded IP list to: $DownloadedFilePath"
            return Get-Content $DownloadedFilePath | Where-Object { $_.Trim() -ne "" }
        }
        catch {
            Write-Host "Failed to download iplist.txt from GitHub. Error: $_"
            return @()
        }
    }
}

# Function to clean up the downloaded IP list if applicable
function Cleanup-IPList {
    if ($DownloadedIPList -and (Test-Path $DownloadedFilePath)) {
        if (Test-Path $DownloadedFilePath) {
            Remove-Item $DownloadedFilePath -Force -ErrorAction Stop
        } else {
            Write-Host "File not found: $DownloadedFilePath"
        }
        Write-Host "Removed temporary downloaded IP list file."
        $global:DownloadedIPList = $false
    }
}

# Function to add routes (temporary or permanent)
function Add-Routes {
    param(
        [switch]$Permanent
    )
    $ips = Get-IPList
    if ($ips.Count -eq 0) {
        Write-Host "No IP addresses found. Exiting route addition."
        return
    }
    foreach ($ip in $ips) {
        if ($Permanent) {
            route -p add $ip mask $Mask $Gateway
        }
        else {
            route add $ip mask $Mask $Gateway
        }
    }
    if ($Permanent) {
        Write-Host "Permanent routes added successfully."
    }
    else {
        Write-Host "Routes added successfully."
    }
    Cleanup-IPList
}

# Function to remove routes based on iplist.txt
function Remove-Routes {
    $ips = Get-IPList
    if ($ips.Count -eq 0) {
        Write-Host "No IP addresses found. Exiting route removal."
        return
    }
    foreach ($ip in $ips) {
        route delete $ip
    }
    Write-Host "Routes removed successfully."
    Cleanup-IPList
}

# Function to update routes (delete then add new temporary routes)
function Update-Routes {
    $ips = Get-IPList
    if ($ips.Count -eq 0) {
        Write-Host "No IP addresses found. Exiting route update."
        return
    }
    foreach ($ip in $ips) {
        Write-Host "Updating temporary route for $ip..."
        # Delete existing route (if it exists)
        route delete $ip | Out-Null
        # Add the new temporary route
        route add $ip mask $Mask $Gateway
    }
    Write-Host "Temporary routes updated successfully."
    Cleanup-IPList
}

# New function: Update permanent routes by first deleting then adding new permanent routes.
function Update-PermanentRoutes {
    $ips = Get-IPList
    if ($ips.Count -eq 0) {
        Write-Host "No IP addresses found. Exiting permanent route update."
        return
    }
    foreach ($ip in $ips) {
        Write-Host "Updating permanent route for $ip..."
        # Delete existing route (if it exists)
        route delete $ip | Out-Null
        # Add the new permanent route
        route -p add $ip mask $Mask $Gateway
    }
    Write-Host "Permanent routes updated successfully."
    Cleanup-IPList
}

# Function to check WiFi SSID and choose routes
function Auto-Mode {
    Write-Host "Auto mode: checking current WiFi SSID..."
    $netshOutput = netsh wlan show interfaces
    $match = $netshOutput | Select-String -Pattern "SSID\s+:\s+(.*)$"
    if ($match) {
        $ssid = $match.Matches[0].Groups[1].Value.Trim()
    }
    else {
        Write-Host "Could not determine SSID."
        return
    }
    Write-Host "Current SSID is: $ssid"
    if ($ssid -eq "5G") {
        Write-Host "SSID is 5G, adding routes..."
        Add-Routes
    }
    else {
        Write-Host "SSID is not 5G, removing routes..."
        Remove-Routes
    }
}

# Function to update the XML and create/update the scheduled task
function Update-Task {
    Write-Host "Creating/updating scheduled task for network change auto adjustment..."
    $xmlFile = "C:\DispatchTracker\Extension-for-dispatchers-main\task.xml"
    
    # Read and update the XML file:
    # 1. Update the <Author> element with the current user.
    # 2. Change the <LogonType> to InteractiveToken so no password is required.
    $content = Get-Content $xmlFile
    $content = $content -replace '<Author>.*?</Author>', "<Author>$($env:USERDOMAIN)\$($env:USERNAME)</Author>"
    $content = $content -replace '<LogonType>.*?</LogonType>', "<LogonType>InteractiveToken</LogonType>"
    $content | Set-Content $xmlFile

    if ($DEBUG_MODE) {
        Write-Host "============================"
        Write-Host "Contents of XML file after update:"
        Get-Content $xmlFile | ForEach-Object { Write-Host $_ }
        Write-Host "============================"
    }

    schtasks /Create /TN "NetworkStaticRouteTask" /XML $xmlFile /F

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Scheduled task created/updated successfully."
    }
    else {
        Write-Host "Failed to create/update scheduled task. Error code: $LASTEXITCODE"
    }
}

# Main menu / argument processing
if ($args.Count -gt 0) {
    foreach ($choice in $args) {
        switch ($choice.ToUpper()) {
            "AUTO" { Auto-Mode }
            "1"    { Update-Routes }
            "2"    { Remove-Routes }
            "3"    { Update-Task }
            "4"    { Update-PermanentRoutes }
            "5"    { Add-AlternateDNS }
            default { Write-Host "Invalid selection: $choice" }
        }
    }
}
else {
    Write-Host ""
    Write-Host "What do you want to do?"
    Write-Host "1) Update routes now (delete existing and add new temporary routes)"
    Write-Host "2) Remove routes now"
    Write-Host "3) Create/update scheduled task (auto adjust on network change)"
    Write-Host "4) Update permanent routes (delete existing and add new permanent routes)"
    Write-Host "5) Set alternate DNS server (active connection)"
    $choice = Read-Host "Enter 1, 2, 3, 4, or 5"
    switch ($choice.ToUpper()) {
        "AUTO" { Auto-Mode }
        "1"    { Update-Routes }
        "2"    { Remove-Routes }
        "3"    { Update-Task }
        "4"    { Update-PermanentRoutes }
        "5"    { Add-AlternateDNS }
        default { Write-Host "Invalid selection. Exiting." }
    }
}


switch ($choice.ToUpper()) {
    "AUTO" { Auto-Mode }
    "1"    { Update-Routes }
    "2"    { Remove-Routes }
    "3"    { Update-Task }
    "4"    { Update-PermanentRoutes }
    "5"    { Add-AlternateDNS }
    default { Write-Host "Invalid selection. Exiting." }
}
