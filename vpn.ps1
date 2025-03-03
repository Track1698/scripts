# -----------------------------
# VPN Script (vpn.ps1)
# -----------------------------
param(
    [string]$DeviceType,
    [int]$Arg1,
    [string]$Arg2
)

# Self-elevate if not running as administrator, forwarding parameters
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($PSBoundParameters.ContainsKey("DeviceType")) { $arguments += " -DeviceType $DeviceType" }
    if ($PSBoundParameters.ContainsKey("Arg1")) { $arguments += " -Arg1 $Arg1" }
    if ($PSBoundParameters.ContainsKey("Arg2") -and $Arg2) { $arguments += " -Arg2 $Arg2" }
    Start-Process powershell -Verb RunAs -ArgumentList $arguments -ErrorAction Stop
    exit
}

# Define your functions (unchanged)
$DEBUG_MODE = $true
$Gateway = "192.168.1.199"
$Mask = "255.255.255.255"
$NetworkIPList = "\\sAdmin\sr\Scripts\iplist.txt"
$DownloadedIPList = $false
$DownloadedFilePath = "$PSScriptRoot\iplist_downloaded.txt"

function Get-IPList {
    if (Test-Path $NetworkIPList) {
        Write-Host "Using IP list from network share: $NetworkIPList"
        return Get-Content $NetworkIPList | Where-Object { $_.Trim() -ne "" }
    }
    else {
        Write-Host "Network share not available. Attempting to download IP list from GitHub..."
        try {
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

function Cleanup-IPList {
    if ($DownloadedIPList -and (Test-Path $DownloadedFilePath)) {
        Remove-Item $DownloadedFilePath -Force -ErrorAction Stop
        Write-Host "Removed temporary downloaded IP list file."
        $global:DownloadedIPList = $false
    }
}

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

function Update-Routes {
    $ips = Get-IPList
    if ($ips.Count -eq 0) {
        Write-Host "No IP addresses found. Exiting route update."
        return
    }
    foreach ($ip in $ips) {
        Write-Host "Updating temporary route for $ip..."
        route delete $ip | Out-Null
        route add $ip mask $Mask $Gateway
    }
    Write-Host "Temporary routes updated successfully."
    Cleanup-IPList
}

function Update-PermanentRoutes {
    $ips = Get-IPList
    if ($ips.Count -eq 0) {
        Write-Host "No IP addresses found. Exiting permanent route update."
        return
    }
    foreach ($ip in $ips) {
        Write-Host "Updating permanent route for $ip..."
        route delete $ip | Out-Null
        route -p add $ip mask $Mask $Gateway
    }
    Write-Host "Permanent routes updated successfully."
    Cleanup-IPList
}

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

function Update-Task {
    Write-Host "Creating/updating scheduled task for network change auto adjustment..."
    $xmlFile = "C:\DispatchTracker\Extension-for-dispatchers-main\task.xml"
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

# -----------------------------
# Non-interactive mode: If parameters are provided, use them to decide the action.
# -----------------------------
if ($PSBoundParameters.ContainsKey("DeviceType") -and $PSBoundParameters.ContainsKey("Arg1")) {
    Write-Host "Running VPN script non-interactively with parameters:"
    Write-Host "DeviceType: $DeviceType, Arg1: $Arg1, Arg2: $Arg2"
    if ($PSBoundParameters.ContainsKey("Arg2") -and $Arg2 -eq "AUTO") {
        Auto-Mode
    }
    else {
        switch ($Arg1) {
            1 { Update-Routes }
            2 { Remove-Routes }
            3 { Update-Task }
            4 { Update-PermanentRoutes }
            default { Write-Host "Invalid argument provided. Exiting." }
        }
    }
    exit
}

# -----------------------------
# Interactive Mode (fallback)
# -----------------------------
Write-Host ""
Write-Host "What do you want to do?"
Write-Host "1) Update routes now (delete existing and add new temporary routes)"
Write-Host "2) Remove routes now"
Write-Host "3) Create/update scheduled task (auto adjust on network change)"
Write-Host "4) Update permanent routes (delete existing and add new permanent routes)"
Write-Host "AUTO) Auto mode based on current WiFi SSID"
$choice = Read-Host "Enter your choice (1,2,3,4 or AUTO)"
switch ($choice.ToUpper()) {
    "AUTO" { Auto-Mode }
    "1"    { Update-Routes }
    "2"    { Remove-Routes }
    "3"    { Update-Task }
    "4"    { Update-PermanentRoutes }
    default { Write-Host "Invalid selection. Exiting." }
}
