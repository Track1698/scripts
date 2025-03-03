# Self-elevate if not running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Re-launch the script with administrator privileges
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Set execution policy for the current process to bypass restrictions
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Setting up executor..."

# Define paths
$targetFolder  = "C:\DispatchTracker"
$executorPath  = Join-Path $targetFolder "executor.ps1"
$sourcePath    = "\\ADMIN\sr\Scripts\executor.ps1"

# Ensure target directory exists
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

# Copy executor.ps1 from network share to local directory
if (Test-Path $sourcePath) {
    Copy-Item -Path $sourcePath -Destination $executorPath -Force
    Write-Host "Executor copied to: $executorPath"
} else {
    Write-Host "Source executor.ps1 not found at $sourcePath"
    exit
}

# Create a shortcut on the Desktop
$WshShell    = New-Object -ComObject WScript.Shell
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath "Update.lnk"
$shortcut    = $WshShell.CreateShortcut($shortcutPath)

$shortcut.TargetPath = "powershell.exe"

# Set the arguments to launch executor.ps1 with elevated privileges via the shortcut
$shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -File \"C:\DispatchTracker\executor.ps1\"'' -Verb RunAs"'

$shortcut.IconLocation = "powershell.exe,0"
$shortcut.Save()

Write-Host "Shortcut created at: $shortcutPath"

pause
