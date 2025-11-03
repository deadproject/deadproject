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

function Remove-WindowsApp {
    param([string]$AppName, [string]$DisplayName)
    
    try {
        # Remove for current user
        Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        # Remove for all users
        Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        # Remove provisioned package
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$DisplayName*" } | ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
        Write-Host "Removed: $DisplayName" -ForegroundColor Green
    } catch {
        Write-Host "Failed to remove: $DisplayName" -ForegroundColor Red
    }
}

function Install-FixOS {
    param()

    Clear-Host
    if (-not $Silent) { Write-Host "Installing FixOS... (Requires elevation if not already elevated.)" }

    # Auto-elevation
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
        if (-not $Silent) { Write-Host "Starting FixOS installation..." }

        # 1) Remove all specified Microsoft apps
        if (-not $Silent) { Write-Host "Removing Microsoft apps..." }
        
        $appsToRemove = @(
            @{Name = "Microsoft.MicrosoftEdge"; DisplayName = "Microsoft Edge"},
            @{Name = "Microsoft.Teams"; DisplayName = "Microsoft Teams"},
            @{Name = "Clipchamp.Clipchamp"; DisplayName = "Clipchamp"},
            @{Name = "Microsoft.XboxApp"; DisplayName = "Xbox"},
            @{Name = "Microsoft.XboxGamingOverlay"; DisplayName = "Xbox Game Bar"},
            @{Name = "Microsoft.XboxIdentityProvider"; DisplayName = "Xbox Identity"},
            @{Name = "Microsoft.XboxSpeechToTextOverlay"; DisplayName = "Xbox Speech"},
            @{Name = "Microsoft.Paint"; DisplayName = "Paint"},
            @{Name = "Microsoft.MSPaint"; DisplayName = "Paint"},
            @{Name = "Microsoft.LinkedIn"; DisplayName = "LinkedIn"},
            @{Name = "Microsoft.BingNews"; DisplayName = "Microsoft News"},
            @{Name = "Microsoft.WindowsAlarms"; DisplayName = "Alarms & Clock"},
            @{Name = "Microsoft.WindowsCamera"; DisplayName = "Camera"},
            @{Name = "Microsoft.WindowsSoundRecorder"; DisplayName = "Voice Recorder"},
            @{Name = "Microsoft.YourPhone"; DisplayName = "Phone Link"},
            @{Name = "Microsoft.MicrosoftStickyNotes"; DisplayName = "Sticky Notes"},
            @{Name = "Microsoft.OneDrive"; DisplayName = "OneDrive"},
            @{Name = "Microsoft.QuickAssist"; DisplayName = "Quick Assist"},
            @{Name = "Microsoft.BingWeather"; DisplayName = "Weather"},
            @{Name = "Microsoft.People"; DisplayName = "People"},
            @{Name = "Microsoft.GetHelp"; DisplayName = "Get Help"},
            @{Name = "Microsoft.Getstarted"; DisplayName = "Get Started"},
            @{Name = "Microsoft.MicrosoftOfficeHub"; DisplayName = "Office"},
            @{Name = "Microsoft.MicrosoftSolitaireCollection"; DisplayName = "Solitaire"},
            @{Name = "Microsoft.WindowsFeedbackHub"; DisplayName = "Feedback Hub"},
            @{Name = "Microsoft.WindowsMaps"; DisplayName = "Maps"},
            @{Name = "Microsoft.ZuneMusic"; DisplayName = "Groove Music"},
            @{Name = "Microsoft.ZuneVideo"; DisplayName = "Movies & TV"},
            @{Name = "Microsoft.Windows.Photos"; DisplayName = "Photos"},
            @{Name = "Microsoft.ScreenSketch"; DisplayName = "Snip & Sketch"},
            @{Name = "Microsoft.WindowsCalculator"; DisplayName = "Calculator"},
            @{Name = "Microsoft.BingSearch"; DisplayName = "Bing Search"},
            @{Name = "Microsoft.Todos"; DisplayName = "Microsoft To Do"},
            @{Name = "Microsoft.Widgets"; DisplayName = "Widgets"},
            @{Name = "Microsoft.Cortana"; DisplayName = "Cortana"},
            @{Name = "Microsoft.PowerAutomateDesktop"; DisplayName = "Power Automate"}
        )

        foreach ($app in $appsToRemove) {
            Remove-WindowsApp -AppName $app.Name -DisplayName $app.DisplayName
        }

        # 2) Disable Copilot and AI features
        if (-not $Silent) { Write-Host "Disabling Copilot and AI features..." }
        # Disable Copilot button
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
        
        # Disable Recall (AI timeline)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AI" -Name "EnableRecall" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AI" -Force | Out-Null

        # 3) Disable Location Services COMPLETELY
        if (-not $Silent) { Write-Host "Disabling location services..." }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableWindowsLocationProvider" -Value 1 -Type DWord -Force
        
        # Disable location in settings
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type String -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Value 0 -Type DWord -Force

        # 4) Disable ALL Privacy/Security settings
        if (-not $Silent) { Write-Host "Disabling privacy and security settings..." }
        
        # General privacy settings
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Name "DisablePrivacyExperience" -Value 1 -Type DWord -Force
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Force | Out-Null
        
        # Disable advertising ID
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force
        
        # Disable tailored experiences
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force
        
        # Disable app launch tracking
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -Force

        # 5) Disable Linking & Typing features
        if (-not $Silent) { Write-Host "Disabling linking and typing features..." }
        
        # Disable text suggestions
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Input\Settings" -Name "InsightsEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name "Enabled" -Value 0 -Type DWord -Force
        
        # Disable autocorrect
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" -Name "EnableAutocorrection" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" -Name "EnableSpellchecking" -Value 0 -Type DWord -Force
        
        # Disable handwriting personalization
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Value 1 -Type DWord -Force
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Force | Out-Null
        
        # Disable inking and typing personalization
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord -Force

        # 6) Disable Xbox Live and Gaming services
        if (-not $Silent) { Write-Host "Disabling Xbox services..." }
        $xboxServices = @(
            "XboxGipSvc",
            "XboxNetApiSvc",
            "XboxAuthManager"
        )
        
        foreach ($service in $xboxServices) {
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        }

        # 7) Disable Game Bar completely
        if (-not $Silent) { Write-Host "Disabling Game Bar..." }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0 -Type DWord -Force

        # 8) Disable Widgets
        if (-not $Silent) { Write-Host "Disabling Widgets..." }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord -Force

        # 9) Disable OneDrive completely
        if (-not $Silent) { Write-Host "Disabling OneDrive..." }
        # Kill OneDrive process
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "FileCoAuth" -Force -ErrorAction SilentlyContinue
        
        # Prevent OneDrive from running
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Force | Out-Null
        
        # Disable OneDrive setup
        if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
            TakeOwnership -Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
            icacls "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /deny everyone:X
        }
        if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
            TakeOwnership -Path "$env:SystemRoot\System32\OneDriveSetup.exe"
            icacls "$env:SystemRoot\System32\OneDriveSetup.exe" /deny everyone:X
        }

        # 10) Remove remaining Windows components using DISM
        if (-not $Silent) { Write-Host "Removing Windows components..." }
        $componentsToRemove = @(
            "WindowsMediaPlayer",
            "Xbox-XboxLive",
            "XboxGameOverlay",
            "XboxGamingOverlay",
            "XboxIdentityProvider",
            "XboxTCUI"
        )
        
        foreach ($component in $componentsToRemove) {
            dism /Online /Disable-Feature /FeatureName:$component /NoRestart /Quiet
        }

        # 11) Additional telemetry and privacy disabling
        if (-not $Silent) { Write-Host "Disabling additional telemetry..." }
        
        # Disable diagnostic data
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
        
        # Disable activity history
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -Force

        # 12) Disable background apps completely
        if (-not $Silent) { Write-Host "Disabling background apps..." }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force

        # 13) Apply remaining original tweaks from your script
        if (-not $Silent) { Write-Host "Applying system tweaks..." }
        
        # .NET Framework 3.5
        dism /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet
        
        # Password policy
        net accounts /maxpwage:90
        
        # Execution policy
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
        
        # Teredo
        netsh interface teredo set state disabled
        
        # Power plan
        $origGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $dupOut = powercfg -duplicatescheme $origGuid 2>$null
        if ($LASTEXITCODE -eq 0 -and $dupOut -match 'Power Scheme GUID: ([a-fA-F0-9-]{36})') {
            $newGuid = $matches[1]
            powercfg -changename $newGuid "FixOs Powerplan" "FixOs optimized power plan"
            powercfg -setactive $newGuid
        }
        
        # Hibernation
        powercfg -h off

        # 14) Set wallpaper
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
            Write-Host "FixOS installation finished successfully!" -ForegroundColor Green
            Write-Host "All specified apps have been removed and features disabled." -ForegroundColor Green
            Write-Host "Some changes may require a restart to take effect." -ForegroundColor Yellow
        }
    }
    Catch {
        if (-not $Silent) { 
            Write-Host "An error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $Silent) { 
        Pause
        Show-Menu 
    }
}

# Helper function to take ownership of files
function TakeOwnership {
    param([string]$Path)
    try {
        takeown /f $Path /a
        icacls $Path /grant administrators:F
    } catch {
        # Ignore errors
    }
}

# If script invoked with -Install, run tweaks directly and exit.
if ($Install) {
    Install-FixOS
    exit
}

Show-Menu
