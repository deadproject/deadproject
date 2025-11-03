# FixOS Installer PowerShell Script
param(
    [switch]$Install,
    [switch]$Silent
)

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "                          ┌───────────────────────────────────────────────┐"
    Write-Host "                          │                                               │"
    Write-Host "                          │                    FixOS                      │"
    Write-Host "                          │          the Future OS of Windows             │"
    Write-Host "                          │                                               │"
    Write-Host "                          └───────────────────────────────────────────────┘"
    Write-Host ""
    Write-Host "                                 FixOS - the Future OS of Windows"
    Write-Host ""
    Write-Host "                              [1] Install FixOS        [2] Learn More"
    Write-Host ""
    Write-Host "                                             [3] Exit"
    Write-Host ""
    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1" { Install-FixOS }
        "2" { Start-Process "https://github.com/deadproject/FixOs"; Show-Menu }
        "3" { exit }
        default { Write-Host "Invalid selection..."; Pause; Show-Menu }
    }
}

function Install-FixOS {
    param()

    Clear-Host
    if (-not $Silent) { Write-Host "Installing FixOS... (Requires elevation if not already elevated.)" }

    # Auto-elevation (relaunch elevated; pass -Install and -Silent if requested)
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }

    $winPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $winPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        $exe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Install"
        if ($Silent) { $arg += ' -Silent' }
        Start-Process -FilePath $exe -ArgumentList $arg -Verb RunAs -WindowStyle Hidden
        exit
    }

    # Running elevated here.
    $ErrorActionPreference = 'SilentlyContinue'

    Try {
        # Helper to run a command while hiding output
        function Run-Quiet {
            param([ScriptBlock]$Block)
            & $Block *> $null 2>&1
        }

        # 1) Enable .NET Framework 3.5
        Run-Quiet { Start-Process -FilePath dism -ArgumentList '/Online','/Enable-Feature','/FeatureName:NetFx3','/All','/NoRestart' -NoNewWindow -Wait }

        # 2) Configure Maximum Password Age (90 days)
        Run-Quiet { net accounts /maxpwage:90 }

        # 3) Allow execution of PowerShell scripts
        Run-Quiet { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force }

        # 4) Disable Teredo
        Run-Quiet { Start-Process -FilePath netsh -ArgumentList 'interface','teredo','set','state','disabled' -NoNewWindow -Wait }

        # 5) Disable telemetry/data collection (common policies)
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord

        # 6) Disable common telemetry scheduled tasks (silently)
        $tasksToDisable = @(
          '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
          '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
          '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
          '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
          '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
          '\Microsoft\Windows\Autochk\Proxy'
        )
        foreach ($t in $tasksToDisable) { Run-Quiet { schtasks /Change /TN $t /Disable } }

        # 7/8) Enable Ultimate Performance plan, duplicate/rename and set active
        $origGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $dupOut = & powercfg -duplicatescheme $origGuid 2>$null
        $dupText = ($dupOut -join "`n")
        if ($dupText -match '\{([0-9A-Fa-f0-9-]{36})\}') { $newGuid = $matches[1] } else { $newGuid = $origGuid }
        Run-Quiet { & powercfg -changename $newGuid "FixOs Powerplan" }
        Run-Quiet { & powercfg -setactive $newGuid }

        # 9) Set many services startup types
        $svcMap = @{
          'AJRouter'='Disabled'; 'ALG'='Manual'; 'AppIDSvc'='Manual'; 'AppMgmt'='Manual'; 'AppReadiness'='Manual';
          'AppVClient'='Disabled'; 'AppXSvc'='Manual'; 'Appinfo'='Manual'; 'AssignedAccessManagerSvc'='Disabled';
          'AudioEndpointBuilder'='Automatic'; 'AudioSrv'='Automatic'; 'AxInstSV'='Manual'; 'BDESVC'='Manual';
          'BFE'='Automatic'; 'BITS'='Manual'; 'BrokerInfrastructure'='Automatic'; 'Browser'='Manual';
          'CDPSvc'='Manual'; 'ClipSVC'='Manual'; 'CryptSvc'='Automatic'; 'Dhcp'='Automatic';
          'DiagTrack'='Disabled'; 'DoSvc'='Manual'; 'DmEnrollmentSvc'='Manual'; 'Dnscache'='Automatic';
          'DsmSvc'='Manual'; 'EventLog'='Automatic'; 'EventSystem'='Automatic'; 'FontCache'='Automatic';
          'LanmanServer'='Automatic'; 'LanmanWorkstation'='Automatic'; 'MpsSvc'='Automatic'; 'Netlogon'='Automatic';
          'RemoteAccess'='Disabled'; 'RemoteRegistry'='Disabled'; 'RpcSs'='Automatic'; 'Schedule'='Automatic';
          'Spooler'='Automatic'; 'SysMain'='Automatic'; 'TrustedInstaller'='Manual'; 'W32Time'='Manual';
          'WinDefend'='Automatic'; 'Wuauserv'='Manual'
        }
        foreach ($k in $svcMap.Keys) {
          Get-Service -Name $k -ErrorAction SilentlyContinue | ForEach-Object {
            Set-Service -Name $_.Name -StartupType $svcMap[$k] -ErrorAction SilentlyContinue
          }
        }

        # 10/11) Disable Xbox Game DVR/Game Bar
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Type DWord
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -Type DWord
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'BackgroundCaptureEnabled' -Value 0 -Type DWord

        # 12) Disable Background Apps
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Power' -Force | Out-Null
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerFeatures' -Value 1 -Type DWord
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' /v GlobalUserDisabled /t REG_DWORD /d 1 /f }

        # 13) Disable Hibernation
        Run-Quiet { & powercfg -h off }

        # Performance / game mode tweaks
        Run-Quiet { & powercfg -SETACVALUEINDEX $newGuid SUB_PROCESSOR PROCTHROTTLEMAX 100 }
        Run-Quiet { & powercfg -SETACVALUEINDEX $newGuid SUB_VIDEO ADAPTIVE_POWER 0 }

        # 18) Disable Cortana
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 -Type DWord

        # 20) Disable Location Services
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'AllowLocation' -Value 0 -Type DWord

        # 21) Turn off Activity History
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -Type DWord
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0 -Type DWord

        # rest of tweaks
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' /v Enabled /t REG_DWORD /d 0 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting' /v Disabled /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Defender\Spynet' /v SubmitSamplesConsent /t REG_DWORD /d 2 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' /v DisableConsumerFeatures /t REG_DWORD /d 1 /f }

        Run-Quiet { New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Force | Out-Null }
        Run-Quiet { Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0 -Type DWord }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\TouchKeyboard' /v AllowHandwriting /t REG_DWORD /d 0 /f }

        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f }
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f }
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' /v Enabled /t REG_DWORD /d 0 /f }

        Run-Quiet { Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowSearchToUseLocation' -Value 0 -Type DWord }
        Run-Quiet { Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type DWord }

        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\WindowsStore' /v RemoveWindowsStore /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v NoAutoUpdate /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v AUOptions /t REG_DWORD /d 3 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v DeferFeatureUpdates /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v DeferFeatureUpdatesPeriodInDays /t REG_DWORD /d 365 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v DeferQualityUpdates /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v DeferQualityUpdatesPeriodInDays /t REG_DWORD /d 365 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' /v DisableRemoteAssistance /t REG_DWORD /d 1 /f }

        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization' /v NoLockScreenImage /t REG_DWORD /d 1 /f }

        Run-Quiet { & reg delete 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' /f }
        Run-Quiet { & reg delete 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' /f }
        Run-Quiet { & reg delete 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' /f }
        Run-Quiet { & reg delete 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' /f }

        Run-Quiet { & reg add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' /v SettingsPageVisibility /t REG_SZ /d 'Hide:Home' /f }

        # Remove some built-in apps (kept, but silenced)
        $appsToRemove = @(
          'Print.Fax.Scan','Language.Handwriting','Browser.InternetExplorer','MathRecognizer',
          'OneCoreUAP.OneSync','OpenSSH.Client','Microsoft.Windows.MSPaint','Microsoft.Windows.PowerShell.ISE',
          'Microsoft.Windows.WordPad','Microsoft.Windows.Photos','App.Support.QuickAssist','Language.Speech',
          'Language.TextToSpeech','App.StepsRecorder','Media.WindowsMediaPlayer'
        )
        foreach ($a in $appsToRemove) {
          Run-Quiet { Get-AppxPackage -Name $a -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue }
          Run-Quiet { Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$a*" } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue } }
        }

        Run-Quiet { & reg add 'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem' /v LongPathsEnabled /t REG_DWORD /d 1 /f }
        Run-Quiet { & reg add 'HKCU\Control Panel\Mouse' /v MouseSpeed /t REG_SZ /d 0 /f }
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v ShowTaskViewButton /t REG_DWORD /d 0 /f }
        Run-Quiet { & reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f }
        Run-Quiet { & reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v TaskbarAl /t REG_DWORD /d 0 /f }

        # 66) Download and set wallpaper (silently)
        $wallUrl = 'https://github.com/deadproject/FixOs/blob/main/FixOs-Standard/Wallpaper.png?raw=true'
        $out = Join-Path $env:Public 'FixOs-Wallpaper.png'
        Run-Quiet { Invoke-WebRequest -Uri $wallUrl -OutFile $out -ErrorAction SilentlyContinue }
        if (Test-Path $out) {
          Add-Type -MemberDefinition @'
          [DllImport("user32.dll",SetLastError=$true)]
          public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
'@ -Name Win32 -Namespace NativeMethods
          [NativeMethods.Win32]::SystemParametersInfo(20,0,$out,3) | Out-Null
        }

        if (-not $Silent) { Write-Host ""; Write-Host "FixOS installation finished successfully!" }
    }
    Catch {
        if (-not $Silent) { Write-Host "An error occurred during installation." }
    }

    if (-not $Silent) { Pause; Show-Menu }
}

# If script invoked with -Install, run tweaks directly and exit.
if ($Install) {
    Install-FixOS
    exit
}

Show-Menu