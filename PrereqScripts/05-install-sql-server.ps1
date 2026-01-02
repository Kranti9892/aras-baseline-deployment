# ------------------------------------------------------------
# SQL Server 2019 (Offline Media) Installation + Aras Config
# ------------------------------------------------------------

# STEP 1: Load configuration
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


# STEP 2: Detect SQL instance
Write-Host "Checking existing SQL Server instance..."

$expectedServiceName = if ($SQL_INSTANCE_NAME -eq "MSSQLSERVER") {
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


# STEP 3: Install SQL Server
if (-not $IsSqlInstalled) {

    Write-Host "Proceeding with SQL Server installation..."

    $SetupExe = Join-Path $INSTALLABLES_PATH "SQL\setup.exe"
    if (-not (Test-Path $SetupExe)) {
        Write-Error "setup.exe not found in Installables\SQL"
        exit 2
    }

    $installArgs = @(
        "/QS"
        "/ACTION=Install"
        "/FEATURES=SQLEngine"
        "/INSTANCENAME=$SQL_INSTANCE_NAME"
        "/SECURITYMODE=SQL"
        "/SAPWD=$SQL_SA_PASSWORD"
        "/SQLSYSADMINACCOUNTS=$SQL_SYSADMIN_ACCOUNTS"
        "/IACCEPTSQLSERVERLICENSETERMS"
    )

    Start-Process -FilePath $SetupExe -ArgumentList ($installArgs -join " ") -Wait
    Write-Host "SQL Server installation completed."
} else {
    Write-Host "Skipping SQL installation phase."
}


# STEP 4: Enable TCP/IP (best effort)
Write-Host "Enabling TCP/IP protocol..."

try {
    $ns = Get-WmiObject -Namespace "root\Microsoft\SqlServer" -Class "__namespace" |
        Where-Object { $_.Name -like "ComputerManagement*" } |
        Select-Object -Last 1

    if ($ns) {
        $proto = Get-WmiObject -Namespace "root\Microsoft\SqlServer\$($ns.Name)" `
            -Class ServerNetworkProtocol |
            Where-Object { $_.ProtocolName -eq "Tcp" }

        if ($proto) { $proto.SetEnable() | Out-Null }
        Write-Host "TCP/IP enabled."
    }
}
catch {
    Write-Warning "TCP/IP configuration skipped (may already be enabled)."
}


# STEP 5: Restart SQL service
Write-Host "Restarting SQL service..."
Get-Service -Name $expectedServiceName -ErrorAction SilentlyContinue | Restart-Service -Force


# STEP 6: Install ODBC + SQLCMD if missing
Write-Host "Checking SQL client tools..."

$odbcInstalled = Get-ItemProperty `
 "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
 Where-Object { $_.DisplayName -like "Microsoft ODBC Driver*" }

$sqlcmdExists = Get-Command sqlcmd -ErrorAction SilentlyContinue

# ODBC
if (-not $odbcInstalled) {
    Write-Host "Installing Microsoft ODBC Driver..."
    $OdbcInstaller = Join-Path $INSTALLABLES_PATH "SQL\ODBCDriver.exe"
    if (Test-Path $OdbcInstaller) {
        Start-Process $OdbcInstaller -ArgumentList "/quiet /norestart" -Wait
        Write-Host "ODBC Driver installed."
    } else {
        Write-Warning "ODBC installer missing - skipping."
    }
} else {
    Write-Host "ODBC Driver already installed."
}

# SQLCMD
if (-not $sqlcmdExists) {
    Write-Host "Installing SQL Command Line Tools (sqlcmd)..."
    $SqlCmdInstaller = Join-Path $INSTALLABLES_PATH "SQL\SqlCmdTools.exe"
    if (Test-Path $SqlCmdInstaller) {
        Start-Process $SqlCmdInstaller -ArgumentList "/quiet /norestart" -Wait
        Write-Host "sqlcmd installed."
    } else {
        Write-Warning "SQLCMD installer missing - skipping."
    }
} else {
    Write-Host "sqlcmd already installed."
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")


# STEP 7: Validate SA login (only if sqlcmd exists)
Write-Host "Validating SQL connectivity..."

if (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
    sqlcmd -S "localhost\$SQL_INSTANCE_NAME" -U sa -P "$SQL_SA_PASSWORD" -Q "SELECT @@VERSION" -b
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unable to connect to SQL Server using SA credentials."
        exit 3
    }
    Write-Host "SQL connection validated."
} else {
    Write-Warning "sqlcmd not available - skipping connectivity validation."
}


# STEP 8: Configure Aras DB + Login
Write-Host "Configuring SQL for Aras Innovator..."

$sqlScript = @'
IF NOT EXISTS (SELECT name FROM sys.sql_logins WHERE name = '$ARAS_SQL_LOGIN')
    CREATE LOGIN [$ARAS_SQL_LOGIN] WITH PASSWORD = '$ARAS_SQL_PASSWORD', CHECK_POLICY = OFF;

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$ARAS_DB_NAME')
    CREATE DATABASE [$ARAS_DB_NAME];

USE [$ARAS_DB_NAME];

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$ARAS_SQL_LOGIN')
    CREATE USER [$ARAS_SQL_LOGIN] FOR LOGIN [$ARAS_SQL_LOGIN];

EXEC sp_addrolemember 'db_owner', '$ARAS_SQL_LOGIN';
'@

if (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
    sqlcmd -S "localhost\$SQL_INSTANCE_NAME" -U sa -P "$SQL_SA_PASSWORD" -Q "$sqlScript" -b
    Write-Host "Aras database and login configured."
} else {
    Write-Warning "sqlcmd missing - database configuration skipped."
}


# FINAL
Write-Host ""
Write-Host "SQL Server installation and configuration completed."
Write-Host "SQL Server is ready for Aras Innovator."
Write-Host "A system restart may be required."
exit 0
