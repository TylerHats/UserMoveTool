# Windows Setup Integration Script v2.1

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$PublicStaging = "C:\System_Profile_Migration"
$JsonConfig = Get-Content (Join-Path $PublicStaging "Migration.json") -Raw | ConvertFrom-Json
$StagedUsers = Get-ChildItem (Join-Path $PublicStaging "StagedFiles") -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

$MatchFound = $false; $MatchedOldUser = ""
foreach ($oldUser in $StagedUsers) {
    if ($env:USERNAME -match $oldUser -or $oldUser -match $env:USERNAME) { $MatchFound = $true; $MatchedOldUser = $oldUser; break }
}

if ($MatchFound) {
    $Blocker = New-Object System.Windows.Forms.Form
    $Blocker.FormBorderStyle = 'None'; $Blocker.WindowState = 'Maximized'; $Blocker.TopMost = $true; $Blocker.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#005a9e"); $Blocker.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $MainLabel = New-Object System.Windows.Forms.Label; $MainLabel.Text = "Setting things up for you..."; $MainLabel.ForeColor = [System.Drawing.Color]::White; $MainLabel.Font = New-Object System.Drawing.Font("Segoe UI Light", 32); $MainLabel.AutoSize = $false; $MainLabel.Dock = 'Fill'; $MainLabel.TextAlign = 'MiddleCenter'
    $Blocker.Controls.Add($MainLabel)
    $SubLabel = New-Object System.Windows.Forms.Label; $SubLabel.Text = "Please wait while we integrate your profile. This might take a few minutes."; $SubLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#cce4f7"); $SubLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12); $SubLabel.AutoSize = $false; $SubLabel.Height = 100; $SubLabel.Dock = 'Bottom'; $SubLabel.TextAlign = 'MiddleCenter'
    $Blocker.Controls.Add($SubLabel)
    $Blocker.Show(); [System.Windows.Forms.Application]::DoEvents()
    function Update-UI([string]$text) { $SubLabel.Text = $text; [System.Windows.Forms.Application]::DoEvents() }

    # 1. Inject Credentials
    Update-UI "Restoring Windows credentials..."
    $CredFile = Join-Path $PublicStaging "Windows_Credentials.csv"
    if (Test-Path $CredFile) {
        Import-Csv -Path $CredFile -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Target -ne "Error") { Start-Process cmd.exe -ArgumentList "/c cmdkey /add:`"$($_.Target)`" /user:`"$($_.Username)`" /pass:`"$($_.Password)`"" -WindowStyle Hidden -Wait }
        }
    }

    # 2. File Move
    Update-UI "Copying files and documents..."
    $Src = Join-Path $PublicStaging "StagedFiles\$MatchedOldUser"
    Start-Process robocopy -ArgumentList "`"$Src`" `"$env:USERPROFILE`" /E /MOVE /IS /IT /MT:16 /NFL /NDL /NJH /NJS /nc /ns /np" -WindowStyle Hidden -Wait

    # 3. Wi-Fi Profiles
    $WifiDir = Join-Path $PublicStaging "WiFi_Profiles"
    if (Test-Path $WifiDir) {
        Update-UI "Reconnecting Wi-Fi profiles..."
        Get-ChildItem -Path $WifiDir -Filter "*.xml" | ForEach-Object { Start-Process cmd.exe -ArgumentList "/c netsh wlan add profile filename=`"$($_.FullName)`" user=all" -WindowStyle Hidden -Wait }
    }

    # 4. Drivers & Printers
    $DriverFolder = Join-Path $PublicStaging "ExportedDrivers"
    if (Test-Path $DriverFolder) {
        Update-UI "Installing hardware drivers..."
        Start-Process pnputil.exe -ArgumentList "/add-driver `"$DriverFolder\*.inf`" /subdirs /install" -WindowStyle Hidden -Wait
    }

    # 5. Registry & Themes
    Update-UI "Applying personalization and taskbar settings..."
    $uSettings = $JsonConfig.Settings.$MatchedOldUser
    if ($null -ne $uSettings.AppsUseLightTheme) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -Value $uSettings.AppsUseLightTheme -ErrorAction SilentlyContinue }
    if ($null -ne $uSettings.SystemUsesLightTheme) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name SystemUsesLightTheme -Value $uSettings.SystemUsesLightTheme -ErrorAction SilentlyContinue }
    if ($null -ne $uSettings.ColorPrevalence) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name ColorPrevalence -Value $uSettings.ColorPrevalence -ErrorAction SilentlyContinue }
    if ($null -ne $uSettings.TaskbarAl) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarAl -Value $uSettings.TaskbarAl -ErrorAction SilentlyContinue }
    if ($null -ne $uSettings.ShowTaskViewButton) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -Value $uSettings.ShowTaskViewButton -ErrorAction SilentlyContinue }
    if ($null -ne $uSettings.TaskbarDa) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarDa -Value $uSettings.TaskbarDa -ErrorAction SilentlyContinue }
    if ($null -ne $uSettings.SearchboxTaskbarMode) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -Value $uSettings.SearchboxTaskbarMode -ErrorAction SilentlyContinue }

    # 6. Desktop Icons
    $IconReg = Join-Path $PublicStaging "DesktopIcons_$MatchedOldUser.reg"
    if (Test-Path $IconReg) {
        Start-Process reg.exe -ArgumentList "import `"$IconReg`"" -WindowStyle Hidden -Wait
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; Start-Process explorer.exe
    }

    if ($uSettings.MappedDrives) {
        foreach ($drive in $uSettings.MappedDrives) { Start-Process cmd.exe -ArgumentList "/c net use $($drive.Drive): `"$($drive.Path)`" /persistent:yes" -WindowStyle Hidden }
    }

    # 7. Missing Software Logic
    Update-UI "Analyzing installed software..."
    function Get-UninstallKey($path) {
        $keys = @()
        if (Test-Path "Registry::$path") {
            Get-ChildItem -Path "Registry::$path" -ErrorAction SilentlyContinue | ForEach-Object {
                $name = (Get-ItemProperty -Path $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                if ($name) { $keys += $name }
            }
        }
        return $keys
    }
    
    $CurrentSys = @()
    $CurrentSys += Get-UninstallKey "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $CurrentSys += Get-UninstallKey "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $CurrentUsr = Get-UninstallKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $CurrentAll = $CurrentSys + $CurrentUsr | Select-Object -Unique

    $OldAll = @()
    if ($JsonConfig.SystemSoftware) { $OldAll += $JsonConfig.SystemSoftware }
    if ($JsonConfig.UserSoftware.$MatchedOldUser) { $OldAll += $JsonConfig.UserSoftware.$MatchedOldUser }
    $OldAll = $OldAll | Select-Object -Unique

    $MissingSoftware = @()
    foreach ($oldApp in $OldAll) {
        if ($CurrentAll -notcontains $oldApp) { $MissingSoftware += $oldApp }
    }

    # 8. Drop Recovery Info Folder
    Update-UI "Finalizing..."
    $InfoDrop = Join-Path -Path [Environment]::GetFolderPath('Desktop') -ChildPath "Migration_Recovery_Info"
    New-Item -ItemType Directory -Path $InfoDrop -Force | Out-Null
    
    if (Test-Path $CredFile) { Copy-Item $CredFile -Destination $InfoDrop -Force -ErrorAction SilentlyContinue }
    $ChromeCsv = Join-Path $PublicStaging "Chrome_Passwords_$MatchedOldUser.csv"
    if (Test-Path $ChromeCsv) { Copy-Item $ChromeCsv -Destination $InfoDrop -Force -ErrorAction SilentlyContinue }

    $ReadmeContent = @"
MIGRATION RECOVERY FOLDER

1. MISSING SOFTWARE:
If any software was present on the old computer but is missing here, it is listed below.
You will need to reinstall these programs manually.

2. BROWSER PASSWORDS:
To import browser passwords into Chrome or Edge:
- Go to Settings -> Password Manager.
- Click the three dots (More Actions) next to "Saved Passwords".
- Select "Import Passwords" and choose the CSV file in this folder.

3. WINDOWS CREDENTIALS:
Your Windows network passwords and VPN profiles have ALREADY been natively restored!

You may delete this folder once you have imported what you need.
--------------------------------------------------------------
MISSING SOFTWARE LIST:
"@
    foreach ($app in $MissingSoftware) { $ReadmeContent += "`n- $app" }
    $ReadmeContent | Out-File (Join-Path $InfoDrop "ReadMe.txt") -Encoding ascii

    Remove-Item $Src -Recurse -Force -ErrorAction SilentlyContinue

    Update-UI "Integration Complete! You will be signed out in 5 seconds to apply deep system themes. Please log back in."
    Start-Sleep -Seconds 5
    $Blocker.Close()
    
    # Force logoff to guarantee taskbar/themes fully reload
    Start-Process logoff.exe -WindowStyle Hidden
}

$Remaining = Get-ChildItem (Join-Path $PublicStaging "StagedFiles") -Directory -ErrorAction SilentlyContinue
if (-not $Remaining) {
    Start-Process schtasks.exe -ArgumentList "/delete /tn `"WindowsSetupIntegration`" /f" -WindowStyle Hidden -Wait
    Start-Process cmd.exe -ArgumentList "/c rmdir /s /q `"$PublicStaging`"" -WindowStyle Hidden
}
