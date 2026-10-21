# =============================================================================
# 👑 Lipi Programming Language — Windows PowerShell Sovereign Installer
# GitHub: https://github.com/asaudola-cmyk/LiPi_Lang
# Usage:  irm https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.ps1 | iex
# =============================================================================

[CmdletBinding()]
param (
    [string]$InstallDir = "$HOME\.lipi",
    [string]$BinDir = "$HOME\.local\bin",
    [switch]$Update
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ██╗     ██╗██████╗ ██╗" -ForegroundColor Cyan
Write-Host "  ██║     ██║██╔══██╗██║" -ForegroundColor Cyan
Write-Host "  ██║     ██║██████╔╝██║" -ForegroundColor Cyan
Write-Host "  ██║     ██║██╔═══╝ ██║" -ForegroundColor Cyan
Write-Host "  ███████╗██║██║     ██║" -ForegroundColor Cyan
Write-Host "  ╚══════╝╚═╝╚═╝     ╚═╝" -ForegroundColor Cyan
Write-Host "  Lipi Programming Language — First 1.0.0 (Windows Sovereign Setup)" -ForegroundColor Yellow
Write-Host "  Autonomous Bilingual Systems Programming Language (0% C, 0% Libc, 0% LLVM)`n"

# 1. Verify Architecture
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
Write-Host "  ✔ Detected Windows Architecture: $arch" -ForegroundColor Green

# 2. Check Git or Download Repository
$repoUrl = "https://github.com/asaudola-cmyk/LiPi_Lang.git"
$zipUrl = "https://github.com/asaudola-cmyk/LiPi_Lang/archive/refs/heads/main.zip"

if (Test-Path "$PSScriptRoot\src\compiler\driver_cli.lp") {
    $InstallDir = $PSScriptRoot
    Write-Host "  ✔ Using local LiPi repository: $InstallDir" -ForegroundColor Green
} elseif (Test-Path "$InstallDir\.git") {
    Write-Host "  → Updating existing installation in $InstallDir..." -ForegroundColor Cyan
    git -C "$InstallDir" pull --quiet
} else {
    Write-Host "  → Installing LiPi into $InstallDir..." -ForegroundColor Cyan
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git clone --quiet --depth=1 "$repoUrl" "$InstallDir"
    } else {
        Write-Host "  → git not found, downloading repository zip..." -ForegroundColor Cyan
        $zipFile = "$env:TEMP\lipi_repo.zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
        Expand-Archive -Path $zipFile -DestinationPath "$env:TEMP\lipi_extracted" -Force
        if (!(Test-Path "$InstallDir")) { New-Item -ItemType Directory -Path "$InstallDir" -Force | Out-Null }
        Copy-Item -Path "$env:TEMP\lipi_extracted\LiPi_Lang-main\*" -Destination "$InstallDir" -Recurse -Force
        Remove-Item -Path $zipFile, "$env:TEMP\lipi_extracted" -Recurse -Force
    }
}

# 3. Setup bin directory
$binPath = "$InstallDir\bin"
if (!(Test-Path $binPath)) { New-Item -ItemType Directory -Path $binPath -Force | Out-Null }

# 4. Generate Windows Command and PowerShell Shims for transparent execution
$tools = @("lipi", "lipc", "aati", "haat", "lipils", "lipifmt", "lipidoc", "lipirepl", "lipi-test")

foreach ($t in $tools) {
    # .cmd shim for Windows CMD / Terminal
    $cmdContent = @"
@echo off
where wsl.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    wsl.exe -e "%~dp0$t" %*
) else (
    echo [LiPi Error] WSL2 is required to run LiPi freestanding engine on Windows.
    echo Run 'wsl --install' in an elevated PowerShell terminal to install WSL2.
    exit /b 1
)
"@
    Set-Content -Path "$binPath\$t.cmd" -Value $cmdContent -Force

    # .ps1 shim for PowerShell
    $psContent = @"
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    & wsl.exe -e "`$PSScriptRoot/$t" @args
} else {
    Write-Error "LiPi requires WSL2 on Windows. Run 'wsl --install' in PowerShell to enable WSL2."
}
"@
    Set-Content -Path "$binPath\$t.ps1" -Value $psContent -Force
}
Write-Host "  ✔ Created Windows execution bridge shims (CMD & PowerShell) in $binPath" -ForegroundColor Green

# 5. Add to User Environment Path
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$binPath;$userPath", "User")
    $env:Path = "$binPath;$env:Path"
    Write-Host "  ✔ Added $binPath to User Environment PATH" -ForegroundColor Green
} else {
    Write-Host "  ✔ $binPath already present in User Environment PATH" -ForegroundColor Green
}

Write-Host "`n  🎉 LiPi successfully installed on Windows!" -ForegroundColor Green
Write-Host "  • Compiler:     lipc (generates PE32+ .exe, WASM, ELF64, Mach-O)" -ForegroundColor Cyan
Write-Host "  • CLI Runner:   lipi (runs scripts and interactive REPL)" -ForegroundColor Cyan
Write-Host "  • Package Tool: aati (manage packages and cryptographically sign bundles)" -ForegroundColor Cyan
Write-Host "  • Example Run:  lipi run examples\01_hello_world\main.lp" -ForegroundColor Yellow
Write-Host "  • Build Binary: lipc examples\01_hello_world\main.lp -o app.exe" -ForegroundColor Yellow
Write-Host "  • Test Suite:   lipi test" -ForegroundColor Yellow
Write-Host "`n  Note: Restart your terminal session to ensure PATH updates take effect." -ForegroundColor Gray
