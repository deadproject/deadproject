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
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$DisplayName*" -or $_.PackageName -like "*$AppName*" } | ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
        if (-not $Silent) { Write-Host "Removed: $DisplayName" -ForegroundColor Green }
    } catch {
        if (-not $Silent) { Write-Host "Failed to remove: $DisplayName" -ForegroundColor Yellow }
    }
}

function Set-RegistryProperty {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = "DWord")
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    } catch {
        return $false
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

        # 1) Remove ALL Microsoft apps COMPLETELY
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
            @{Name = "Microsoft.PowerAutomateDesktop"; DisplayName = "Power Automate"},
            @{Name = "Microsoft.WindowsStore"; DisplayName = "Microsoft Store"},
            @{Name = "Microsoft.OutlookForWindows"; DisplayName = "Outlook"},
            @{Name = "microsoft.windowscommunicationsapps"; DisplayName = "Mail and Calendar"},
            @{Name = "Microsoft.SkypeApp"; DisplayName = "Skype"},
            @{Name = "Microsoft.MicrosoftEdgeDevToolsClient"; DisplayName = "Edge Dev Tools"},
            @{Name = "Microsoft.549981C3F5F10"; DisplayName = "Cortana"},
            @{Name = "Microsoft.GamingApp"; DisplayName = "Xbox Gaming"},
            @{Name = "Microsoft.MicrosoftWhiteboard"; DisplayName = "Whiteboard"},
            @{Name = "Microsoft.BingFoodAndDrink"; DisplayName = "Food & Drink"},
            @{Name = "Microsoft.BingHealthAndFitness"; DisplayName = "Health & Fitness"},
            @{Name = "Microsoft.BingTravel"; DisplayName = "Travel"},
            @{Name = "Microsoft.BingFinance"; DisplayName = "Finance"},
            @{Name = "Microsoft.WindowsNotepad"; DisplayName = "Notepad"},
            @{Name = "Microsoft.WindowsTerminal"; DisplayName = "Terminal"},
            @{Name = "Microsoft.RawImageExtension"; DisplayName = "Raw Image Extension"},
            @{Name = "Microsoft.VP9VideoExtensions"; DisplayName = "VP9 Video Extension"},
            @{Name = "Microsoft.WebMediaExtensions"; DisplayName = "Web Media Extension"},
            @{Name = "Microsoft.WebpImageExtension"; DisplayName = "Webp Image Extension"},
            @{Name = "Microsoft.DesktopAppInstaller"; DisplayName = "App Installer"},
            @{Name = "Microsoft.Paint"; DisplayName = "Paint 3D"},
            @{Name = "Microsoft.MixedReality.Portal"; DisplayName = "Mixed Reality"},
            @{Name = "Microsoft.HEIFImageExtension"; DisplayName = "HEIF Image Extension"},
            @{Name = "Microsoft.ScreenSketch"; DisplayName = "Snip & Sketch"},
            @{Name = "Microsoft.MicrosoftEdge"; DisplayName = "Edge Update"},
            @{Name = "Microsoft.Advertising.Xaml"; DisplayName = "Advertising Xaml"}
        )

        foreach ($app in $appsToRemove) {
            Remove-WindowsApp -AppName $app.Name -DisplayName $app.DisplayName
        }

        # Remove using wildcards for hard-to-find apps
        $wildcardApps = @(
            "*Outlook*",
            "*Teams*",
            "*Xbox*",
            "*Bing*",
            "*Microsoft.Office*",
            "*Microsoft.MicrosoftOffice*",
            "*Clipchamp*",
            "*Cortana*",
            "*Copilot*"
        )

        foreach $wildcard in $wildcardApps) {
            Get-AppxPackage -Name $wildcard -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxPackage -Name $wildcard -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $wildcard -or $_.PackageName -like $wildcard } | ForEach-Object {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
            }
        }

        # 2) Disable Copilot and AI features COMPLETELY
        if (-not $Silent) { Write-Host "Disabling Copilot and AI features..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AI" -Name "EnableRecall" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0

        # 3) Disable Location Services COMPLETELY
        if (-not $Silent) { Write-Host "Disabling location services..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableWindowsLocationProvider" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type "String"
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Value 0

        # 4) Disable ALL Privacy/Security settings
        if (-not $Silent) { Write-Host "Disabling privacy and security settings..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Name "DisablePrivacyExperience" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0

        # 5) Disable Linking & Typing features
        if (-not $Silent) { Write-Host "Disabling linking and typing features..." }
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Input\Settings" -Name "InsightsEnabled" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name "Enabled" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" -Name "EnableAutocorrection" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" -Name "EnableSpellchecking" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Value 1
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0

        # 6) Disable Xbox Live and Gaming services
        if (-not $Silent) { Write-Host "Disabling Xbox services..." }
        $xboxServices = @("XboxGipSvc", "XboxNetApiSvc", "XboxAuthManager")
        foreach ($service in $xboxServices) {
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        }

        # 7) Disable Game Bar completely
        if (-not $Silent) { Write-Host "Disabling Game Bar..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0

        # 8) Disable Widgets COMPLETELY
        if (-not $Silent) { Write-Host "Disabling Widgets..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0
        # Kill widget process
        Stop-Process -Name "Widgets" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "WebExperienceHost" -Force -ErrorAction SilentlyContinue

        # 9) Disable OneDrive COMPLETELY
        if (-not $Silent) { Write-Host "Disabling OneDrive..." }
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "FileCoAuth" -Force -ErrorAction SilentlyContinue
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1
        # Uninstall OneDrive
        if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
            Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait
        }
        if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
            Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait
        }

        # 10) TASKBAR AND START MENU TWEAKS
        if (-not $Silent) { Write-Host "Configuring taskbar and start menu..." }
        
        # Move Start button to left
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
        
        # Hide Search button
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
        
        # Hide Task View button
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        
        # Hide Widgets button
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
        
        # Hide Chat button
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0
        
        # Clean taskbar - only show Start and File Explorer
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCortanaButton" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0

        # 11) DISABLE ALL SEARCH FEATURES
        if (-not $Silent) { Write-Host "Disabling search features..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowSearchToUseLocation" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCloudSearch" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "AllowSearchToUseLocation" -Value 0

        # 12) FILE EXPLORER TWEAKS
        if (-not $Silent) { Write-Host "Configuring File Explorer..." }
        
        # Open File Explorer to This PC instead of Quick Access
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1
        
        # Show file extensions
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
        
        # Show hidden files
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
        
        # Show operating system files
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1
        
        # Disable show recent files in Quick Access
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0
        
        # Disable show frequent folders in Quick Access
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0

        # 13) SECURITY TWEAKS
        if (-not $Silent) { Write-Host "Applying security tweaks..." }
        
        # Disable Windows Defender
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1
        
        # Disable SmartScreen
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type "String"
        
        # Disable UAC
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 0
        
        # Disable Firewall
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
        
        # Disable Windows Update
        Set-Service -Name "wuauserv" -StartupType Disabled
        Stop-Service -Name "wuauserv" -Force

        # 14) PERFORMANCE TWEAKS
        if (-not $Silent) { Write-Host "Applying performance tweaks..." }
        
        # .NET Framework 3.5
        dism /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet
        
        # Password policy
        net accounts /maxpwage:90
        
        # Execution policy
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
        
        # Teredo
        netsh interface teredo set state disabled
        
        # Power plan - Ultimate Performance
        $origGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $dupOut = powercfg -duplicatescheme $origGuid 2>$null
        if ($LASTEXITCODE -eq 0 -and $dupOut -match 'Power Scheme GUID: ([a-fA-F0-9-]{36})') {
            $newGuid = $matches[1]
            powercfg -changename $newGuid "FixOs Powerplan" "FixOs optimized power plan"
            powercfg -setactive $newGuid
        }
        
        # Hibernation
        powercfg -h off

        # 15) TELEMETRY AND DATA COLLECTION
        if (-not $Silent) { Write-Host "Disabling telemetry..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0

        # 16) Set wallpaper
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

        # 17) RESTART EXPLORER TO APPLY CHANGES
        if (-not $Silent) { Write-Host "Restarting Explorer to apply changes..." }
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process "explorer.exe"

        if (-not $Silent) { 
            Write-Host ""
            Write-Host "FixOS installation finished successfully!" -ForegroundColor Green
            Write-Host "All specified apps have been removed and features disabled." -ForegroundColor Green
            Write-Host "Taskbar has been cleaned - only Start and File Explorer remain." -ForegroundColor Green
            Write-Host "File Explorer now opens to This PC." -ForegroundColor Green
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

# If script invoked with -Install, run tweaks directly and exit.
if ($Install) {
    Install-FixOS
    exit
}

Show-Menu
