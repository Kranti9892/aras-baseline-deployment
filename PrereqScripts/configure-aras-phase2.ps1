# ============================================================
# Aras Innovator 36 – Phase 2 Post-Install Configuration
# License + IIS + OAuth Validation
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " Aras Innovator Phase-2 Configuration "
Write-Host "========================================="

# ------------------------------------------------------------
# Load Configuration
# ------------------------------------------------------------
$configFilePath = Join-Path $PSScriptRoot "..\ConfigurationFiles\config.ps1"
. $configFilePath

Write-Host "Configuration loaded successfully"

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
$serverRoot = Join-Path $ARAS_INSTALL_DIR "Innovator\Server"
$appDataPath = Join-Path $serverRoot "App_Data"
$licenseDir = Join-Path $appDataPath "License"
$licenseFile = Join-Path $licenseDir "License.xml"

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------
if (-not (Test-Path $serverRoot)) {
    Write-Error "Innovator Server path not found: $serverRoot"
    exit 10
}

if (-not $ARAS_LICENSE_XML) {
    Write-Error "ARAS_LICENSE_XML missing in config.ps1"
    exit 11
}

# ------------------------------------------------------------
# Step 1: License
# ------------------------------------------------------------
Write-Host "Ensuring License directory exists..."

if (-not (Test-Path $licenseDir)) {
    New-Item -ItemType Directory -Path $licenseDir | Out-Null
}

Write-Host "Writing License.xml..."

$ARAS_LICENSE_XML.Trim() | Out-File `
    -FilePath $licenseFile `
    -Encoding UTF8 `
    -Force

Write-Host "License applied successfully"

# ------------------------------------------------------------
# Step 2: IIS AppPool Validation
# ------------------------------------------------------------
Import-Module WebAdministration

$appPoolName = "Aras Innovator AppPool ASP.NET Core"
$appPoolPath = "IIS:\AppPools\$appPoolName"

if (-not (Test-Path $appPoolPath)) {
    Write-Error "Application Pool not found: $appPoolName"
    exit 20
}

Set-ItemProperty $appPoolPath -Name managedRuntimeVersion -Value ""
Set-ItemProperty $appPoolPath -Name managedPipelineMode -Value Integrated

Write-Host "IIS AppPool validated"

# ------------------------------------------------------------
# Step 3: Restart IIS
# ------------------------------------------------------------
Write-Host "Restarting IIS..."
iisreset | Out-Null

# ------------------------------------------------------------
# Step 4: OAuth Health Check (NOT modification)
# ------------------------------------------------------------
Write-Host "Validating OAuth endpoint..."

$oauthUrl = "$ARAS_APP_SERVER_URL/OAuthServer/.well-known/openid-configuration"

try {
    $resp = Invoke-WebRequest -Uri $oauthUrl -UseBasicParsing -TimeoutSec 15
    Write-Host "OAuth endpoint is responding"
}
catch {
    Write-Warning "OAuth endpoint not reachable yet (may initialize on first use)"
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "========================================="
Write-Host " Aras Innovator Phase-2 COMPLETED "
Write-Host " License applied & IIS ready "
Write-Host "========================================="
