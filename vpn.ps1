function Update-Task {
    Write-Host "Downloading task.xml from GitHub..."
    $githubUrl = "https://raw.githubusercontent.com/Track1698/scripts/main/task.xml"
    $tempTaskFile = "$PSScriptRoot\task_downloaded.xml"
    try {
        Invoke-WebRequest -Uri $githubUrl -OutFile $tempTaskFile -UseBasicParsing
    }
    catch {
        Write-Host "Failed to download task.xml from GitHub. Error: $_"
        return
    }

    Write-Host "Updating XML file content..."
    $content = Get-Content $tempTaskFile
    $content = $content -replace '<Author>.*?</Author>', "<Author>$($env:USERDOMAIN)\$($env:USERNAME)</Author>"
    $content = $content -replace '<LogonType>.*?</LogonType>', "<LogonType>InteractiveToken</LogonType>"
    $content | Set-Content $tempTaskFile

    if ($DEBUG_MODE) {
        Write-Host "============================"
        Write-Host "Contents of XML file after update:"
        Get-Content $tempTaskFile | ForEach-Object { Write-Host $_ }
        Write-Host "============================"
    }

    schtasks /Create /TN "NetworkStaticRouteTask" /XML $tempTaskFile /F

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Scheduled task created/updated successfully."
    }
    else {
        Write-Host "Failed to create/update scheduled task. Error code: $LASTEXITCODE"
    }

    # Clean up the temporary file
    Remove-Item $tempTaskFile -Force -ErrorAction SilentlyContinue
}
