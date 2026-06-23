# User Move Tool - Tyler Hatfield - v2.1

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$MicroLoader = New-Object System.Windows.Forms.Form
$MicroLoader.ClientSize = New-Object System.Drawing.Size(220, 40)
$MicroLoader.StartPosition = 'CenterScreen'
$MicroLoader.FormBorderStyle = 'None'
$MicroLoader.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
$loadLabel = New-Object System.Windows.Forms.Label
$loadLabel.Text = "Loading Migration Tool..."
$loadLabel.ForeColor = [System.Drawing.Color]::White
$loadLabel.Dock = 'Fill'; $loadLabel.TextAlign = 'MiddleCenter'
$MicroLoader.Controls.Add($loadLabel)
$MicroLoader.Show() | Out-Null
[System.Windows.Forms.Application]::DoEvents()

$OSVersion = [System.Environment]::OSVersion.Version
$global:TempUserMoveLog = Join-Path $env:TEMP "Hats-UserMove-Log.txt"

function Log-Message {
    param( [string]$message, [string]$level = "Info" )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$level] - $message" | Out-File -FilePath $global:TempUserMoveLog -Append
    if ($Script:LogBox) {
        $Script:LogBox.AppendText("[$level] $message`n")
        $Script:LogBox.ScrollToCaret()
    }
}

$NativeDll = Join-Path $PSScriptRoot "HMTUserMoveNative.dll"
if (Test-Path $NativeDll) { Add-Type -Path $NativeDll -ErrorAction Stop }

[HMTUserMoveNative.UIHelpers]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

$MoveGUI = New-Object System.Windows.Forms.Form
$MoveGUI.Text = "Hat's User Migration Tool"
$MoveGUI.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
$MoveGUI.ClientSize = New-Object System.Drawing.Size(500, 800)
$MoveGUI.StartPosition = 'CenterScreen'
$MoveGUI.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$MoveGUI.MaximizeBox = $false
$MoveGUI.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$MoveGUI.Handle | Out-Null
$darkMode = 1
[HMTUserMoveNative.UIHelpers]::DwmSetWindowAttribute($MoveGUI.Handle, 20, [ref]$darkMode, 4) | Out-Null

$BackupTabBtn = New-Object System.Windows.Forms.Button
$BackupTabBtn.Text = "Backup (Export)"
$BackupTabBtn.Location = New-Object System.Drawing.Point(10, 10)
$BackupTabBtn.Size = New-Object System.Drawing.Size(240, 40)
$BackupTabBtn.FlatStyle = 'Flat'
$BackupTabBtn.FlatAppearance.BorderSize = 0
$BackupTabBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#36393f")
$BackupTabBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
$MoveGUI.Controls.Add($BackupTabBtn)

$RestoreTabBtn = New-Object System.Windows.Forms.Button
$RestoreTabBtn.Text = "Restore (Import)"
$RestoreTabBtn.Location = New-Object System.Drawing.Point(250, 10)
$RestoreTabBtn.Size = New-Object System.Drawing.Size(240, 40)
$RestoreTabBtn.FlatStyle = 'Flat'
$RestoreTabBtn.FlatAppearance.BorderSize = 0
$RestoreTabBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
$RestoreTabBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#808080")
$MoveGUI.Controls.Add($RestoreTabBtn)

$BackupPanel = New-Object System.Windows.Forms.Panel
$BackupPanel.Location = New-Object System.Drawing.Point(10, 50)
$BackupPanel.Size = New-Object System.Drawing.Size(480, 540)
$BackupPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#36393f")
$MoveGUI.Controls.Add($BackupPanel)

$RestorePanel = New-Object System.Windows.Forms.Panel
$RestorePanel.Location = New-Object System.Drawing.Point(10, 50)
$RestorePanel.Size = New-Object System.Drawing.Size(480, 540)
$RestorePanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#36393f")
$RestorePanel.Visible = $false
$MoveGUI.Controls.Add($RestorePanel)

$BackupTabBtn.Add_Click({
    $BackupPanel.Visible = $true
    $RestorePanel.Visible = $false
    $BackupTabBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#36393f")
    $BackupTabBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
    $RestoreTabBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
    $RestoreTabBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#808080")
})

$RestoreTabBtn.Add_Click({
    $RestorePanel.Visible = $true
    $BackupPanel.Visible = $false
    $RestoreTabBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#36393f")
    $RestoreTabBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
    $BackupTabBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
    $BackupTabBtn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#808080")
})

# -- BACKUP TAB --

$BPathLabel = New-Object System.Windows.Forms.Label
$BPathLabel.Text = "Destination Folder:"
$BPathLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
$BPathLabel.Location = New-Object System.Drawing.Point(10, 15); $BPathLabel.AutoSize = $true
$BackupPanel.Controls.Add($BPathLabel)

$BMediaLabel = New-Object System.Windows.Forms.Label
$BMediaLabel.Text = ""
$BMediaLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#a0a0a0")
$BMediaLabel.Location = New-Object System.Drawing.Point(150, 15); $BMediaLabel.AutoSize = $true
$BackupPanel.Controls.Add($BMediaLabel)

$BPathTextBox = New-Object System.Windows.Forms.TextBox
$BPathTextBox.Location = New-Object System.Drawing.Point(10, 40); $BPathTextBox.Width = 360
$BackupPanel.Controls.Add($BPathTextBox)

$BBrowseButton = New-Object System.Windows.Forms.Button
$BBrowseButton.Text = "Browse"
$BBrowseButton.Location = New-Object System.Drawing.Point(380, 38); $BBrowseButton.Size = New-Object System.Drawing.Size(80, 27)
$BBrowseButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
$BBrowseButton.FlatStyle = 'Flat'
$BBrowseButton.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($fbd.ShowDialog() -eq 'OK') { $BPathTextBox.Text = $fbd.SelectedPath }
    })
$BackupPanel.Controls.Add($BBrowseButton)

$BPathTextBox.Add_TextChanged({
        if (Test-Path $BPathTextBox.Text) {
            try {
                $DriveLetter = (Split-Path $BPathTextBox.Text -Qualifier).TrimEnd(':')
                $Disk = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue
                if ($Disk) {
                    if ($Disk.BusType -eq "USB") { $BMediaLabel.ForeColor = [System.Drawing.Color]::Yellow; $BMediaLabel.Text = "Media: USB (Verify it is USB 3.0+)" }
                    elseif ($Disk.MediaType -eq "HDD") { $BMediaLabel.ForeColor = [System.Drawing.Color]::Orange; $BMediaLabel.Text = "Warning: HDD Detected (Slow Transfer)" }
                    else { $BMediaLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#43b581"); $BMediaLabel.Text = "Media: $($Disk.MediaType) ($($Disk.BusType))" }
                }
            }
            catch { $BMediaLabel.Text = "" }
        }
    })

$UserListBox = New-Object System.Windows.Forms.CheckedListBox
$UserListBox.Location = New-Object System.Drawing.Point(10, 85); $UserListBox.Size = New-Object System.Drawing.Size(450, 80)
$UserListBox.CheckOnClick = $true; $UserListBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#40444b"); $UserListBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
$BackupPanel.Controls.Add($UserListBox)

$LocalUsers = Get-ChildItem -Path "C:\Users" -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
foreach ($u in $LocalUsers) {
    $idx = $UserListBox.Items.Add($u.Name)
    if ($u.Name -eq $env:USERNAME) { $UserListBox.SetItemChecked($idx, $true) }
}

$y = 175
$chkRoot = New-Object System.Windows.Forms.CheckBox; $chkRoot.Text = "C:\ Root Data (Excl. Windows/ProgFiles)"; $chkRoot.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkRoot.Location = New-Object System.Drawing.Point(20, $y); $chkRoot.Width = 400; $chkRoot.Checked = $true; $BackupPanel.Controls.Add($chkRoot); $y += 25
$chkUser = New-Object System.Windows.Forms.CheckBox; $chkUser.Text = "Selected User Profiles (Excl. Cloud Sync)"; $chkUser.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkUser.Location = New-Object System.Drawing.Point(20, $y); $chkUser.Width = 400; $chkUser.Checked = $true; $BackupPanel.Controls.Add($chkUser); $y += 25
$chkBrowsers = New-Object System.Windows.Forms.CheckBox; $chkBrowsers.Text = "Browser Data (Bookmarks, History, Extensions)"; $chkBrowsers.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkBrowsers.Location = New-Object System.Drawing.Point(20, $y); $chkBrowsers.Width = 400; $chkBrowsers.Checked = $true; $BackupPanel.Controls.Add($chkBrowsers); $y += 25
$chkSettings = New-Object System.Windows.Forms.CheckBox; $chkSettings.Text = "OS Settings, Printers, Taskbar && Wi-Fi Profiles"; $chkSettings.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkSettings.Location = New-Object System.Drawing.Point(20, $y); $chkSettings.Width = 400; $chkSettings.Checked = $true; $BackupPanel.Controls.Add($chkSettings); $y += 25
$chkSoftware = New-Object System.Windows.Forms.CheckBox; $chkSoftware.Text = "Generate Missing Software Report"; $chkSoftware.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkSoftware.Location = New-Object System.Drawing.Point(20, $y); $chkSoftware.Width = 400; $chkSoftware.Checked = $true; $BackupPanel.Controls.Add($chkSoftware); $y += 25
$chkDrivers = New-Object System.Windows.Forms.CheckBox; $chkDrivers.Text = "Extract 3rd Party Drivers (Takes a while)"; $chkDrivers.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkDrivers.Location = New-Object System.Drawing.Point(20, $y); $chkDrivers.Width = 400; $chkDrivers.Checked = $false; $BackupPanel.Controls.Add($chkDrivers); $y += 25
$chkCreds = New-Object System.Windows.Forms.CheckBox; $chkCreds.Text = "Extract Win Credentials && Browser Passwords"; $chkCreds.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkCreds.Location = New-Object System.Drawing.Point(20, $y); $chkCreds.Width = 400; $chkCreds.Checked = $false; $BackupPanel.Controls.Add($chkCreds); $y += 25
$chkIntegrity = New-Object System.Windows.Forms.CheckBox; $chkIntegrity.Text = "Perform Post-Transfer File Integrity Check"; $chkIntegrity.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $chkIntegrity.Location = New-Object System.Drawing.Point(20, $y); $chkIntegrity.Width = 400; $chkIntegrity.Checked = $true; $BackupPanel.Controls.Add($chkIntegrity)

$StartBackupBtn = New-Object System.Windows.Forms.Button
$StartBackupBtn.Text = "Start Backup"
$StartBackupBtn.Location = New-Object System.Drawing.Point(10, 480)
$StartBackupBtn.Size = New-Object System.Drawing.Size(350, 40)
$StartBackupBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
$StartBackupBtn.ForeColor = [System.Drawing.Color]::White; $StartBackupBtn.FlatStyle = 'Flat'
$BackupPanel.Controls.Add($StartBackupBtn)

$CancelBackupBtn = New-Object System.Windows.Forms.Button
$CancelBackupBtn.Text = "Cancel"
$CancelBackupBtn.Location = New-Object System.Drawing.Point(370, 480); $CancelBackupBtn.Size = New-Object System.Drawing.Size(90, 40)
$CancelBackupBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#b33232"); $CancelBackupBtn.ForeColor = [System.Drawing.Color]::White; $CancelBackupBtn.FlatStyle = 'Flat'
$CancelBackupBtn.Enabled = $false
$BackupPanel.Controls.Add($CancelBackupBtn)

# -- RESTORE TAB --

$RPathTextBox = New-Object System.Windows.Forms.TextBox
$RPathTextBox.Location = New-Object System.Drawing.Point(10, 40); $RPathTextBox.Width = 360
$RestorePanel.Controls.Add($RPathTextBox)

$RBrowseButton = New-Object System.Windows.Forms.Button
$RBrowseButton.Text = "Browse"
$RBrowseButton.Location = New-Object System.Drawing.Point(380, 38); $RBrowseButton.Size = New-Object System.Drawing.Size(80, 27)
$RBrowseButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $RBrowseButton.FlatStyle = 'Flat'
$RBrowseButton.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($fbd.ShowDialog() -eq 'OK') { $RPathTextBox.Text = $fbd.SelectedPath }
    })
$RestorePanel.Controls.Add($RBrowseButton)

$RUserListBox = New-Object System.Windows.Forms.CheckedListBox
$RUserListBox.Location = New-Object System.Drawing.Point(10, 85); $RUserListBox.Size = New-Object System.Drawing.Size(450, 150)
$RUserListBox.CheckOnClick = $true; $RUserListBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#40444b"); $RUserListBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
$RestorePanel.Controls.Add($RUserListBox)

$StartRestoreBtn = New-Object System.Windows.Forms.Button
$StartRestoreBtn.Text = "Stage Migration Data"
$StartRestoreBtn.Location = New-Object System.Drawing.Point(10, 250); $StartRestoreBtn.Size = New-Object System.Drawing.Size(450, 40)
$StartRestoreBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136"); $StartRestoreBtn.ForeColor = [System.Drawing.Color]::White; $StartRestoreBtn.FlatStyle = 'Flat'
$RestorePanel.Controls.Add($StartRestoreBtn)

# -- COMMON ELEMENTS --
$ProgressLabel = New-Object System.Windows.Forms.Label
$ProgressLabel.Text = "Ready"
$ProgressLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9")
$ProgressLabel.Location = New-Object System.Drawing.Point(10, 600); $ProgressLabel.AutoSize = $true
$MoveGUI.Controls.Add($ProgressLabel)

$TrackPanel = New-Object System.Windows.Forms.Panel
$TrackPanel.Location = New-Object System.Drawing.Point(10, 625); $TrackPanel.Size = New-Object System.Drawing.Size(480, 20); $TrackPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#40444b")
$MoveGUI.Controls.Add($TrackPanel)

$FillPanel = New-Object System.Windows.Forms.Panel
$FillPanel.Location = New-Object System.Drawing.Point(0, 0); $FillPanel.Size = New-Object System.Drawing.Size(0, 20); $FillPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#43b581")
$TrackPanel.Controls.Add($FillPanel)

$Script:LogBox = New-Object System.Windows.Forms.RichTextBox
$Script:LogBox.Location = New-Object System.Drawing.Point(10, 655); $Script:LogBox.Size = New-Object System.Drawing.Size(480, 130)
$Script:LogBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#202225"); $Script:LogBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#d9d9d9"); $Script:LogBox.ReadOnly = $true
$MoveGUI.Controls.Add($Script:LogBox)

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 500

$Global:AbortOperation = $false

$CancelBackupBtn.Add_Click({
        $Global:AbortOperation = $true
        Log-Message "Aborting operation... Killing background processes." "Warning"
        Get-Process -Name "robocopy" -ErrorAction SilentlyContinue | Stop-Process -Force
    })

# ---------------------------------------------------------------------------
# Backup Logic
# ---------------------------------------------------------------------------
$StartBackupBtn.Add_Click({
        if (-not (Test-Path $BPathTextBox.Text)) { [System.Windows.Forms.MessageBox]::Show("Invalid destination.", "Error", 0, 16); return }
        $ActiveUsers = @()
        foreach ($item in $UserListBox.CheckedItems) { $ActiveUsers += $item }
        if ($ActiveUsers.Count -eq 0 -and ($chkUser.Checked -or $chkBrowsers.Checked)) { return }

        $StartBackupBtn.Enabled = $false; $BackupTabBtn.Enabled = $false; $RestoreTabBtn.Enabled = $false; $CancelBackupBtn.Enabled = $true
        $Global:AbortOperation = $false
        $FillPanel.Width = 0

        $DestRoot = Join-Path $BPathTextBox.Text "HMT_Migration_$(Get-Date -Format 'yyyyMMdd_HHmm')"
        New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
        $DataRoot = Join-Path $DestRoot "C_Drive"
        New-Item -ItemType Directory -Path $DataRoot -Force | Out-Null

        $JsonConfig = @{ OSBuild = $OSVersion.Build; UsersBackedUp = $ActiveUsers; Domain = $env:USERDOMAIN; Settings = @{}; SystemSoftware = @(); UserSoftware = @{} }

        Log-Message "Indexing files..."
        $FoldersToScan = @()
        if ($chkRoot.Checked) { Get-ChildItem -Path "C:\" -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('Windows', 'Program Files', 'Program Files (x86)', 'PerfLogs', '$Recycle.Bin', 'System Volume Information') } | ForEach-Object { $FoldersToScan += $_.FullName } }

        foreach ($u in $ActiveUsers) {
            $UserRoot = "C:\Users\$u"
            if ($chkUser.Checked) {
                $UserFolders = @('Desktop', 'Documents', 'Downloads', 'Music', 'Pictures', 'Videos', 'Favorites')
                foreach ($uf in $UserFolders) { $p = Join-Path $UserRoot $uf; if (Test-Path $p) { $FoldersToScan += $p } }
                $FoldersToScan += "$UserRoot\AppData\Roaming\Microsoft\Signatures"
                $FoldersToScan += "$UserRoot\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"
                $FoldersToScan += "$UserRoot\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
            }
            if ($chkBrowsers.Checked) {
                if (Test-Path "$UserRoot\AppData\Local\Google\Chrome\User Data") { $FoldersToScan += "$UserRoot\AppData\Local\Google\Chrome\User Data" }
                if (Test-Path "$UserRoot\AppData\Local\Microsoft\Edge\User Data") { $FoldersToScan += "$UserRoot\AppData\Local\Microsoft\Edge\User Data" }
                if (Test-Path "$UserRoot\AppData\Roaming\Mozilla\Firefox\Profiles") { $FoldersToScan += "$UserRoot\AppData\Roaming\Mozilla\Firefox" }
            }
        }

        $ProgressLabel.Text = "Calculating Backup Size (This may take a minute)..."
        [System.Windows.Forms.Application]::DoEvents()
        $TotalBytes = 0; $ValidFolders = @(); $dots = 0
        foreach ($folder in $FoldersToScan) {
            if (-not (Test-Path $folder)) { continue }
            if ($folder -match "OneDrive|SharePoint|Dropbox|Google Drive") { continue }
            
            $shortName = Split-Path $folder -Leaf
            if ($folder -match "^C:\\Users\\([^\\]+)\\") {
                $uName = $matches[1]
                $ProgressLabel.Text = "Indexing $uName\$shortName" + ("." * (($dots % 3) + 1))
            } else {
                $ProgressLabel.Text = "Indexing $shortName" + ("." * (($dots % 3) + 1))
            }
            [System.Windows.Forms.Application]::DoEvents()
            $dots++

            $found = Get-ChildItem -Path $folder -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "OneDrive|SharePoint|Dropbox" }
            if ($found) { $TotalBytes += ($found | Measure-Object -Property Length -Sum).Sum; $ValidFolders += $folder }
        }

        if ($TotalBytes -gt 50GB) {
            $msgRes = [System.Windows.Forms.MessageBox]::Show("The backup is $([math]::Round($TotalBytes/1GB, 2)) GB. Continue?", "Large Backup", 4, 48)
            if ($msgRes -eq 'No') { $StartBackupBtn.Enabled = $true; $BackupTabBtn.Enabled = $true; $RestoreTabBtn.Enabled = $true; $CancelBackupBtn.Enabled = $false; return }
        }

        if ($chkSoftware.Checked) {
            Log-Message "Extracting Installed Software Lists..."
            function Get-UninstallKey($path) {
                if (Test-Path "Registry::$path") {
                    Get-ChildItem -Path "Registry::$path" -ErrorAction SilentlyContinue | ForEach-Object {
                        $name = (Get-ItemProperty -Path $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                        if ($name) { $name }
                    }
                }
            }
            $JsonConfig.SystemSoftware += Get-UninstallKey "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            $JsonConfig.SystemSoftware += Get-UninstallKey "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            $JsonConfig.SystemSoftware = $JsonConfig.SystemSoftware | Select-Object -Unique
        }

        if ($chkSettings.Checked) {
            Log-Message "Exporting OS Settings, Printers, Wi-Fi..."
            $JsonConfig.Printers = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "Microsoft|OneNote|PDF|XPS|Root" } | Select-Object Name, DriverName, PortName, Shared
        
            # Wi-Fi Export
            $WifiDir = Join-Path $DestRoot "WiFi_Profiles"
            New-Item -ItemType Directory -Path $WifiDir -Force | Out-Null
            Start-Process cmd.exe -ArgumentList "/c netsh wlan export profile key=clear folder=`"$WifiDir`"" -WindowStyle Hidden -Wait

            foreach ($u in $ActiveUsers) {
                $JsonConfig.Settings.$u = @{}
                try {
                    $objUser = New-Object System.Security.Principal.NTAccount($u)
                    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier]).Value
                    $RegLoadedHere = $false
                    if (-not (Test-Path "Registry::HKEY_USERS\$strSID")) {
                        Start-Process cmd.exe -ArgumentList "/c reg load `"HKU\TempHive_$u`" `"C:\Users\$u\NTUSER.DAT`"" -NoNewWindow -Wait
                        $TargetHive = "Registry::HKEY_USERS\TempHive_$u"
                        $RegLoadedHere = $true
                    }
                    else { $TargetHive = "Registry::HKEY_USERS\$strSID" }

                    if ($chkSoftware.Checked) {
                        $JsonConfig.UserSoftware.$u = @()
                        $JsonConfig.UserSoftware.$u += Get-UninstallKey "$TargetHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                    }

                    $ThemeKey = "$TargetHive\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                    $JsonConfig.Settings.$u.AppsUseLightTheme = (Get-ItemProperty -Path $ThemeKey -Name AppsUseLightTheme -ErrorAction SilentlyContinue).AppsUseLightTheme
                    $JsonConfig.Settings.$u.SystemUsesLightTheme = (Get-ItemProperty -Path $ThemeKey -Name SystemUsesLightTheme -ErrorAction SilentlyContinue).SystemUsesLightTheme
                    $JsonConfig.Settings.$u.ColorPrevalence = (Get-ItemProperty -Path $ThemeKey -Name ColorPrevalence -ErrorAction SilentlyContinue).ColorPrevalence
                
                    $TBKey = "$TargetHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    $JsonConfig.Settings.$u.TaskbarAl = (Get-ItemProperty -Path $TBKey -Name TaskbarAl -ErrorAction SilentlyContinue).TaskbarAl
                    $JsonConfig.Settings.$u.ShowTaskViewButton = (Get-ItemProperty -Path $TBKey -Name ShowTaskViewButton -ErrorAction SilentlyContinue).ShowTaskViewButton
                    $JsonConfig.Settings.$u.TaskbarDa = (Get-ItemProperty -Path $TBKey -Name TaskbarDa -ErrorAction SilentlyContinue).TaskbarDa
                
                    $SearchKey = "$TargetHive\Software\Microsoft\Windows\CurrentVersion\Search"
                    $JsonConfig.Settings.$u.SearchboxTaskbarMode = (Get-ItemProperty -Path $SearchKey -Name SearchboxTaskbarMode -ErrorAction SilentlyContinue).SearchboxTaskbarMode

                    $BagsKey = "$TargetHive\Software\Microsoft\Windows\Shell\Bags\1\Desktop"
                    if (Test-Path $BagsKey) {
                        $RegExportFile = Join-Path $DestRoot "DesktopIcons_$u.reg"
                        Start-Process cmd.exe -ArgumentList "/c reg export `"$BagsKey`" `"$RegExportFile`" /y" -WindowStyle Hidden -Wait
                    }

                    $NetworkKey = "$TargetHive\Network"
                    $Drives = @()
                    if (Test-Path $NetworkKey) {
                        Get-ChildItem -Path $NetworkKey -ErrorAction SilentlyContinue | ForEach-Object {
                            $RemotePath = (Get-ItemProperty -Path $_.PSPath -Name RemotePath -ErrorAction SilentlyContinue).RemotePath
                            $Drives += @{ Drive = $_.PSChildName; Path = $RemotePath }
                        }
                    }
                    $JsonConfig.Settings.$u.MappedDrives = $Drives

                    if ($RegLoadedHere) {
                        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                        Start-Process cmd.exe -ArgumentList "/c reg unload `"HKU\TempHive_$u`"" -NoNewWindow -Wait
                    }
                }
                catch {}
            }

            # PC Specs Generation
            $ProgressLabel.Text = "Generating PC Specs report..."
            [System.Windows.Forms.Application]::DoEvents()
            $BIOS = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
            $CS = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
            "PC Name: $($CS.Name)`nModel: $($CS.Model)`nManufacturer: $($CS.Manufacturer)`nSerial Number: $($BIOS.SerialNumber)" | Out-File (Join-Path $DestRoot "PC_Specs.txt")
        }

        if ($chkCreds.Checked) {
            Log-Message "Extracting Credentials..."
            $ProgressLabel.Text = "Extracting Credentials..."
            [System.Windows.Forms.Application]::DoEvents()

            $SqliteDllPath = Join-Path $env:TEMP "System.Data.SQLite.dll"
            $LocalDll = Join-Path $PSScriptRoot "System.Data.SQLite.dll"
            
            if (Test-Path $LocalDll) {
                $SqliteDllPath = $LocalDll
            } else {
                $SQLiteUrl = "https://www.nuget.org/api/v2/package/System.Data.SQLite.Core/1.0.118"
                try {
                    if (-not (Test-Path $SqliteDllPath)) {
                        $ZipPath = Join-Path $env:TEMP "sqlite.zip"
                        Invoke-WebRequest -Uri $SQLiteUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
                        Expand-Archive -Path $ZipPath -DestinationPath (Join-Path $env:TEMP "sqlite_extract") -Force
                        Copy-Item (Join-Path $env:TEMP "sqlite_extract\lib\net46\System.Data.SQLite.dll") -Destination $SqliteDllPath -Force
                        Remove-Item $ZipPath -Force; Remove-Item (Join-Path $env:TEMP "sqlite_extract") -Recurse -Force
                    }
                }
                catch { Log-Message "Failed to download SQLite. Browser passwords will be skipped." "Error" }
            }

            try {
                $csv = [HMTUserMoveNative.CredentialExtractor]::GetWindowsCredentialsCsv()
                $csv | Out-File (Join-Path $DestRoot "Windows_Credentials.csv") -Encoding UTF8
                
            if (Test-Path $SqliteDllPath) {
                foreach ($u in $ActiveUsers) {
                    $LocalState = "C:\Users\$u\AppData\Local\Google\Chrome\User Data\Local State"
                    $LoginData = "C:\Users\$u\AppData\Local\Google\Chrome\User Data\Default\Login Data"
                    if ((Test-Path $LocalState) -and (Test-Path $LoginData)) {
                            
                        $ChromeCsv = ""
                        if ($u -eq $env:USERNAME) {
                            $ChromeCsv = [HMTUserMoveNative.CredentialExtractor]::GetChromiumPasswordsCsv($LocalState, $LoginData, $SqliteDllPath)
                        }
                        else {
                            # Prompt for offline user password
                            $PassPrompt = New-Object System.Windows.Forms.Form
                            $PassPrompt.Text = "Offline User Credentials"
                            $PassPrompt.Size = New-Object System.Drawing.Size(400, 200)
                            $PassPrompt.StartPosition = 'CenterScreen'
                            $PassPrompt.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2f3136")
                            $PassPrompt.FormBorderStyle = 'FixedDialog'
                            $PassPrompt.MaximizeBox = $false
                            $PassPrompt.MinimizeBox = $false

                            $lbl = New-Object System.Windows.Forms.Label
                            $lbl.Text = "User '$u' is offline. To extract their browser passwords, please enter their Windows password. Leave blank to skip."
                            $lbl.Location = New-Object System.Drawing.Point(10, 10)
                            $lbl.Size = New-Object System.Drawing.Size(360, 50)
                            $lbl.ForeColor = [System.Drawing.Color]::White
                            $PassPrompt.Controls.Add($lbl)

                            $txtPass = New-Object System.Windows.Forms.TextBox
                            $txtPass.Location = New-Object System.Drawing.Point(10, 70)
                            $txtPass.Size = New-Object System.Drawing.Size(360, 25)
                            $txtPass.PasswordChar = '*'
                            $PassPrompt.Controls.Add($txtPass)

                            $btnOk = New-Object System.Windows.Forms.Button
                            $btnOk.Text = "Submit"
                            $btnOk.Location = New-Object System.Drawing.Point(10, 110)
                            $btnOk.Size = New-Object System.Drawing.Size(170, 30)
                            $btnOk.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#7289da")
                            $btnOk.ForeColor = [System.Drawing.Color]::White
                            $btnOk.FlatStyle = 'Flat'
                            $btnOk.DialogResult = 'OK'
                            $PassPrompt.Controls.Add($btnOk)

                            $btnSkip = New-Object System.Windows.Forms.Button
                            $btnSkip.Text = "Skip"
                            $btnSkip.Location = New-Object System.Drawing.Point(200, 110)
                            $btnSkip.Size = New-Object System.Drawing.Size(170, 30)
                            $btnSkip.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#f04747")
                            $btnSkip.ForeColor = [System.Drawing.Color]::White
                            $btnSkip.FlatStyle = 'Flat'
                            $btnSkip.DialogResult = 'Cancel'
                            $PassPrompt.Controls.Add($btnSkip)

                            $PassPrompt.AcceptButton = $btnOk

                            while ($true) {
                                $res = $PassPrompt.ShowDialog()
                                if ($res -eq 'OK' -and -not [string]::IsNullOrWhiteSpace($txtPass.Text)) {
                                    $ChromeCsv = [HMTUserMoveNative.CredentialExtractor]::GetChromiumPasswordsImpersonated($LocalState, $LoginData, $SqliteDllPath, $env:USERDOMAIN, $u, $txtPass.Text)
                                    if ($ChromeCsv -match "LogonUser Failed") {
                                        [System.Windows.Forms.MessageBox]::Show("Incorrect password. Please try again or click Skip.", "Authentication Failed", 0, 16) | Out-Null
                                        $txtPass.Text = ""
                                        continue
                                    }
                                    break
                                }
                                else {
                                    Log-Message "Skipped DPAPI extraction for user $u." "Warning"
                                    break
                                }
                            }
                            $PassPrompt.Dispose()
                        }

                        if (-not [string]::IsNullOrWhiteSpace($ChromeCsv)) {
                            $ChromeCsv | Out-File (Join-Path $DestRoot "Chrome_Passwords_$u.csv") -Encoding UTF8
                        }
                    }
                }
            }
        }
        catch { Log-Message "Credential Extraction failed: $_" "Warning" }
    }

    $JsonConfig | ConvertTo-Json -Depth 5 | Out-File (Join-Path $DestRoot "Migration.json") -Encoding ascii

    Log-Message "Starting Async Robocopy..."
    $ProgressLabel.Text = "Copying files... 0%"
    $MaxWidth = $TrackPanel.ClientSize.Width

    $Runspace = [runspacefactory]::CreateRunspace(); $Runspace.Open(); $Pipeline = $Runspace.CreatePipeline()
    $Pipeline.Commands.AddScript({
            param($ValidFolders, $DataRoot)
            foreach ($folder in $ValidFolders) {
                $Relative = $folder.Substring(3)
                $TargetDir = Join-Path $DataRoot $Relative
                $Args = @("`"$folder`"", "`"$TargetDir`"", "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:1", "/W:2", "/MT:16", "/XD", "`"OneDrive*`"", "`"SharePoint*`"", "`"Dropbox*`"", "/NFL", "/NDL", "/NJH", "/NJS", "/nc", "/ns", "/np")
                Start-Process robocopy -ArgumentList $Args -WindowStyle Hidden -Wait
            }
        })
    $Pipeline.Commands[0].Parameters.Add("ValidFolders", $ValidFolders); $Pipeline.Commands[0].Parameters.Add("DataRoot", $DataRoot)
    $AsyncResult = $Pipeline.BeginInvoke()

    $Timer.Add_Tick({
            if ($Global:AbortOperation) {
                $Timer.Stop(); $Runspace.Close(); $Runspace.Dispose()
                $ProgressLabel.Text = "Operation Cancelled."
                $StartBackupBtn.Enabled = $true; $BackupTabBtn.Enabled = $true; $RestoreTabBtn.Enabled = $true; $CancelBackupBtn.Enabled = $false
                return
            }

            if ($AsyncResult.IsCompleted) {
                $Timer.Stop()
                $FillPanel.Width = $MaxWidth
            
                if ($chkIntegrity.Checked -and -not $Global:AbortOperation) {
                    $ProgressLabel.Text = "Running File Integrity Validation..."
                    Log-Message "Starting File Integrity Check..."
                    [System.Windows.Forms.Application]::DoEvents()
                    $Failed = 0
                    foreach ($folder in $ValidFolders) {
                        $TargetDir = Join-Path $DataRoot $folder.Substring(3)
                        $SrcCount = (Get-ChildItem $folder -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object).Count
                        $DstCount = (Get-ChildItem $TargetDir -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object).Count
                        if ($SrcCount -ne $DstCount) { $Failed++ }
                    }
                    if ($Failed -gt 0) { 
                        Log-Message "Integrity Warning: $Failed folders had mismatched file counts!" "Warning"
                        "INTEGRITY WARNING: $Failed folders failed to completely transfer after 2 attempts." | Out-File (Join-Path $DataRoot "..\Integrity_Warning.log")
                    }
                    else { Log-Message "Integrity Check Passed!" }
                }

                $ProgressLabel.Text = "Backup Complete!"
                Log-Message "Backup successfully completed."
                $StartBackupBtn.Enabled = $true; $BackupTabBtn.Enabled = $true; $RestoreTabBtn.Enabled = $true; $CancelBackupBtn.Enabled = $false
                $Runspace.Close(); $Runspace.Dispose()
            }
            else {
                if ($TotalBytes -gt 0) {
                    $CurrentBytes = (Get-ChildItem -Path $DataRoot -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    $Percent = [math]::Min([math]::Round(($CurrentBytes / $TotalBytes) * 100), 99)
                    $ProgressLabel.Text = "Copying files... $Percent%"
                    $FillPanel.Width = [int]($MaxWidth * ($Percent / 100))
                }
            }
        })
    $Timer.Start()
})

# ---------------------------------------------------------------------------
# Restore Logic
# ---------------------------------------------------------------------------
$RPathTextBox.Add_TextChanged({
        if (Test-Path $RPathTextBox.Text) {
            $ConfigPath = Join-Path $RPathTextBox.Text "Migration.json"
            if (Test-Path $ConfigPath) {
                $RUserListBox.Items.Clear()
                $JsonConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                if ($JsonConfig.UsersBackedUp) {
                    foreach ($u in $JsonConfig.UsersBackedUp) {
                        $idx = $RUserListBox.Items.Add($u)
                        if ($u -eq $env:USERNAME) { $RUserListBox.SetItemChecked($idx, $true) }
                    }
                }
            }
        }
    })

$StartRestoreBtn.Add_Click({
        if (-not (Test-Path $RPathTextBox.Text)) { return }
        $ActiveRestoreUsers = @(); foreach ($item in $RUserListBox.CheckedItems) { $ActiveRestoreUsers += $item }
        if ($ActiveRestoreUsers.Count -eq 0) { return }

        $StartRestoreBtn.Enabled = $false; $BackupTabBtn.Enabled = $false; $RestoreTabBtn.Enabled = $false
        $PublicStaging = "C:\System_Profile_Migration"
        if (-not (Test-Path $PublicStaging)) { New-Item -ItemType Directory -Path $PublicStaging -Force | Out-Null }
        Start-Process cmd.exe -ArgumentList "/c icacls `"$PublicStaging`" /inheritance:r /grant `"SYSTEM:(OI)(CI)F`" `"Administrators:(OI)(CI)F`" /T /C /Q" -WindowStyle Hidden -Wait

        $ConfigPath = Join-Path $RPathTextBox.Text "Migration.json"
        Copy-Item $ConfigPath -Destination $PublicStaging -Force
        Copy-Item (Join-Path $RPathTextBox.Text "WiFi_Profiles") -Destination $PublicStaging -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item (Join-Path $RPathTextBox.Text "ExportedDrivers") -Destination $PublicStaging -Recurse -Force -ErrorAction SilentlyContinue
    
        # Driver Export Fix
        $DriverDest = Join-Path $RPathTextBox.Text "ExportedDrivers"
        if (-not (Test-Path $DriverDest) -and $chkDrivers.Checked) {
            Log-Message "Exporting 3rd Party Drivers..."
            $ProgressLabel.Text = "Exporting Drivers via DISM (This takes a while)..."
            [System.Windows.Forms.Application]::DoEvents()
            $DriverDestOut = Join-Path $DestRoot "ExportedDrivers"
            New-Item -ItemType Directory -Path $DriverDestOut -Force | Out-Null
            $job = Start-Job { Export-WindowsDriver -Online -Destination $args[0] -ErrorAction SilentlyContinue } -ArgumentList $DriverDestOut
            while ($job.State -eq 'Running') {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 100
            }
            Remove-Job $job -Force
        }

        Copy-Item (Join-Path $RPathTextBox.Text "*.reg") -Destination $PublicStaging -Force -ErrorAction SilentlyContinue
        Copy-Item (Join-Path $RPathTextBox.Text "*.csv") -Destination $PublicStaging -Force -ErrorAction SilentlyContinue

        $DataRoot = Join-Path $RPathTextBox.Text "C_Drive"
        $FilesStaging = Join-Path $PublicStaging "StagedFiles"
        if (-not (Test-Path $FilesStaging)) { New-Item -ItemType Directory -Path $FilesStaging -Force | Out-Null }

        Log-Message "Copying files to Secure Staging..."
        $ProgressLabel.Text = "Staging files... (This may take a while)"
        [System.Windows.Forms.Application]::DoEvents()

        foreach ($u in $ActiveRestoreUsers) {
            $SrcU = Join-Path $DataRoot "Users\$u"
            $DstU = Join-Path $FilesStaging $u
            if (Test-Path $SrcU) { Start-Process robocopy -ArgumentList "`"$SrcU`" `"$DstU`" /E /COPY:DAT /DCOPY:DAT /R:0 /W:0 /MT:16 /NFL /NDL /NJH /NJS /nc /ns /np" -WindowStyle Hidden -Wait }
        }

        Get-ChildItem -Path $DataRoot -Directory | Where-Object { $_.Name -ne "Users" } | ForEach-Object {
            Start-Process robocopy -ArgumentList "`"$($_.FullName)`" `"C:\$($_.Name)`" /E /COPY:DAT /DCOPY:DAT /R:0 /W:0 /MT:16 /NFL /NDL /NJH /NJS /nc /ns /np" -WindowStyle Hidden -Wait
        }

        $PostScriptSrc = Join-Path $PSScriptRoot "UserMoveToolPostRestore.ps1"
        Copy-Item $PostScriptSrc -Destination (Join-Path $PublicStaging "WindowsSetupIntegration.ps1") -Force

        $TaskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>powershell.exe</Command><Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\System_Profile_Migration\WindowsSetupIntegration.ps1"</Arguments></Exec></Actions>
</Task>
"@
        $TaskXMLPath = Join-Path $env:TEMP "MigrationTask.xml"
        $TaskXML | Out-File $TaskXMLPath -Encoding ascii
        Start-Process schtasks.exe -ArgumentList "/create /tn `"WindowsSetupIntegration`" /xml `"$TaskXMLPath`" /f" -WindowStyle Hidden -Wait

        $ProgressLabel.Text = "Restore Staging Complete! Please log off and log in as the user(s) to finalize."
        [System.Windows.Forms.MessageBox]::Show("Staging complete!`nPlease log off and log back in as the migrated user(s). The system will automatically finalize their profile settings upon login.", "Staging Successful", 0, 64)
        $StartRestoreBtn.Enabled = $true; $BackupTabBtn.Enabled = $true; $RestoreTabBtn.Enabled = $true
    })

$MicroLoader.Close(); $MicroLoader.Dispose()
$MoveGUI.ShowDialog() | Out-Null
