# ============================================================
# Aras Innovator 36 – Phase 1 Core Installation (SUPPORTED)
# ============================================================

param (
    [string]$LogFilePath = "C:\Aras\Logs\aras_install.log"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " Starting Aras Innovator Phase-1 Install "
Write-Host "========================================="

# ------------------------------------------------------------
# Load Configuration
# ------------------------------------------------------------

$configFilePath = Join-Path $PSScriptRoot "..\ConfigurationFiles\config.ps1"
$configFilePath = Resolve-Path $configFilePath -ErrorAction SilentlyContinue

if (-not $configFilePath) {
    Write-Error "Configuration file not found."
    exit 1
}

. $configFilePath

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

$INSTALLER = Join-Path `
    (Join-Path $ARAS_INSTALLER_ROOT $ARAS_RELEASE_FOLDER) `
    $ARAS_MSI_NAME

if (-not (Test-Path $INSTALLER)) {
    Write-Error "Aras MSI not found: $INSTALLER"
    exit 1
}

if (-not (Test-Path $ARAS_LOG_DIR)) {
    New-Item -ItemType Directory -Path $ARAS_LOG_DIR | Out-Null
}

# ------------------------------------------------------------
# MSI Install (SUPPORTED MODE)
# ------------------------------------------------------------

Write-Host "Installing Aras Innovator 36 (basic UI mode)..."
Write-Host "MSI Log : $LogFilePath"

$arguments = @(
    "/i", "`"$INSTALLER`"",
    "/qb",
    "/norestart",
    "AGREETOLICENSE=Yes",
    "INSTALLDIR=`"$ARAS_INSTALL_DIR`"",
    "/L*v", "`"$LogFilePath`""
)

$process = Start-Process `
    -FilePath "msiexec.exe" `
    -ArgumentList $arguments `
    -Wait `
    -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "Aras MSI installation failed. ExitCode: $($process.ExitCode)"
    exit 10
}

Write-Host "========================================="
Write-Host " Aras Innovator CORE INSTALL COMPLETED "
Write-Host "Next step: Post-install configuration"
Write-Host "========================================="
