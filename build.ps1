# build.ps1 - Windows PowerShell wrapper for FPGA build
# Calls the Linux build.sh script through WSL

param(
    [string]$SourceDir = "",
    [string]$Top = "",
    [string]$Constraints = "",
    [string]$Project = "",
    [switch]$Flash,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if WSL is available
try {
    $wslCheck = wsl.exe --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: WSL is not installed or not running." -ForegroundColor Red
        Write-Host ""
        Write-Host "To install WSL:" -ForegroundColor Yellow
        Write-Host "  1. Open PowerShell as Administrator"
        Write-Host "  2. Run: wsl --install"
        Write-Host "  3. Restart your computer"
        Write-Host ""
        exit 1
    }
} catch {
    Write-Host "ERROR: WSL is not available." -ForegroundColor Red
    Write-Host "Install it with: wsl --install" -ForegroundColor Yellow
    exit 1
}

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

# Build arguments for build.sh
$buildArgs = @()

if ($Help) {
    $buildArgs += "--help"
} else {
    if ($SourceDir) {
        $buildArgs += "--source-dir"
        $buildArgs += ConvertTo-WslPath $SourceDir
    }
    if ($Top) {
        $buildArgs += "--top"
        $buildArgs += $Top
    }
    if ($Constraints) {
        $buildArgs += "--constraints"
        $buildArgs += ConvertTo-WslPath $Constraints
    }
    if ($Project) {
        $buildArgs += "--project"
        $buildArgs += $Project
    }
    if ($Flash) {
        $buildArgs += "--flash"
    }
}

# Execute build.sh in WSL
Write-Host "Running FPGA build through WSL..." -ForegroundColor Cyan

$wslCommand = "cd '$WslScriptDir' && bash ./build.sh $($buildArgs -join ' ')"
wsl.exe bash -c $wslCommand

exit $LASTEXITCODE
