# ------------------------------------------------------------
# Enable IIS & Required Windows Features
# For Aras Innovator / ASP.NET (.NET Framework)
# ------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms

Write-Host "Checking IIS and required Windows features..."

$features = @(
    # IIS Core
    "IIS-WebServerRole",
    "IIS-WebServer",
    "IIS-CommonHttpFeatures",

    # HTTP Features
    "IIS-DefaultDocument",
    "IIS-DirectoryBrowsing",
    "IIS-HttpErrors",
    "IIS-StaticContent",

    # Application Development
    "IIS-ApplicationDevelopment",
    "IIS-NetFxExtensibility45",
    "IIS-ASPNET45",
    "IIS-ISAPIExtensions",
    "IIS-ISAPIFilter",

    # Security
    "IIS-Security",
    "IIS-WindowsAuthentication",
    "IIS-RequestFiltering",

    # Management
    "IIS-ManagementConsole"
)

$restartRequired = $false

foreach ($feature in $features) {

    $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue

    if ($featureState.State -eq "Enabled") {
        Write-Host "✔ $feature is already enabled. Skipping..."
    }
    else {
        Write-Host "➕ Enabling feature: $feature"
        Enable-WindowsOptionalFeature `
            -Online `
            -FeatureName $feature `
            -All `
            -NoRestart `
            -ErrorAction SilentlyContinue

        $restartRequired = $true
    }
}

Write-Host "IIS feature processing completed."

# Restart IIS only if IIS is already running
if (Get-Service W3SVC -ErrorAction SilentlyContinue) {
    Write-Host "Restarting IIS services..."
    iisreset
}

# -----------------------------
# User Notification Popup
# -----------------------------

if ($restartRequired) {
    [System.Windows.Forms.MessageBox]::Show(
        "IIS features have been enabled successfully.`n`nPlease RESTART the system to apply all changes.",
        "Restart Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
else {
    [System.Windows.Forms.MessageBox]::Show(
        "All required IIS features are already enabled.`nNo restart is required.",
        "IIS Status",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

Write-Host "IIS is ready."
