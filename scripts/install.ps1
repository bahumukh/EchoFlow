$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Installing Echoflow for Windows   " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Define variables
$Repo = "bahumukh/EchoFlow"
$ZipName = "Echoflow-Windows.zip"
$DownloadUrl = "https://github.com/$Repo/releases/latest/download/$ZipName"
$TempDir = Join-Path $env:TEMP "EchoflowInstall"
$ZipPath = Join-Path $TempDir $ZipName
$InstallDir = Join-Path $env:LOCALAPPDATA "Echoflow"

# Create temp directory
if (!(Test-Path -Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

Write-Host "Downloading latest release..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
} catch {
    Write-Host "Error: Failed to download Echoflow. Make sure a release exists at $DownloadUrl" -ForegroundColor Red
    exit 1
}

Write-Host "Installing Echoflow..."
try {
    # Clean up old install if exists
    if (Test-Path -Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Extract ZIP
    Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
    
    # Create Desktop Shortcut
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Echoflow.lnk")
    $Shortcut.TargetPath = "$InstallDir\Echoflow.exe"
    $Shortcut.WorkingDirectory = "$InstallDir"
    $Shortcut.Save()
} catch {
    Write-Host "Failed to install." -ForegroundColor Red
    exit 1
}

Write-Host "Cleaning up..."
Remove-Item -Path $TempDir -Recurse -Force

Write-Host "=====================================" -ForegroundColor Green
Write-Host "Echoflow installed successfully! 🎉" -ForegroundColor Green
Write-Host "A shortcut has been added to your Desktop." -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
