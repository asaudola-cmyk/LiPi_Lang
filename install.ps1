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

# 4. Install Native Windows PE32+ (.exe) Binaries if present in dist/
if (Test-Path "$InstallDir\dist") {
    Get-ChildItem -Path "$InstallDir\dist\*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "$binPath\$($_.Name)" -Force
        Write-Host "  ✔ Installed native Windows PE32+ binary: $($_.Name)" -ForegroundColor Green
    }
}

# 5. Generate Windows Command and PowerShell Hybrid Execution Bridges
$tools = @("lipi", "lipc", "aati", "haat", "lipils", "lipifmt", "lipidoc", "lipirepl", "lipi-test")

foreach ($t in $tools) {
    # .cmd hybrid bridge (Prioritizes native .exe, falls back to WSL for ELF utilities)
    $cmdContent = @"
@echo off
if exist "%~dp0$t.exe" (
    "%~dp0$t.exe" %*
    exit /b %ERRORLEVEL%
)
where wsl.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    wsl.exe -e "%~dp0$t" %*
) else (
    echo [LiPi Error] WSL2 is required to run LiPi ELF binaries on Windows when $t.exe is not found.
    echo Run 'wsl --install' in an elevated PowerShell terminal to install WSL2.
    exit /b 1
)
"@
    Set-Content -Path "$binPath\$t.cmd" -Value $cmdContent -Force

    # .ps1 hybrid bridge
    $psContent = @"
`$exePath = Join-Path `$PSScriptRoot "$t.exe"
if (Test-Path `$exePath) {
    & `$exePath @args
    exit `$LASTEXITCODE
}
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    & wsl.exe -e "`$PSScriptRoot/$t" @args
} else {
    Write-Error "LiPi requires WSL2 on Windows when $t.exe is not found. Run 'wsl --install' in PowerShell."
}
"@
    Set-Content -Path "$binPath\$t.ps1" -Value $psContent -Force
}
Write-Host "  ✔ Configured Windows execution bridges (Native PE32+ & WSL fallbacks) in $binPath" -ForegroundColor Green

# 6. Add to User Environment Path
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$binPath;$userPath", "User")
    $env:Path = "$binPath;$env:Path"
    Write-Host "  ✔ Added $binPath to User Environment PATH" -ForegroundColor Green
} else {
    Write-Host "  ✔ $binPath already present in User Environment PATH" -ForegroundColor Green
}

Write-Host "`n  🎉 LiPi successfully installed on Windows!" -ForegroundColor Green
Write-Host "  • Native Compiler: lipc.exe (Direct PE32+ .exe, WASM, ELF64, Mach-O)" -ForegroundColor Cyan
Write-Host "  • Native CLI:      lipi.exe (Direct program runner & in-memory evaluator)" -ForegroundColor Cyan
Write-Host "  • Package Tool:    aati.exe (Cryptographically sign & verify packages)" -ForegroundColor Cyan
Write-Host "  • Example Run:     lipi run examples\01_hello_world\main.lp" -ForegroundColor Yellow
Write-Host "  • Build EXE:       lipc examples\01_hello_world\main.lp -o app.exe --target windows" -ForegroundColor Yellow
Write-Host "  • Run Test Suite:  lipi test" -ForegroundColor Yellow
Write-Host "`n  Note: Restart your terminal session to ensure PATH updates take effect." -ForegroundColor Gray
