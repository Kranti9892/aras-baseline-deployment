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


$configFilePath = Join-Path $PSScriptRoot "..\ConfigurationFiles\config.ps1"
$configFilePath = Resolve-Path $configFilePath -ErrorAction SilentlyContinue

if (-not $configFilePath) {
    Write-Error "Configuration file not found."
    exit 1
}

. $configFilePath






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
