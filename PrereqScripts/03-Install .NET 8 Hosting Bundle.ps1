# ------------------------------------------------------------
# Install .NET 6 ASP.NET Core Hosting Bundle
#
# Purpose:
# - Ensures .NET 6 ASP.NET Core Hosting Bundle is installed
# - Loads configuration from ConfigurationFiles\config.ps1
# - Uses offline installer if available
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
    Write-Error "Configuration file not found at expected location."
    exit 1
}

. $configFilePath

Write-Host "Configuration loaded successfully"
Write-Host "Installables Path : $INSTALLABLES_PATH"


# ------------------------------------------------------------
# STEP 2: Check if .NET 6 Hosting Bundle is already installed
# ------------------------------------------------------------
$aspNetCoreModulePath = "C:\Program Files\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"

Write-Host "Checking if ASP.NET Core Hosting Bundle is already installed..."

if (Test-Path $aspNetCoreModulePath) {
    Write-Host ".NET Hosting Bundle already installed."
    Write-Host "AspNetCoreModule found at:"
    Write-Host $aspNetCoreModulePath
    Write-Host "Skipping installation."
    exit 0
}
$dotNetRegPath = "HKLM:\SOFTWARE\Microsoft\ASP.NET Core\Shared Framework"

Write-Host "Checking if .NET 6 ASP.NET Core Hosting Bundle is installed..."

if (Test-Path $dotNetRegPath) {

    $installedVersions = Get-ChildItem $dotNetRegPath -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -like "6.*" }

    if ($installedVersions) {
        Write-Host "Detected .NET 6 ASP.NET Core Hosting Bundle versions:"
        foreach ($v in $installedVersions) {
            Write-Host " - Version: $($v.PSChildName)"
        }

        Write-Host ".NET 6 Hosting Bundle is already installed. Skipping installation."
        exit 0
    }
}

Write-Host ".NET 6 ASP.NET Core Hosting Bundle not found. Installation required."


# ------------------------------------------------------------
# STEP 3: Locate offline installer
# ------------------------------------------------------------

Write-Host "Searching for .NET 6 Hosting Bundle installer in Installables..."

$dotNetInstaller = Get-ChildItem `
    -Path $INSTALLABLES_PATH `
    -Recurse `
    -Filter "dotnet-hosting-6.*-win.exe" `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $dotNetInstaller) {
    Write-Error "dotnet-hosting-6.x installer not found in Installables."
    exit 2
}

Write-Host "Using installer:"
Write-Host $dotNetInstaller.FullName


# ------------------------------------------------------------
# STEP 4: Install .NET 6 Hosting Bundle silently
# ------------------------------------------------------------

Write-Host "Installing .NET 6 ASP.NET Core Hosting Bundle..."

Start-Process `
    -FilePath $dotNetInstaller.FullName `
    -ArgumentList "/quiet /norestart" `
    -Wait `
    -NoNewWindow


# ------------------------------------------------------------
# STEP 5: Post-install validation (CORRECT METHOD)
# ------------------------------------------------------------

Write-Host "Validating .NET 6 Hosting Bundle installation..."

$aspNetCoreModulePath = "C:\Program Files\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"

if (Test-Path $aspNetCoreModulePath) {
    Write-Host ".NET 6 Hosting Bundle validation successful."
    Write-Host "AspNetCoreModule found at:"
    Write-Host $aspNetCoreModulePath
}
else {
    Write-Error ".NET 6 Hosting Bundle validation failed."
    Write-Error "AspNetCoreModule not found."
    exit 3
}


# ------------------------------------------------------------
# STEP 6: Completion
# ------------------------------------------------------------

Write-Host ".NET 6 ASP.NET Core Hosting Bundle installation completed successfully."
Write-Host "⚠ IIS restart or system reboot may be required."

exit 0
