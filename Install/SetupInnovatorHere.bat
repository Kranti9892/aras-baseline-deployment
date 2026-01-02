@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo   ARAS BASELINE INSTANCE INSTALLER
echo ==========================================

:: --------------------------------------------------
:: Read config file path argument
:: --------------------------------------------------
if "%~1"=="" (
  echo ERROR: Config file argument missing
  echo Usage: SetupInnovatorHere.bat Config\machine.local.json
  pause
  exit /b 1
)

set CONFIG_FILE=%~1

if not exist "%CONFIG_FILE%" (
  echo ERROR: Config file not found: %CONFIG_FILE%
  pause
  exit /b 1
)

echo Using config file: %CONFIG_FILE%
echo.

:: --------------------------------------------------
:: Parse JSON using PowerShell
:: --------------------------------------------------
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command ^
  "(Get-Content '%CONFIG_FILE%' | ConvertFrom-Json) | Select-Object InstallPath,VaultPath,SqlInstance,DatabaseName,BaselineDbFile,CodeTreePath,LicenseFile,IisSiteName,Port ^
  | ConvertTo-Json -Compress"`) do set JSON=%%A

for %%K in (InstallPath VaultPath SqlInstance DatabaseName BaselineDbFile CodeTreePath LicenseFile IisSiteName Port) do (
  for /f "usebackq tokens=2 delims=:" %%V in (`echo %JSON% ^| powershell -NoProfile -Command ^
    "(ConvertFrom-Json '%JSON%').%%K"`) do set %%K=%%V
)

echo InstallPath = %InstallPath%
echo VaultPath   = %VaultPath%
echo DB Name     = %DatabaseName%
echo IIS Site    = %IisSiteName%
echo Port        = %Port%
echo.

:: --------------------------------------------------
:: Create folders
:: --------------------------------------------------
echo Creating install and vault directories...
mkdir "%InstallPath%" >nul 2>&1
mkdir "%VaultPath%" >nul 2>&1

:: --------------------------------------------------
:: Restore database
:: --------------------------------------------------
echo Restoring database from baseline...
powershell -NoProfile -Command ^
  "Invoke-Sqlcmd -ServerInstance '%SqlInstance%' -Query \"IF DB_ID('%DatabaseName%') IS NOT NULL BEGIN ALTER DATABASE [%DatabaseName%] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [%DatabaseName%]; END\""

powershell -NoProfile -Command ^
  "Restore-SqlDatabase -ServerInstance '%SqlInstance%' -Database '%DatabaseName%' -BackupFile '%BaselineDbFile%'"

echo Database restore complete
echo.

:: --------------------------------------------------
:: Copy CodeTree
:: --------------------------------------------------
echo Copying CodeTree...
xcopy "%CodeTreePath%\*" "%InstallPath%\" /E /I /Y >nul

echo CodeTree copied
echo.

:: --------------------------------------------------
:: Copy license
:: --------------------------------------------------
if exist "%LicenseFile%" (
  echo Copying license...
  copy /Y "%LicenseFile%" "%InstallPath%\ InnovatorLicense.xml" >nul
)

:: --------------------------------------------------
:: Configure IIS Website
:: --------------------------------------------------
echo Creating IIS site...

powershell -NoProfile -Command ^
  "Import-Module WebAdministration; ^
   if (Test-Path IIS:\Sites\%IisSiteName%) { Remove-Website -Name %IisSiteName% } ^
   New-Website -Name '%IisSiteName%' -Port %Port% -PhysicalPath '%InstallPath%' -Force"

echo IIS site created
echo.

echo ==========================================
echo   INSTANCE SETUP COMPLETE 🎯
echo   URL: http://localhost:%Port%/InnovatorServer
echo ==========================================

pause
endlocal

