# setup.ps1 - Windows PowerShell wrapper for FPGA toolchain setup
# Calls the Linux setup.sh script through WSL

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== FPGA Toolchain Setup for Windows ===" -ForegroundColor Green
Write-Host ""

# Check if WSL is available
Write-Host "Checking WSL availability..." -ForegroundColor Yellow
try {
    $wslCheck = wsl.exe --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: WSL is not installed or not running." -ForegroundColor Red
        Write-Host ""
        Write-Host "WSL is required to run the FPGA toolchain on Windows." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To install WSL:" -ForegroundColor Cyan
        Write-Host "  1. Open PowerShell as Administrator"
        Write-Host "  2. Run: wsl --install"
        Write-Host "  3. Restart your computer"
        Write-Host "  4. Run this setup script again"
        Write-Host ""
        exit 1
    }
    Write-Host "✓ WSL is available" -ForegroundColor Green
} catch {
    Write-Host "ERROR: WSL is not available." -ForegroundColor Red
    Write-Host "Install it with: wsl --install" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "This will install the FPGA toolchain inside WSL:" -ForegroundColor Yellow
Write-Host "  • Yosys (synthesis)"
Write-Host "  • nextpnr-xilinx (place & route)"
Write-Host "  • openFPGALoader (JTAG programmer)"
Write-Host "  • prjxray (bitstream generation)"
Write-Host "  • System dependencies"
Write-Host ""
Write-Host "This is a ONE-TIME setup that takes 10-15 minutes." -ForegroundColor Cyan
Write-Host ""

# Ask for confirmation
$confirmation = Read-Host "Continue with setup? (y/n)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting toolchain setup in WSL..." -ForegroundColor Green
Write-Host "(This may take several minutes. Please be patient...)" -ForegroundColor Yellow
Write-Host ""

# Convert Windows path to WSL path
function ConvertTo-WslPath {
    param([string]$WindowsPath)
    
    if ([string]::IsNullOrEmpty($WindowsPath)) {
        return ""
    }
    
    # If it's already a WSL path, return as-is
    if ($WindowsPath -match "^/") {
        return $WindowsPath
    }
    
    # Convert Windows path to WSL path
    $wslPath = wsl.exe wslpath -u "$WindowsPath" 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($wslPath)) {
        return $wslPath.Trim()
    }
    
    # Fallback: manual conversion
    $drive = $WindowsPath.Substring(0, 1).ToLower()
    $path = $WindowsPath.Substring(2).Replace('\', '/')
    return "/mnt/$drive$path"
}

# Convert script directory to WSL path
$WslScriptDir = ConvertTo-WslPath $ScriptDir

# Execute setup.sh in WSL
$wslCommand = "cd '$WslScriptDir' && bash ./setup.sh"
wsl.exe bash -c $wslCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Setup Complete! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now build FPGA projects." -ForegroundColor Cyan
    Write-Host "Use 'FPGA: Build Bitstream' command in VS Code." -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Setup failed. Check the error messages above." -ForegroundColor Red
    Write-Host ""
}

exit $LASTEXITCODE
