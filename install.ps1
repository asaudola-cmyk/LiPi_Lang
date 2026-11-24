# =============================================================================
# Lipi Programming Language — Windows PowerShell Installer
# GitHub: https://github.com/asaudola-cmyk/LiPi_Lang
# Usage:  irm https://raw.githubusercontent.com/asaudola-cmyk/LiPi_Lang/main/install.ps1 | iex
# =============================================================================

[CmdletBinding()]
param (
    [string]$InstallDir = "$HOME\.lipi",
    [string]$BinDir = "$HOME\.local\bin",
    [switch]$Update,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$tools = @(
    "lipi", "lipc", "aati", "haat", "lipipkg", "lipilsp", "lipils",
    "lipidbg", "lipifmt", "lipiconvert", "lipidoc", "lipirepl",
    "lipiassimilate", "lipi_akhara", "lipi_unikernel_boot", "lipi-build", "lipi-test"
)

if ($Uninstall) {
    Write-Host "  → Uninstalling LiPi from $BinDir and $InstallDir..." -ForegroundColor Cyan
    foreach ($t in $tools) {
        Remove-Item -Path "$BinDir\$t.exe", "$BinDir\$t.cmd", "$BinDir\$t.ps1", "$BinDir\$t" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$InstallDir") {
        Remove-Item -Path "$InstallDir" -Recurse -Force -ErrorAction SilentlyContinue
    }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath) {
        $cleaned = ($userPath.Split(';') | Where-Object { $_ -and ($_ -ne $BinDir) }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $cleaned, "User")
    }
    Write-Host "  ✔ LiPi successfully uninstalled." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "  ██╗     ██╗██████╗ ██╗" -ForegroundColor Cyan
Write-Host "  ██║     ██║██╔══██╗██║" -ForegroundColor Cyan
Write-Host "  ██║     ██║██████╔╝██║" -ForegroundColor Cyan
Write-Host "  ██║     ██║██╔═══╝ ██║" -ForegroundColor Cyan
Write-Host "  ███████╗██║██║     ██║" -ForegroundColor Cyan
Write-Host "  ╚══════╝╚═╝╚═╝     ╚═╝" -ForegroundColor Cyan
Write-Host "  Lipi Programming Language — 1.0.0 (Windows Setup)" -ForegroundColor Yellow
Write-Host "  Self-hosted bilingual systems programming language (zero C, libc, or LLVM)`n"

# 1. Verify Architecture
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
Write-Host "  ✔ Detected Windows Architecture: $arch" -ForegroundColor Green

# 2. Check Git or Download Repository
$repoUrl = "https://github.com/asaudola-cmyk/LiPi_Lang.git"
$zipUrl = "https://github.com/asaudola-cmyk/LiPi_Lang/archive/refs/heads/main.zip"

if ($PSScriptRoot -and (Test-Path "$PSScriptRoot\src\compiler\driver_cli.lp")) {
    $InstallDir = $PSScriptRoot
    Write-Host "  ✔ Using local LiPi repository: $InstallDir" -ForegroundColor Green
    if ($Update -and (Test-Path "$InstallDir\.git") -and (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  → Pulling latest updates in $InstallDir..." -ForegroundColor Cyan
        git -C "$InstallDir" pull --quiet
    }
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
$binPath = $BinDir
if (!(Test-Path $binPath)) { New-Item -ItemType Directory -Path $binPath -Force | Out-Null }

# 4. Install Native Windows PE32+ (.exe) Binaries if present in dist/ or bin/, or bootstrap via WSL2
foreach ($exeDir in @("$InstallDir\dist", "$InstallDir\bin")) {
    if (Test-Path $exeDir) {
        Get-ChildItem -Path "$exeDir\*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination "$binPath\$($_.Name)" -Force
            Write-Host "  ✔ Installed native Windows PE32+ binary: $($_.Name)" -ForegroundColor Green
        }
    }
}

$hasWsl = [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
if ($hasWsl -and ($Update -or !(Test-Path "$InstallDir\bin\lipc"))) {
    Write-Host "  → Bootstrapping LiPi native toolchain inside WSL2..." -ForegroundColor Cyan
    $wslInstallDir = (& wsl.exe wslpath -a "$InstallDir" 2>$null)
    if ($wslInstallDir) {
        & wsl.exe sh -c "cd '$wslInstallDir' && make build"
    }
}

$hasNativeExe = Test-Path "$binPath\lipc.exe"
$hasWslCompiler = $hasWsl -and (Test-Path "$InstallDir\bin\lipc")
if (-not $hasNativeExe -and -not $hasWslCompiler) {
    Write-Error "LiPi installation failed: neither native Windows PE32+ ($binPath\lipc.exe) nor a WSL2 compiler ($InstallDir\bin\lipc) is available. Install WSL2 ('wsl --install') or provide Windows PE32+ binaries in dist/."
    exit 1
}

# 5. Generate Windows Command and PowerShell Hybrid Execution Bridges
foreach ($t in $tools) {
    $cmdContent = @"
@echo off
if exist "%~dp0$t.exe" (
    "%~dp0$t.exe" %*
    exit /b %ERRORLEVEL%
)
where wsl.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%i in ('wsl.exe wslpath -a "$InstallDir\bin\$t"') do set "WSL_TOOL=%%i"
    wsl.exe "%WSL_TOOL%" %*
    exit /b %ERRORLEVEL%
) else (
    echo [LiPi Error] WSL2 is required to run LiPi ELF binaries on Windows when $t.exe is not found.
    echo Run 'wsl --install' in an elevated PowerShell terminal to install WSL2.
    exit /b 1
)
"@
    Set-Content -Path "$binPath\$t.cmd" -Value $cmdContent -Force

    $psContent = @"
`$exePath = Join-Path `$PSScriptRoot "$t.exe"
if (Test-Path `$exePath) {
    & `$exePath @args
    exit `$LASTEXITCODE
}
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    `$wslTool = (& wsl.exe wslpath -a "$InstallDir\bin\$t")
    & wsl.exe `$wslTool @args
    exit `$LASTEXITCODE
} else {
    Write-Error "LiPi requires WSL2 on Windows when $t.exe is not found. Run 'wsl --install' in PowerShell."
    exit 1
}
"@
    Set-Content -Path "$binPath\$t.ps1" -Value $psContent -Force
}
Write-Host "  ✔ Configured Windows execution bridges (Native PE32+ & WSL2) in $binPath" -ForegroundColor Green

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
Write-Host "  • Native Compiler: lipc (Direct PE32+ .exe, WASM, ELF64, Mach-O)" -ForegroundColor Cyan
Write-Host "  • Native CLI:      lipi (Direct program runner & in-memory evaluator)" -ForegroundColor Cyan
Write-Host "  • Package Tool:    aati (Cryptographically sign & verify packages)" -ForegroundColor Cyan
Write-Host "  • Example Run:     lipi run examples\01_hello_world\main.lp" -ForegroundColor Yellow
Write-Host "  • Uninstall:       .\install.ps1 -Uninstall" -ForegroundColor Yellow
Write-Host "`n  Note: Restart your terminal session to ensure PATH updates take effect." -ForegroundColor Gray
