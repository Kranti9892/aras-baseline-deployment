# ------------------------------------------------------------
# Install .NET Framework 4.7.2
#
# Purpose:
# - Ensures .NET Framework 4.7.2 or higher is installed
# - Loads configuration from ConfigurationFiles\config.ps1
# - Uses offline installer if available
# - Falls back to Microsoft download if allowed
#
# Compatible with:
# - PowerShell 7 (pwsh)
# - Jenkins
# - Manual execution
# ------------------------------------------------------------


# ------------------------------------------------------------
# STEP 1: Load configuration (PROVEN RELATIVE-PATH PATTERN)
# ------------------------------------------------------------

# Resolve configuration file path relative to this script
$configFilePath = Join-Path $PSScriptRoot "..\ConfigurationFiles\config.ps1"
$configFilePath = Resolve-Path $configFilePath -ErrorAction SilentlyContinue

if (-not $configFilePath) {
    Write-Error "Configuration file not found at expected location."
    Write-Error "Expected: ..\ConfigurationFiles\config.ps1"
    exit 1
}

# Load configuration
. $configFilePath

Write-Host "Configuration loaded successfully"
Write-Host "ARAS Base Path     : $ARAS_BASE_PATH"
Write-Host "Installables Path : $INSTALLABLES_PATH"


# ------------------------------------------------------------
# STEP 2: Check installed .NET Framework version
# ------------------------------------------------------------

$dotNetReleaseKeyRequired = 461808   # .NET Framework 4.7.2
$regPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"

Write-Host "Checking .NET Framework version..."

if (Test-Path $regPath) {

    $netProps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
    $release  = $netProps.Release

    if ($release -ge $dotNetReleaseKeyRequired) {

        Write-Host "Detected .NET Framework Version : $($netProps.Version)"
        Write-Host "Detected .NET Release Key       : $($netProps.Release)"
        Write-Host ".NET Framework 4.7.2 or later is already installed. Skipping installation."

        exit 0
    }
}

Write-Host ".NET Framework 4.7.2 not found. Installation required."


# ------------------------------------------------------------
# STEP 3: Locate offline installer in Installables folder
# ------------------------------------------------------------

Write-Host "Searching for .NET Framework 4.7.2 installer in Installables..."

$dotNetInstaller = Get-ChildItem `
    -Path $INSTALLABLES_PATH `
    -Recurse `
    -Filter "*.exe" `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "4\.7\.2|472|Net.*Framework"
    } |
    Select-Object -First 1


# ------------------------------------------------------------
# STEP 4: Download installer if not found locally
# ------------------------------------------------------------

if (-not $dotNetInstaller) {

    if (-not $ALLOW_INTERNET_DOWNLOAD) {
        Write-Error "Offline installer not found and internet download is disabled."
        exit 2
    }

    Write-Host "Offline installer not found. Downloading from Microsoft..."

    if (-not (Test-Path $TEMP_PATH)) {
        New-Item -ItemType Directory -Path $TEMP_PATH | Out-Null
    }

    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=863265"
    $downloadTarget = Join-Path $TEMP_PATH "NDP472-KB4054530-x86-x64-AllOS-ENU.exe"

    Invoke-WebRequest `
        -Uri $downloadUrl `
        -OutFile $downloadTarget `
        -ErrorAction Stop

    $dotNetInstaller = Get-Item $downloadTarget
}

Write-Host "Using installer:"
Write-Host $dotNetInstaller.FullName


# ------------------------------------------------------------
# STEP 5: Install .NET Framework silently
# ------------------------------------------------------------

Write-Host "Installing .NET Framework 4.7.2..."

Start-Process `
    -FilePath $dotNetInstaller.FullName `
    -ArgumentList "/quiet /norestart" `
    -Wait `
    -NoNewWindow


# ------------------------------------------------------------
# STEP 6: Completion message
# ------------------------------------------------------------

Write-Host ".NET Framework 4.7.2 installation completed successfully."
Write-Host "⚠ A system restart may be required."
exit 0
