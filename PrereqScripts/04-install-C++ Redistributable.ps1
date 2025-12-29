# ------------------------------------------------------------
# Install Microsoft VC++ Redistributable & .NET Core Runtime
#
# Behavior:
# - CHECK first
# - INSTALL only if missing
# - SKIP if already installed
#
# Compatible with:
# - PowerShell 7 (pwsh)
# - Jenkins
# - Manual execution
# ------------------------------------------------------------


# ------------------------------------------------------------
# STEP 1: Load configuration
# ------------------------------------------------------------

$configFilePath = Join-Path $PSScriptRoot "..\ConfigurationFiles\config.ps1"
$configFilePath = Resolve-Path $configFilePath -ErrorAction SilentlyContinue

if (-not $configFilePath) {
    Write-Error "Configuration file not found."
    exit 1
}

. $configFilePath

Write-Host "Configuration loaded successfully"
Write-Host "Installables Path : $INSTALLABLES_PATH"


# ============================================================
# PART A: Microsoft Visual C++ Redistributable
# ============================================================

Write-Host ""
Write-Host "=== Microsoft Visual C++ Redistributable Check ==="

$vcInstalled = Get-ItemProperty `
    HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -match "Microsoft Visual C\+\+.*Redistributable"
    }

if ($vcInstalled) {

    Write-Host "Microsoft Visual C++ Redistributable already installed."
    $vcInstalled | ForEach-Object {
        Write-Host " - $($_.DisplayName) ($($_.DisplayVersion))"
    }
    Write-Host "Skipping VC++ installation."
}
else {

    Write-Host "Microsoft Visual C++ Redistributable NOT found."

    $vcInstaller = Join-Path $INSTALLABLES_PATH "Microsoft Visual C++ Redistributable.exe"

    if (-not (Test-Path $vcInstaller)) {
        Write-Error "VC++ Redistributable installer not found:"
        Write-Error $vcInstaller
        exit 2
    }

    Write-Host "Installing Microsoft Visual C++ Redistributable..."
    Start-Process `
        -FilePath $vcInstaller `
        -ArgumentList "/quiet /norestart" `
        -Wait `
        -NoNewWindow

    Write-Host "Microsoft Visual C++ Redistributable installation completed."
}


# ============================================================
# PART B: .NET Core Runtime
# ============================================================

Write-Host ""
Write-Host "=== .NET Core Runtime Check ==="

$dotnetExe = "C:\Program Files\dotnet\dotnet.exe"

if (Test-Path $dotnetExe) {

    Write-Host ".NET Core Runtime already installed."
    & $dotnetExe --list-runtimes
    Write-Host "Skipping .NET Core Runtime installation."
}
else {

    Write-Host ".NET Core Runtime NOT found."

    $runtimeInstaller = Join-Path $INSTALLABLES_PATH "NET Core Runtime.exe"

    if (-not (Test-Path $runtimeInstaller)) {
        Write-Error ".NET Core Runtime installer not found:"
        Write-Error $runtimeInstaller
        exit 3
    }

    Write-Host "Installing .NET Core Runtime..."
    Start-Process `
        -FilePath $runtimeInstaller `
        -ArgumentList "/quiet /norestart" `
        -Wait `
        -NoNewWindow

    # Post-install validation
    if (Test-Path $dotnetExe) {
        Write-Host ".NET Core Runtime installation validated successfully."
        & $dotnetExe --list-runtimes
    }
    else {
        Write-Error ".NET Core Runtime installation failed."
        exit 4
    }
}


# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

Write-Host ""
Write-Host "All prerequisite Installation and validation is  completed successfully."
Write-Host "System is ready for Aras Innovator . Please Install the SQL 2019/2022"

exit 0
