$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Installing Echoflow for Windows   " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Define variables
$Repo = "bahumukh/EchoFlow"
$ExeName = "Echoflow-Windows-Installer.exe"
$DownloadUrl = "https://github.com/$Repo/releases/latest/download/$ExeName"
$TempDir = Join-Path $env:TEMP "EchoflowInstall"
$ExePath = Join-Path $TempDir $ExeName

# Create temp directory
if (!(Test-Path -Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

Write-Host "Downloading latest release..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath
} catch {
    Write-Host "Error: Failed to download Echoflow. Make sure a release exists at $DownloadUrl" -ForegroundColor Red
    exit 1
}

Write-Host "Installing Echoflow..."
try {
    # Run installer silently. Assuming InnoSetup or NSIS
    Start-Process -FilePath $ExePath -ArgumentList "/S" -Wait -NoNewWindow
} catch {
    Write-Host "Failed to run the installer." -ForegroundColor Red
    exit 1
}

Write-Host "Cleaning up..."
Remove-Item -Path $TempDir -Recurse -Force

Write-Host "=====================================" -ForegroundColor Green
Write-Host "Echoflow installed successfully! 🎉" -ForegroundColor Green
Write-Host "You can find it in your Start Menu." -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
