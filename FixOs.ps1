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
        Start-Process -FilePath $exe -ArgumentList $arg -Verb RunAs -Wait
        exit
    }

    # Running elevated here.
    $ErrorActionPreference = 'Continue'

    Try {
        # Helper to run a command while hiding output
        function Run-Quiet {
            param([ScriptBlock]$Block)
            & $Block *> $null 2>&1
            return $?
        }

        if (-not $Silent) { Write-Host "Starting FixOS installation..." }

        # 1) Enable .NET Framework 3.5
        if (-not $Silent) { Write-Host "Enabling .NET Framework 3.5..." }
        Run-Quiet { 
            dism /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet
        }

        # 2) Configure Maximum Password Age (90 days)
        if (-not $Silent) { Write-Host "Configuring password policy..." }
        Run-Quiet { net accounts /maxpwage:90 }

        # 3) Allow execution of PowerShell scripts
        if (-not $Silent) { Write-Host "Setting execution policy..." }
        Run-Quiet { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force }

        # 4) Disable Teredo
        if (-not $Silent) { Write-Host "Disabling Teredo..." }
        Run-Quiet { netsh interface teredo set state disabled }

        # 5) Disable telemetry/data collection (common policies)
        if (-not $Silent) { Write-Host "Configuring telemetry settings..." }
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord -Force
        }

        # 6) Disable common telemetry scheduled tasks (silently)
        if (-not $Silent) { Write-Host "Disabling telemetry tasks..." }
        $tasksToDisable = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
            '\Microsoft\Windows\Autochk\Proxy'
        )
        foreach ($t in $tasksToDisable) { 
            Run-Quiet { schtasks /Change /TN $t /Disable }
        }

        # 7/8) Enable Ultimate Performance plan, duplicate/rename and set active
        if (-not $Silent) { Write-Host "Configuring power plan..." }
        $origGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $dupOut = powercfg -duplicatescheme $origGuid 2>$null
        if ($LASTEXITCODE -eq 0 -and $dupOut -match 'Power Scheme GUID: ([a-fA-F0-9-]{36})') {
            $newGuid = $matches[1]
            Run-Quiet { powercfg -changename $newGuid "FixOs Powerplan" "FixOs optimized power plan" }
            Run-Quiet { powercfg -setactive $newGuid }
        } else {
            # Fallback to high performance
            Run-Quiet { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c }
        }

        # 9) Set many services startup types
        if (-not $Silent) { Write-Host "Configuring services..." }
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
        if (-not $Silent) { Write-Host "Disabling Game DVR..." }
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'BackgroundCaptureEnabled' -Value 0 -Type DWord -Force
        }

        # 12) Disable Background Apps
        if (-not $Silent) { Write-Host "Disabling background apps..." }
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsRunInBackground' -Value 2 -Type DWord -Force
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        # 13) Disable Hibernation
        if (-not $Silent) { Write-Host "Disabling hibernation..." }
        Run-Quiet { powercfg -h off }

        # Performance / game mode tweaks
        if (-not $Silent) { Write-Host "Applying performance tweaks..." }
        $currentPlan = (powercfg -getactivescheme) -replace '.*(: )?([a-fA-F0-9-]+).*','$2'
        if ($currentPlan) {
            Run-Quiet { powercfg -setacvalueindex $currentPlan SUB_PROCESSOR PROCTHROTTLEMAX 100 }
            Run-Quiet { powercfg -setdcvalueindex $currentPlan SUB_PROCESSOR PROCTHROTTLEMAX 100 }
            Run-Quiet { powercfg -setacvalueindex $currentPlan SUB_VIDEO VIDEOCONLOCK 0 }
        }

        # 18) Disable Cortana
        if (-not $Silent) { Write-Host "Disabling Cortana..." }
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type DWord -Force
        }

        # 20) Disable Location Services
        if (-not $Silent) { Write-Host "Disabling location services..." }
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocationScripting' -Value 1 -Type DWord -Force
        }

        # 21) Turn off Activity History
        if (-not $Silent) { Write-Host "Disabling activity history..." }
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0 -Type DWord -Force
        }

        # Additional registry tweaks
        if (-not $Silent) { Write-Host "Applying registry tweaks..." }
        
        # Disable advertising ID
        Run-Quiet { 
            New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Force | Out-Null
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0 -Type DWord -Force
        }

        # Disable Windows Error Reporting
        Run-Quiet { 
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        # Windows Defender sample submission
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' -Name 'SubmitSamplesConsent' -Value 2 -Type DWord -Force
        }

        # Disable Delivery Optimization
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0 -Type DWord -Force
        }

        # Disable touch keyboard handwriting
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC' -Name 'PreventHandwritingDataSharing' -Value 1 -Type DWord -Force
        }

        # Disable content delivery manager suggestions
        Run-Quiet { 
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SystemPaneSuggestionsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord -Force
        }

        # Windows Search tweaks
        Run-Quiet { 
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowSearchToUseLocation' -Value 0 -Type DWord -Force
        }

        # Windows Update policies
        Run-Quiet { 
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Force | Out-Null
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'AUOptions' -Value 2 -Type DWord -Force
        }

        # Disable Remote Assistance
        Run-Quiet { 
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' -Name 'fAllowToGetHelp' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        # Disable Windows Spotlight
        Run-Quiet { 
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SoftLandingEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenOverlayEnabled' -Value 0 -Type DWord -Force
        }

        # Enable long paths
        Run-Quiet { 
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -Type DWord -Force
        }

        # Taskbar tweaks
        Run-Quiet { 
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Type DWord -Force
        }

        # Remove built-in apps
        if (-not $Silent) { Write-Host "Removing built-in apps..." }
        $appsToRemove = @(
            'Microsoft.BingWeather',
            'Microsoft.GetHelp',
            'Microsoft.Getstarted', 
            'Microsoft.MicrosoftOfficeHub',
            'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.People',
            'Microsoft.WindowsCamera',
            'microsoft.windowscommunicationsapps',
            'Microsoft.WindowsFeedbackHub',
            'Microsoft.WindowsMaps',
            'Microsoft.XboxApp',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.ZuneMusic',
            'Microsoft.ZuneVideo'
        )
        
        foreach ($app in $appsToRemove) {
            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like "*$app*" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }

        # 66) Download and set wallpaper
        if (-not $Silent) { Write-Host "Setting wallpaper..." }
        $wallUrl = 'https://github.com/deadproject/FixOs/raw/main/FixOs-Standard/Wallpaper.png'
        $out = Join-Path $env:PUBLIC 'FixOs-Wallpaper.png'
        try {
            Invoke-WebRequest -Uri $wallUrl -OutFile $out -ErrorAction Stop
            if (Test-Path $out) {
                Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
                [Wallpaper]::SystemParametersInfo(0x0014, 0, $out, 0x01 -bor 0x02) | Out-Null
            }
        } catch {
            # Wallpaper download failed, continue without it
        }

        if (-not $Silent) { 
            Write-Host ""
            Write-Host "FixOS installation finished successfully!" 
            Write-Host "Some changes may require a restart to take effect."
        }
    }
    Catch {
        if (-not $Silent) { 
            Write-Host "An error occurred during installation: $($_.Exception.Message)" 
        }
    }

    if (-not $Silent) { 
        Pause
        Show-Menu 
    }
}

# If script invoked with -Install, run tweaks directly and exit.
if ($Install) {
    Install-FixOS
    exit
}

Show-Menu
