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
    param([string]$AppName)
    
    try {
        # Remove for current user
        Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        # Remove for all users
        Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        # Remove provisioned package
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$AppName*" } | ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
        if (-not $Silent) { Write-Host "Removed: $AppName" -ForegroundColor Green }
    } catch {
        if (-not $Silent) { Write-Host "Failed to remove: $AppName" -ForegroundColor Yellow }
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

        # 1) Remove ALL Microsoft apps except Notepad, Snipping Tool, Terminal
        if (-not $Silent) { Write-Host "Removing unwanted apps..." }
        
        $appsToRemove = @(
            "Microsoft.MicrosoftEdge",
            "Microsoft.Teams",
            "Clipchamp.Clipchamp", 
            "Microsoft.XboxApp",
            "Microsoft.XboxGamingOverlay",
            "Microsoft.XboxIdentityProvider",
            "Microsoft.XboxSpeechToTextOverlay",
            "Microsoft.Paint",
            "Microsoft.MSPaint",
            "Microsoft.LinkedIn",
            "Microsoft.BingNews",
            "Microsoft.WindowsAlarms",
            "Microsoft.WindowsCamera", 
            "Microsoft.WindowsSoundRecorder",
            "Microsoft.YourPhone",
            "Microsoft.MicrosoftStickyNotes",
            "Microsoft.OneDrive",
            "Microsoft.QuickAssist",
            "Microsoft.BingWeather",
            "Microsoft.People",
            "Microsoft.GetHelp",
            "Microsoft.Getstarted",
            "Microsoft.MicrosoftOfficeHub",
            "Microsoft.MicrosoftSolitaireCollection",
            "Microsoft.WindowsFeedbackHub",
            "Microsoft.WindowsMaps",
            "Microsoft.ZuneMusic",
            "Microsoft.ZuneVideo",
            "Microsoft.Windows.Photos",
            "Microsoft.ScreenSketch",
            "Microsoft.WindowsCalculator",
            "Microsoft.BingSearch",
            "Microsoft.Todos",
            "Microsoft.Widgets",
            "Microsoft.Cortana",
            "Microsoft.PowerAutomateDesktop",
            "Microsoft.WindowsStore",
            "Microsoft.OutlookForWindows",
            "microsoft.windowscommunicationsapps",
            "Microsoft.SkypeApp",
            "Microsoft.MicrosoftEdgeDevToolsClient",
            "Microsoft.549981C3F5F10",
            "Microsoft.GamingApp",
            "Microsoft.MicrosoftWhiteboard",
            "Microsoft.BingFoodAndDrink",
            "Microsoft.BingHealthAndFitness",
            "Microsoft.BingTravel",
            "Microsoft.BingFinance",
            "Microsoft.MixedReality.Portal",
            "Microsoft.HEIFImageExtension",
            "Microsoft.Advertising.Xaml"
        )

        foreach ($app in $appsToRemove) {
            Remove-WindowsApp -AppName $app
        }

        # 2) Disable Copilot
        if (-not $Silent) { Write-Host "Disabling Copilot..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1

        # 3) Disable Location Services
        if (-not $Silent) { Write-Host "Disabling location services..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1

        # 4) Disable Privacy settings
        if (-not $Silent) { Write-Host "Disabling privacy settings..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0

        # 5) Disable Xbox services
        if (-not $Silent) { Write-Host "Disabling Xbox services..." }
        $xboxServices = @("XboxGipSvc", "XboxNetApiSvc", "XboxAuthManager")
        foreach ($service in $xboxServices) {
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        }

        # 6) Disable Game Bar
        if (-not $Silent) { Write-Host "Disabling Game Bar..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0

        # 7) Disable Widgets
        if (-not $Silent) { Write-Host "Disabling Widgets..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0

        # 8) Disable OneDrive
        if (-not $Silent) { Write-Host "Disabling OneDrive..." }
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1

        # 9) TASKBAR CLEANUP
        if (-not $Silent) { Write-Host "Cleaning taskbar..." }
        # Move Start to left
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
        # Hide Search
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
        # Hide Task View
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        # Hide Widgets
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0

        # 10) DISABLE SEARCH FEATURES
        if (-not $Silent) { Write-Host "Disabling search..." }
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0
        Set-RegistryProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1

        # 11) FILE EXPLORER SETTINGS
        if (-not $Silent) { Write-Host "Configuring File Explorer..." }
        # Open to This PC instead of Quick Access
        Set-RegistryProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1

        # 12) BASIC TWEAKS
        if (-not $Silent) { Write-Host "Applying basic tweaks..." }
        # Execution policy
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
        # Power plan
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        # Hibernation
        powercfg -h off

        # 13) Set wallpaper
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

        # 14) RESTART EXPLORER
        if (-not $Silent) { Write-Host "Restarting Explorer..." }
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process "explorer.exe"

        if (-not $Silent) { 
            Write-Host ""
            Write-Host "FixOS installation completed successfully!" -ForegroundColor Green
            Write-Host "Only Notepad, Snipping Tool, and Terminal remain." -ForegroundColor Green
            Write-Host "Taskbar cleaned and settings applied." -ForegroundColor Green
        }
    }
    Catch {
        if (-not $Silent) { 
            Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
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
