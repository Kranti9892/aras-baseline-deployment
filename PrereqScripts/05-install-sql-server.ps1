# ------------------------------------------------------------
# SQL Server 2019 (Offline Media) Installation + Aras Config
#
# - Uses setup.exe from offline ISO
# - Central config.ps1
# - Idempotent (instance-aware)
# - Progress UI enabled
# - Safe SQL configuration using SA login
#
# Compatible with:
# - PowerShell 7
# - Jenkins
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
Write-Host "SQL Edition : $SQL_EDITION"
Write-Host "SQL Version : $SQL_VERSION"
Write-Host "SQL Instance: $SQL_INSTANCE_NAME"


# ------------------------------------------------------------
# STEP 2: Detect SQL instance correctly
# ------------------------------------------------------------

Write-Host "Checking existing SQL Server instance..."

$expectedServiceName =
    if ($SQL_INSTANCE_NAME -eq "MSSQLSERVER") {
        "MSSQLSERVER"
    } else {
        "MSSQL`$$SQL_INSTANCE_NAME"
    }

$sqlService = Get-Service -Name $expectedServiceName -ErrorAction SilentlyContinue
$IsSqlInstalled = $false

if ($sqlService) {
    Write-Host "SQL Server instance '$SQL_INSTANCE_NAME' already installed."
    Write-Host "Service Status : $($sqlService.Status)"
    $IsSqlInstalled = $true
} else {
    Write-Host "SQL Server instance '$SQL_INSTANCE_NAME' not found."
}


# ------------------------------------------------------------
# STEP 3: Install SQL Server (ONLY if required)
# ------------------------------------------------------------

if (-not $IsSqlInstalled) {

    Write-Host "Proceeding with SQL Server installation..."
    Write-Host "SQL Installer UI with progress bar will be displayed."

    $SetupExe = Join-Path $INSTALLABLES_PATH "SQL\setup.exe"

    if (-not (Test-Path $SetupExe)) {
        Write-Error "setup.exe not found in Installables\SQL"
        exit 2
    }

    Write-Host "Using SQL setup executable:"
    Write-Host $SetupExe

    $installArgs = @(
        "/QS"                              # Show progress UI
        "/ACTION=Install"
        "/FEATURES=SQLEngine"
        "/INSTANCENAME=$SQL_INSTANCE_NAME"
        "/SECURITYMODE=SQL"
        "/SAPWD=$SQL_SA_PASSWORD"
        "/SQLSYSADMINACCOUNTS=$SQL_SYSADMIN_ACCOUNTS"
        "/IACCEPTSQLSERVERLICENSETERMS"
    )

    Start-Process `
        -FilePath $SetupExe `
        -ArgumentList ($installArgs -join " ") `
        -Wait

    Write-Host "SQL Server installation completed."
}
else {
    Write-Host "Skipping SQL installation phase."
}


# ------------------------------------------------------------
# STEP 4: Enable TCP/IP (SQL 2019 namespace)
# ------------------------------------------------------------

Write-Host "Enabling TCP/IP protocol..."

try {
    $wmi = Get-WmiObject `
        -Namespace "root\Microsoft\SqlServer\ComputerManagement15" `
        -Class ServerNetworkProtocol

    $tcp = $wmi | Where-Object { $_.ProtocolName -eq "Tcp" }

    if ($tcp) {
        $tcp.SetEnable()
        Write-Host "TCP/IP enabled."
    }
}
catch {
    Write-Warning "TCP/IP configuration skipped (may already be enabled)."
}


# ------------------------------------------------------------
# STEP 5: Restart SQL Services
# ------------------------------------------------------------

Write-Host "Restarting SQL services..."

Get-Service -Name $expectedServiceName -ErrorAction SilentlyContinue |
    Restart-Service -Force


# ------------------------------------------------------------
# STEP 6: Validate SQL connectivity (SA)
# ------------------------------------------------------------

Write-Host "Validating SQL connectivity using SA account..."

sqlcmd `
    -S "localhost\$SQL_INSTANCE_NAME" `
    -U "sa" `
    -P "$SQL_SA_PASSWORD" `
    -Q "SELECT @@VERSION" `
    -b

if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to connect to SQL Server using SA credentials."
    exit 3
}


# ------------------------------------------------------------
# STEP 7: Configure SQL for Aras Innovator
# ------------------------------------------------------------

Write-Host "Configuring SQL Server for Aras Innovator..."

$sqlScript = @"
IF NOT EXISTS (SELECT name FROM sys.sql_logins WHERE name = '$ARAS_SQL_LOGIN')
    CREATE LOGIN [$ARAS_SQL_LOGIN] WITH PASSWORD = '$ARAS_SQL_PASSWORD', CHECK_POLICY = OFF;

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$ARAS_DB_NAME')
    CREATE DATABASE [$ARAS_DB_NAME];

USE [$ARAS_DB_NAME];

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$ARAS_SQL_LOGIN')
    CREATE USER [$ARAS_SQL_LOGIN] FOR LOGIN [$ARAS_SQL_LOGIN];

EXEC sp_addrolemember 'db_owner', '$ARAS_SQL_LOGIN';
"@

sqlcmd `
    -S "localhost\$SQL_INSTANCE_NAME" `
    -U "sa" `
    -P "$SQL_SA_PASSWORD" `
    -Q $sqlScript `
    -b
# ------------------------------------------------------------
# STEP 8: Install SQL Server Management Studio (SSMS)
# ------------------------------------------------------------

Write-Host "Checking SQL Server Management Studio (SSMS) installation..."

$ssmsInstalled = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -like "Microsoft SQL Server Management Studio*"
    }

if ($ssmsInstalled) {

    Write-Host "SQL Server Management Studio is already installed."
    Write-Host "Version : $($ssmsInstalled.DisplayVersion)"
}
else {

    Write-Host "SQL Server Management Studio not found. Proceeding with installation..."

    $SsmsInstaller = Join-Path $INSTALLABLES_PATH "SQL\SQL Managment Studio.exe"

    if (-not (Test-Path $SsmsInstaller)) {
        Write-Error "SSMS installer not found at expected location:"
        Write-Error $SsmsInstaller
        exit 4
    }

    Write-Host "Using SSMS installer:"
    Write-Host $SsmsInstaller

    Write-Host "Installing SQL Server Management Studio (silent mode)..."

    Start-Process `
        -FilePath $SsmsInstaller `
        -ArgumentList "/install /quiet /norestart" `
        -Wait `
        -NoNewWindow

    Write-Host "SQL Server Management Studio installation completed."
}


# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

Write-Host ""
Write-Host "SQL Server installation and Aras configuration completed successfully."
Write-Host "SQL Server is ready for Aras Innovator."
Write-Host "⚠ A system restart may be required."

exit 0
