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

function Remove-AppxSafe {
    param([string]$AppName)
    try {
        Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like "*$AppName*" } | ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Set-RegistrySafe {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = "DWord")
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    } catch {}
}

function Install-FixOS {
    Clear-Host
    if (-not $Silent) { Write-Host "Installing FixOS... (Requires elevation)" }

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Install" -Verb RunAs -Wait
        exit
    }

    $ErrorActionPreference = 'SilentlyContinue'

    try {
        Remove-AppxSafe -AppName "Microsoft.MicrosoftEdge"
        Remove-AppxSafe -AppName "Microsoft.Teams"
        Remove-AppxSafe -AppName "Clipchamp.Clipchamp"
        Remove-AppxSafe -AppName "Microsoft.XboxApp"
        Remove-AppxSafe -AppName "Microsoft.XboxGamingOverlay"
        Remove-AppxSafe -AppName "Microsoft.XboxIdentityProvider"
        Remove-AppxSafe -AppName "Microsoft.Paint"
        Remove-AppxSafe -AppName "Microsoft.MSPaint"
        Remove-AppxSafe -AppName "Microsoft.LinkedIn"
        Remove-AppxSafe -AppName "Microsoft.BingNews"
        Remove-AppxSafe -AppName "Microsoft.WindowsAlarms"
        Remove-AppxSafe -AppName "Microsoft.WindowsCamera"
        Remove-AppxSafe -AppName "Microsoft.WindowsSoundRecorder"
        Remove-AppxSafe -AppName "Microsoft.YourPhone"
        Remove-AppxSafe -AppName "Microsoft.MicrosoftStickyNotes"
        Remove-AppxSafe -AppName "Microsoft.OneDrive"
        Remove-AppxSafe -AppName "Microsoft.QuickAssist"
        Remove-AppxSafe -AppName "Microsoft.BingWeather"
        Remove-AppxSafe -AppName "Microsoft.People"
        Remove-AppxSafe -AppName "Microsoft.GetHelp"
        Remove-AppxSafe -AppName "Microsoft.Getstarted"
        Remove-AppxSafe -AppName "Microsoft.MicrosoftOfficeHub"
        Remove-AppxSafe -AppName "Microsoft.MicrosoftSolitaireCollection"
        Remove-AppxSafe -AppName "Microsoft.WindowsFeedbackHub"
        Remove-AppxSafe -AppName "Microsoft.WindowsMaps"
        Remove-AppxSafe -AppName "Microsoft.ZuneMusic"
        Remove-AppxSafe -AppName "Microsoft.ZuneVideo"
        Remove-AppxSafe -AppName "Microsoft.Windows.Photos"
        Remove-AppxSafe -AppName "Microsoft.ScreenSketch"
        Remove-AppxSafe -AppName "Microsoft.WindowsCalculator"
        Remove-AppxSafe -AppName "Microsoft.BingSearch"
        Remove-AppxSafe -AppName "Microsoft.Todos"
        Remove-AppxSafe -AppName "Microsoft.Widgets"
        Remove-AppxSafe -AppName "Microsoft.Cortana"
        Remove-AppxSafe -AppName "Microsoft.PowerAutomateDesktop"
        Remove-AppxSafe -AppName "Microsoft.WindowsStore"
        Remove-AppxSafe -AppName "Microsoft.OutlookForWindows"
        Remove-AppxSafe -AppName "microsoft.windowscommunicationsapps"
        Remove-AppxSafe -AppName "Microsoft.SkypeApp"
        Remove-AppxSafe -AppName "Microsoft.Windows.Copilot"
        Remove-AppxSafe -AppName "Microsoft.Copilot"

        dism /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet
        net accounts /maxpwage:90
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
        netsh interface teredo set state disabled

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0

        $tasksToDisable = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
            '\Microsoft\Windows\Autochk\Proxy'
        )
        foreach ($t in $tasksToDisable) { schtasks /Change /TN $t /Disable }

        $origGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $dupOut = powercfg -duplicatescheme $origGuid
        if ($dupOut -match '\{([0-9A-Fa-f-]{36})\}') { 
            $newGuid = $matches[1]
            powercfg -changename $newGuid "FixOs Powerplan" "FixOs optimized power plan"
            powercfg -setactive $newGuid
        }

        Set-Service -Name 'AJRouter' -StartupType Disabled
        Set-Service -Name 'ALG' -StartupType Manual
        Set-Service -Name 'AppIDSvc' -StartupType Manual
        Set-Service -Name 'AppMgmt' -StartupType Manual
        Set-Service -Name 'AppReadiness' -StartupType Manual
        Set-Service -Name 'AppVClient' -StartupType Disabled
        Set-Service -Name 'AppXSvc' -StartupType Manual
        Set-Service -Name 'Appinfo' -StartupType Manual
        Set-Service -Name 'AssignedAccessManagerSvc' -StartupType Disabled
        Set-Service -Name 'AudioEndpointBuilder' -StartupType Automatic
        Set-Service -Name 'AudioSrv' -StartupType Automatic
        Set-Service -Name 'Audiosrv' -StartupType Automatic
        Set-Service -Name 'AxInstSV' -StartupType Manual
        Set-Service -Name 'BDESVC' -StartupType Manual
        Set-Service -Name 'BFE' -StartupType Automatic
        Set-Service -Name 'BITS' -StartupType Manual
        Set-Service -Name 'BTAGService' -StartupType Manual
        Set-Service -Name 'BrokerInfrastructure' -StartupType Automatic
        Set-Service -Name 'Browser' -StartupType Manual
        Set-Service -Name 'BthAvctpSvc' -StartupType Automatic
        Set-Service -Name 'BthHFSrv' -StartupType Automatic
        Set-Service -Name 'CDPSvc' -StartupType Manual
        Set-Service -Name 'COMSysApp' -StartupType Manual
        Set-Service -Name 'ClipSVC' -StartupType Manual
        Set-Service -Name 'CryptSvc' -StartupType Automatic
        Set-Service -Name 'DPS' -StartupType Automatic
        Set-Service -Name 'DcomLaunch' -StartupType Automatic
        Set-Service -Name 'Dhcp' -StartupType Automatic
        Set-Service -Name 'DialogBlockingService' -StartupType Disabled
        Set-Service -Name 'DispBrokerDesktopSvc' -StartupType Automatic
        Set-Service -Name 'DmEnrollmentSvc' -StartupType Manual
        Set-Service -Name 'Dnscache' -StartupType Automatic
        Set-Service -Name 'DoSvc' -StartupType Manual
        Set-Service -Name 'DsmSvc' -StartupType Manual
        Set-Service -Name 'EventLog' -StartupType Automatic
        Set-Service -Name 'EventSystem' -StartupType Automatic
        Set-Service -Name 'FontCache' -StartupType Automatic
        Set-Service -Name 'IKEEXT' -StartupType Manual
        Set-Service -Name 'IPBusEnum' -StartupType Manual
        Set-Service -Name 'KeyIso' -StartupType Automatic
        Set-Service -Name 'KtmRm' -StartupType Manual
        Set-Service -Name 'LanmanServer' -StartupType Automatic
        Set-Service -Name 'LanmanWorkstation' -StartupType Automatic
        Set-Service -Name 'LSM' -StartupType Automatic
        Set-Service -Name 'MpsSvc' -StartupType Automatic
        Set-Service -Name 'MSDTC' -StartupType Manual
        Set-Service -Name 'MSiSCSI' -StartupType Manual
        Set-Service -Name 'Netlogon' -StartupType Automatic
        Set-Service -Name 'Netman' -StartupType Manual
        Set-Service -Name 'NlaSvc' -StartupType Manual
        Set-Service -Name 'NcbService' -StartupType Manual
        Set-Service -Name 'PcaSvc' -StartupType Manual
        Set-Service -Name 'PlugPlay' -StartupType Manual
        Set-Service -Name 'Power' -StartupType Automatic
        Set-Service -Name 'ProfSvc' -StartupType Automatic
        Set-Service -Name 'RemoteAccess' -StartupType Disabled
        Set-Service -Name 'RemoteRegistry' -StartupType Disabled
        Set-Service -Name 'RpcEptMapper' -StartupType Automatic
        Set-Service -Name 'RpcSs' -StartupType Automatic
        Set-Service -Name 'SamSs' -StartupType Automatic
        Set-Service -Name 'Schedule' -StartupType Automatic
        Set-Service -Name 'SENS' -StartupType Automatic
        Set-Service -Name 'SessionEnv' -StartupType Manual
        Set-Service -Name 'SharedAccess' -StartupType Manual
        Set-Service -Name 'ShellHWDetection' -StartupType Automatic
        Set-Service -Name 'Spooler' -StartupType Automatic
        Set-Service -Name 'SSDPSRV' -StartupType Manual
        Set-Service -Name 'SstpSvc' -StartupType Manual
        Set-Service -Name 'StateRepository' -StartupType Manual
        Set-Service -Name 'StorSvc' -StartupType Manual
        Set-Service -Name 'SysMain' -StartupType Automatic
        Set-Service -Name 'SystemEventsBroker' -StartupType Automatic
        Set-Service -Name 'TabletInputService' -StartupType Manual
        Set-Service -Name 'TapiSrv' -StartupType Manual
        Set-Service -Name 'TermService' -StartupType Automatic
        Set-Service -Name 'Themes' -StartupType Automatic
        Set-Service -Name 'ThreadOrder' -StartupType Manual
        Set-Service -Name 'TrkWks' -StartupType Automatic
        Set-Service -Name 'TrustedInstaller' -StartupType Manual
        Set-Service -Name 'UevAgentService' -StartupType Disabled
        Set-Service -Name 'UmRdpService' -StartupType Manual
        Set-Service -Name 'UpgradeService' -StartupType Manual
        Set-Service -Name 'UsoSvc' -StartupType Manual
        Set-Service -Name 'VaultSvc' -StartupType Automatic
        Set-Service -Name 'vds' -StartupType Manual
        Set-Service -Name 'VSS' -StartupType Manual
        Set-Service -Name 'W32Time' -StartupType Manual
        Set-Service -Name 'Wcmsvc' -StartupType Automatic
        Set-Service -Name 'WdiServiceHost' -StartupType Manual
        Set-Service -Name 'WdiSystemHost' -StartupType Manual
        Set-Service -Name 'WebClient' -StartupType Manual
        Set-Service -Name 'Wecsvc' -StartupType Manual
        Set-Service -Name 'WinDefend' -StartupType Automatic
        Set-Service -Name 'WinHttpAutoProxySvc' -StartupType Manual
        Set-Service -Name 'Winmgmt' -StartupType Automatic
        Set-Service -Name 'WlanSvc' -StartupType Automatic
        Set-Service -Name 'WManSvc' -StartupType Manual
        Set-Service -Name 'WMPNetworkSvc' -StartupType Manual
        Set-Service -Name 'WpcMonSvc' -StartupType Manual
        Set-Service -Name 'WSearch' -StartupType Manual
        Set-Service -Name 'wuauserv' -StartupType Manual
        Set-Service -Name 'WwanSvc' -StartupType Manual
        Set-Service -Name 'XblAuthManager' -StartupType Manual
        Set-Service -Name 'XblGameSave' -StartupType Manual
        Set-Service -Name 'XboxGipSvc' -StartupType Manual
        Set-Service -Name 'XboxNetApiSvc' -StartupType Manual

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1

        powercfg -h off

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense" -Name "AllowStorageSenseGlobal" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0

        Set-RegistrySafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value 2000

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowCrossDeviceCollection" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Value 1

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested" -Name "Enabled" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowSyncMySettings" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 2

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SpynetReporting" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" -Name "AllowInputPersonalization" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "RemoveWindowsStore" -Value 1

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync" -Name "BackupPolicy" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0

        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 3
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferFeatureUpdates" -Value 1
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferFeatureUpdatesPeriodInDays" -Value 365
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferQualityUpdates" -Value 1
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferQualityUpdatesPeriodInDays" -Value 365

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenEnabled" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled" -Value 0

        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /f
        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /f
        reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /f
        reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /f

        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v SettingsPageVisibility /t REG_SZ /d "Hide:Home" /f

        Remove-AppxSafe -AppName "Print.Fax.Scan"
        Remove-AppxSafe -AppName "Language.Handwriting"
        Remove-AppxSafe -AppName "Browser.InternetExplorer"
        Remove-AppxSafe -AppName "MathRecognizer"
        Remove-AppxSafe -AppName "OneCoreUAP.OneSync"
        Remove-AppxSafe -AppName "OpenSSH.Client"
        Remove-AppxSafe -AppName "Microsoft.Windows.MSPaint"
        Remove-AppxSafe -AppName "Microsoft.Windows.PowerShell.ISE"
        Remove-AppxSafe -AppName "App.Support.QuickAssist"
        Remove-AppxSafe -AppName "Language.Speech"
        Remove-AppxSafe -AppName "Language.TextToSpeech"
        Remove-AppxSafe -AppName "App.StepsRecorder"
        Remove-AppxSafe -AppName "Hello.Face.18967"
        Remove-AppxSafe -AppName "Hello.Face.Migration.18967"
        Remove-AppxSafe -AppName "Hello.Face.20134"
        Remove-AppxSafe -AppName "Media.WindowsMediaPlayer"
        Remove-AppxSafe -AppName "Microsoft.Windows.WordPad"
        Remove-AppxSafe -AppName "Microsoft.WindowsStore"
        Remove-AppxSafe -AppName "Microsoft.ScreenSketch"

        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
        Set-RegistrySafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1
        Set-RegistrySafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value 0
        Set-RegistrySafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0
        Set-RegistrySafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EnableBDEWithNoTPM" -Value 1
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "UseAdvancedStartup" -Value 1
        Set-RegistrySafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "UseTPM" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
        Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0

        $wallUrl = 'https://github.com/deadproject/FixOs/raw/main/FixOs-Standard/Wallpaper.png'
        $wallPath = Join-Path $env:PUBLIC 'FixOs-Wallpaper.png'
        try {
            Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
            if (Test-Path $wallPath) {
                Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
                [Wallpaper]::SystemParametersInfo(20, 0, $wallPath, 0x01 -bor 0x02)
            }
        } catch {}

        Stop-Process -Name "explorer" -Force
        Start-Sleep -Seconds 2
        Start-Process "explorer.exe"

        if (-not $Silent) { 
            Write-Host "FixOS installation completed successfully!" -ForegroundColor Green
            Write-Host "All advanced tweaks have been applied." -ForegroundColor Green
        }

    } catch {
        if (-not $Silent) { 
            Write-Host "Installation completed with some minor errors." -ForegroundColor Yellow
        }
    }

    if (-not $Silent) { 
        Pause
        Show-Menu 
    }
}

if ($Install) {
    Install-FixOS
    exit
}

Show-Menu