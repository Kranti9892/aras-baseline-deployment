# ============================================================
# PHASE 3 - Aras Innovator 36
# DB Creation + IIS + Instance Startup (FINAL)
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " PHASE 3 - ARAS INNOVATOR 36 START "
Write-Host "========================================="

# ------------------------------------------------------------
# Load Central Config
# ------------------------------------------------------------
$configFilePath = Join-Path $PSScriptRoot "..\ConfigurationFiles\config.ps1"
. $configFilePath

# ------------------------------------------------------------
# Tool Paths (ABSOLUTE)
# ------------------------------------------------------------
$SQLCMD  = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"
$MSI64   = "C:\Windows\System32\msiexec.exe"

if (-not (Test-Path $SQLCMD)) { throw "sqlcmd.exe not found" }
if (-not (Test-Path $MSI64))  { throw "64-bit msiexec.exe not found" }

# ------------------------------------------------------------
# Resolve MSI
# ------------------------------------------------------------
$INNOVATOR_MSI = Join-Path $ARAS_INSTALLER_ROOT $ARAS_MSI_NAME
if (-not (Test-Path $INNOVATOR_MSI)) {
    throw "InnovatorSetup.msi not found at $INNOVATOR_MSI"
}

# ------------------------------------------------------------
# SQL Connectivity Test (TCP)
# ------------------------------------------------------------
& $SQLCMD `
    -S $SQL_SERVER `
    -U $SQL_DBA_LOGIN `
    -P $SQL_DBA_PASSWORD `
    -Q "SELECT 1" `
    -b

Write-Host "SQL connectivity OK"

# ------------------------------------------------------------
# Prepare Log
# ------------------------------------------------------------
New-Item -ItemType Directory -Path $TEMP_PATH -Force | Out-Null
$MSI_LOG = Join-Path $TEMP_PATH "Aras_Phase3_DB.log"

# ------------------------------------------------------------
# MSI Arguments (COMPLETE & REQUIRED)
# ------------------------------------------------------------
$msiArgs = @(
    "/i `"$INNOVATOR_MSI`""
    "/qn"
    "/norestart"
    "/l*v `"$MSI_LOG`""

    "INSTALLDIR=`"$ARAS_INSTALL_DIR`""
    "ADDLOCAL=InnovatorServer,InnovatorClient,WebServer"

    "SQL_SERVER_NAME=`"$SQL_SERVER`""
    "SQL_DATABASE_NAME=`"$ARAS_DB_NAME`""
    "SQL_USER_NAME=`"$SQL_DBA_LOGIN`""
    "SQL_USER_PASSWORD=`"$SQL_DBA_PASSWORD`""
    "SQL_USE_WINDOWS_AUTH=0"
    "CREATE_DATABASE=1"

    "WEB_ALIAS=InnovatorServer"
    "INSTANCE_NAME=InnovatorServer"

    "VAULT_NAME=InnovatorServer"
    "VAULT_PATH=D:\ARAS_INSTALL_AUTOMATION\ArasVaults\InnovatorServer"

    "SKIP_SMTP_VALIDATION=1"
    "SKIP_CONVERSION_SERVER_VALIDATION=1"

    "LICENSE_TYPE=Unlimited"
    "LICENSE_KEY=abd9969b7216dd37f4eaf6aa9c10096f"
    "ACTIVATION_KEY=E7AC6815596F42B792FC751CD49A87EE"

    "OAUTH_CERTIFICATES_PASSWORD=`"$ARAS_OAUTH_PASSWORD`""
)




# ------------------------------------------------------------
# FORCE 64-BIT MSI EXECUTION (CRITICAL)
# ------------------------------------------------------------
Write-Host "Launching 64-bit MSI engine..."

$env:PROCESSOR_ARCHITEW6432 = $null

$proc = Start-Process `
    -FilePath $MSI64 `
    -ArgumentList $msiArgs `
    -Wait `
    -PassThru `
    -NoNewWindow

if ($proc.ExitCode -ne 0) {
    throw "InnovatorSetup.msi FAILED. Check log: $MSI_LOG"
}

Write-Host "InnovatorSetup.msi completed successfully"

# ------------------------------------------------------------
# HARD DB VALIDATION
# ------------------------------------------------------------
$dbCheck = & $SQLCMD `
    -S $SQL_SERVER `
    -U $SQL_DBA_LOGIN `
    -P $SQL_DBA_PASSWORD `
    -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name='$ARAS_DB_NAME'" `
    -h -1

if (-not $dbCheck) {
    throw "Database $ARAS_DB_NAME NOT created"
}

Write-Host "Database $ARAS_DB_NAME created"

# ------------------------------------------------------------
# IIS FIX
# ------------------------------------------------------------
Import-Module WebAdministration

$appPoolName = "Aras Innovator AppPool ASP.NET Core"
$appPoolPath = "IIS:\AppPools\$appPoolName"

if (Test-Path $appPoolPath) {
    Set-ItemProperty $appPoolPath managedRuntimeVersion ""
    Set-ItemProperty $appPoolPath processModel.identityType LocalSystem
    Restart-WebAppPool $appPoolName
}

iisreset | Out-Null

# ------------------------------------------------------------
# URL HEALTH CHECK
# ------------------------------------------------------------
$healthUrl = "$ARAS_APP_SERVER_URL/Server/InnovatorServer.aspx"
$ready = $false

for ($i = 0; $i -lt 30; $i++) {
    try {
        $r = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 10
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    }
    catch {
        Start-Sleep -Seconds 10
    }
}

if (-not $ready) {
    throw "Innovator URL NOT responding"
}

Write-Host "========================================="
Write-Host " PHASE 3 SUCCESS "
Write-Host " DB + INSTANCE UP "
Write-Host " URL: $ARAS_APP_SERVER_URL "
Write-Host "========================================="
