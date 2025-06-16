#requires -Version 7.5

Param(
    [Parameter(Mandatory = $false)] [Switch] $Install,    
    [Parameter(Mandatory = $false)] [Switch] $AutoStart,  
    [Parameter(Mandatory = $false)] [Switch] $Uninstall   
)

#region Welcome Message
# ================================================================================================
$WelcomeMessage = @"

================================================================================
                        WSL Service Agent (WSLaaS)
                        Made with ❤️ by @SaltSpectre
================================================================================
Copyright © 2025 SaltSpectre
Licensed under the MIT License

This script manages the installation, uninstallation, and lifecycle of a WSL 
service agent.

Find more information, the latest versions, and documentation at:
https://github.com/SaltSpectre/ps-WSLaaS

================================================================================


"@
Write-Host $WelcomeMessage
#endregion Welcome Message

#region Configuration and Setup
# ================================================================================================
if ($AutoStart) { $Install = $true }
if ($Uninstall) { $Install = $false }

# Load configuration from JSON file
$ParentPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
$ConfigPath = Join-Path $ParentPath "config.json"

# Import assets module for base64 encoded icons
$AssetsPath = Join-Path $ParentPath "assets.psm1"
if (Test-Path $AssetsPath) {
    Import-Module $AssetsPath -Force
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    # Expand environment variables in config values
    $AppPublisher = [System.Environment]::ExpandEnvironmentVariables($Config.app.publisher)
    $AppDisplayName = [System.Environment]::ExpandEnvironmentVariables($Config.app.displayName)
    $AppShortName = [System.Environment]::ExpandEnvironmentVariables($Config.app.shortName)
    $CustomIcon = [System.Environment]::ExpandEnvironmentVariables($Config.app.customIcon)
    $FallbackIcon = [System.Environment]::ExpandEnvironmentVariables($Config.app.fallbackIcon)
    $FallbackIconIndex = $Config.app.fallbackIconIndex    # Handle template substitution for install path
    $InstallPathTemplate = $Config.paths.installPath
    Write-Host "DEBUG: Raw template = '$InstallPathTemplate'" -ForegroundColor Yellow
    
    # Replace template variables with actual values first
    $InstallPath = $InstallPathTemplate.Replace('$($app.publisher)', $AppPublisher).Replace('$($app.shortName)', $AppShortName)
    Write-Host "DEBUG: After template substitution = '$InstallPath'" -ForegroundColor Yellow
    
    # Convert PowerShell $env: syntax to Windows %VAR% syntax before expanding
    $InstallPath = $InstallPath -replace '\$env:(\w+)', '%$1%'
    Write-Host "DEBUG: After env syntax conversion = '$InstallPath'" -ForegroundColor Yellow
    
    # Then expand environment variables
    $InstallPath = [System.Environment]::ExpandEnvironmentVariables($InstallPath)
    Write-Host "DEBUG: Final InstallPath = '$InstallPath'" -ForegroundColor Yellow
    # WSL configuration
    $WSLDistribution = $Config.WSLaaS.distribution.name
    $WSLKeepAliveInterval = $Config.WSLaaS.distribution.keepAliveInterval
    $WSLProfileGuid = $Config.WSLaaS.distribution.wtProfileGuid
}
catch {
    Write-Error "Failed to parse configuration file (This is commonly caused by malformed file paths i.e. using '\' instead of '\\'.):`n$_"
    exit 1
}

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

#endregion Configuration and Setup

#region Framework Helper Functions
# ================================================================================================
Function Find-IconFile {
    param([string]$BasePath, [string]$IconName)
    
    foreach ($format in @('ico', 'png', 'bmp')) {
        $iconPath = Join-Path $BasePath "$($IconName -replace '\.[^.]*$', '').$format"
        if (Test-Path $iconPath) {
            return $iconPath
        }
    }
    return $null
}

Function New-IconFromFile {
    param([string]$IconPath)
    
    if (-not (Test-Path $IconPath)) { return $null }
    
    $extension = [System.IO.Path]::GetExtension($IconPath).ToLower()
    
    switch ($extension) {
        '.ico' { return [System.Drawing.Icon]::new($IconPath) }
        { $_ -in '.png', '.bmp' } {
            $bitmap = [System.Drawing.Bitmap]::new($IconPath)
            $hIcon = $bitmap.GetHicon()
            $icon = [System.Drawing.Icon]::FromHandle($hIcon)
            $bitmap.Dispose()
            return $icon
        }
        default {
            Write-Warning "Unsupported icon format: $extension"
            return $null
        }
    }
}

Function Test-RegistryValue {
    param([string]$RegKey, [string]$Name)
    return $null -ne (Get-ItemProperty -Path $RegKey -Name $Name -ErrorAction SilentlyContinue)
}

Function Get-ApplicationIcon {
    $customIconPath = Find-IconFile $ParentPath $CustomIcon
    if ($customIconPath) {
        $icon = New-IconFromFile $customIconPath
        if ($icon) { return $icon }
    }
    
    # Fallback to configured system icon
    try {
        return [System.Drawing.Icon]::ExtractIcon($FallbackIcon, $FallbackIconIndex, $false)
    }
    catch {
        return [System.Drawing.SystemIcons]::Application
    }
}

Function Show-ToastNotification {
    param(
        [string]$Title,
        [string]$Message
    )
        
    if ($appSysTrayIcon) {
        $appSysTrayIcon.ShowBalloonTip(3000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::None)
    }
}

#endregion Framework Helper Functions

#region Installation Functions
# ================================================================================================
Function Install-PSApp {
    try {
        # Create installation directory
        if (!(Test-Path $InstallPath)) { 
            New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null 
        }
        
        $copyErrors = 0
        
        # Copy files from manifest
        foreach ($file in $Config.app.manifest) {
            $sourceFile = Join-Path $ParentPath $file
            if (Test-Path $sourceFile) {
                try {
                    $destinationFile = Join-Path $InstallPath $file
                    Copy-Item -Path $sourceFile -Destination $destinationFile -Force -ErrorAction Stop
                    Write-Host "Copied: $file" -ForegroundColor Green
                } catch {
                    Write-Error "Failed to copy $file`: $_"
                    $copyErrors++
                }
            } else {
                Write-Warning "Manifest file not found: $file"
                $copyErrors++
            }
        }
        
        if ($copyErrors -gt 0) {
            Write-Error "Installation failed with $copyErrors errors"
            return
        }
        
        # Setup auto-start if requested
        if ($AutoStart) {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            if (Test-RegistryValue $regPath $AppShortName) {
                Remove-ItemProperty -Path $regPath -Name $AppShortName -Force
            }
            $startCommand = "conhost pwsh.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstallPath\$AppShortName.ps1`""
            New-ItemProperty -Path $regPath -Name $AppShortName -PropertyType String -Value $startCommand -Force | Out-Null
        }

        # Create Start Menu shortcut
        $shell = New-Object -ComObject "WScript.Shell"
        $shortcut = $shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\$AppDisplayName.lnk")
        $shortcut.TargetPath = "$env:SystemRoot\System32\Conhost.exe" 
        $shortcut.Arguments = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstallPath\$AppShortName.ps1`""
        
        # Set shortcut icon
        $installedIconPath = Find-IconFile $InstallPath $CustomIcon
        if ($installedIconPath) {
            $shortcut.IconLocation = $installedIconPath
        }
        else {
            $shortcut.IconLocation = "$FallbackIcon,$FallbackIconIndex"
        }
        $shortcut.Save()
        
        Write-Host "✅ Installation completed: $InstallPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Installation failed: $_"
    }
}

Function Uninstall-PSApp {
    # Remove shortcuts and auto-start
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\$AppDisplayName.lnk" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $AppShortName -Force -ErrorAction SilentlyContinue    

    # Remove the entire installation directory
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Removed installation directory: $InstallPath" -ForegroundColor Green
    }
    
    Write-Host "✅ Uninstallation completed" -ForegroundColor Green
}
#endregion Installation Functions

#region Main Application Helper Functions
Function Start-WindowsTerminalProfile {
    try {
        Start-Process "wt" -ArgumentList "-p", $WSLProfileGuid
        Write-Host "🚀 Launched Windows Terminal with profile: $WSLProfileGuid" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to launch Windows Terminal: $_"
        # Fallback to regular WSL
        try {
            Start-Process "wsl" -ArgumentList "-d", $WSLDistribution
        }
        catch {
            Write-Warning "Failed to launch WSL: $_"
        }
    }
}

Function Update-StatusMenuItem {
    if ($global:statusMenuItem) {
        if (-not $global:AgentStarted) {
            $global:statusMenuItem.Text = "WSL Service Agent Stopped"
            $global:statusMenuItem.Image = New-FluentEmojiIcon "⛔"
        }
        elseif ($global:WSLProcess -and !$global:WSLProcess.HasExited) {
            $global:statusMenuItem.Text = "WSL Service Agent Running"
            $global:statusMenuItem.Image = New-FluentEmojiIcon "🟢"
        }
        else {
            $global:statusMenuItem.Text = "Unexpected State"
            $global:statusMenuItem.Image = New-FluentEmojiIcon "🌋"
        }
    }
}

Function New-FluentEmojiIcon {
    param([string]$IconName, [int]$Size = 16)
    
    # Map emoji names to base64 asset variables
    $iconMapping = @{
        "⛔" = $no_entry
        "🟢" = $green_circle  
        "🌋" = $volcano
        "🔳" = $white_square_button
        "🛑" = $stop_sign
        "▶️" = $play_button
        "❌" = $cross_mark
    }
    
    $base64String = $iconMapping[$IconName]
    $imageBytes = [Convert]::FromBase64String($base64String)
    $memoryStream = [System.IO.MemoryStream]::new($imageBytes)
    $bitmap = [System.Drawing.Bitmap]::new($memoryStream)
    
    # Resize if needed
    if ($bitmap.Width -ne $Size -or $bitmap.Height -ne $Size) {
        $resizedBitmap = [System.Drawing.Bitmap]::new($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($resizedBitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($bitmap, 0, 0, $Size, $Size)
        $graphics.Dispose()
        $bitmap.Dispose()
        $memoryStream.Dispose()
        return $resizedBitmap
    }
    
    $memoryStream.Dispose()
    return $bitmap
}
#endregion Main Application Helper Functions

#region Main Application Logic
# ================================================================================================
# Handle installation/uninstallation
if ($Install) {
    Install-PSApp
    exit 0
}

if ($Uninstall) {
    Uninstall-PSApp
    exit 0
}

# Create system tray application
$appIcon = Get-ApplicationIcon
$appSysTrayIcon = [System.Windows.Forms.NotifyIcon]::new()
$appSysTrayIcon.Text = $AppDisplayName
$appSysTrayIcon.Icon = $appIcon
$appSysTrayIcon.Visible = $true
$appSysTrayIcon.add_DoubleClick({
        Start-WindowsTerminalProfile
    })

    $contextMenu = [System.Windows.Forms.ContextMenuStrip]::new()
$contextMenu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System
$global:statusMenuItem = [System.Windows.Forms.ToolStripMenuItem]::new()
$global:statusMenuItem.Text = "WSL Service Agent Status"
$global:statusMenuItem.Enabled = $true  # Keep enabled so icon shows in color
$global:statusMenuItem.Font = [System.Drawing.Font]::new($global:statusMenuItem.Font, [System.Drawing.FontStyle]::Bold)
$global:statusMenuItem.Image = New-FluentEmojiIcon "⛔"  # Initial icon
$launchMenuItem = [System.Windows.Forms.ToolStripMenuItem]::new()
$launchMenuItem.Text = "&Launch Terminal"
$launchMenuItem.Image = New-FluentEmojiIcon "🔳"
$launchMenuItem.add_Click({
        Start-WindowsTerminalProfile
    })

$startStopMenuItem = [System.Windows.Forms.ToolStripMenuItem]::new()
$startStopMenuItem.Text = "&Stop Agent"
$startStopMenuItem.Image = New-FluentEmojiIcon "🛑"
$startStopMenuItem.add_Click({        
if ($global:AgentStarted) {
        Stop-WSLAgent
        $startStopMenuItem.Text = "&Start Agent"
        $startStopMenuItem.Image = New-FluentEmojiIcon "▶️"
    }
    else {
        Start-WSLAgent
        $startStopMenuItem.Text = "&Stop Agent"
        $startStopMenuItem.Image = New-FluentEmojiIcon "🛑"
    }
})
$exitMenuItem = [System.Windows.Forms.ToolStripMenuItem]::new()
$exitMenuItem.Text = "&Exit"
$exitMenuItem.Image = New-FluentEmojiIcon "❌"
$exitMenuItem.add_Click({
    $appSysTrayIcon.Visible = $false

    #region App-Specific Cleanup Logic
    Stop-WSLAgent
    
    # Dispose timer
    if ($global:WSLTimer) {
        $global:WSLTimer.Dispose()
    }
    #endregion

    $appSysTrayIcon.Dispose()
    [System.Environment]::Exit(0)
})
# Add separators for better organization
$separator1 = [System.Windows.Forms.ToolStripSeparator]::new()
$separator2 = [System.Windows.Forms.ToolStripSeparator]::new()

# Build the context menu
[void]$contextMenu.Items.Add($global:statusMenuItem)
[void]$contextMenu.Items.Add($separator1)
[void]$contextMenu.Items.Add($startStopMenuItem)
[void]$contextMenu.Items.Add($launchMenuItem)
[void]$contextMenu.Items.Add($separator2)
[void]$contextMenu.Items.Add($exitMenuItem)

# Assign the context menu to the system tray icon
$appSysTrayIcon.ContextMenuStrip = $contextMenu

#region WSL Service Agent
# ================================================================================================

Function Stop-WSLAgent {
    Write-Host "🛑 Stopping WSL Service Agent..." -ForegroundColor Red
    
    # Stop the monitoring timer
    if ($global:WSLTimer) {
        $global:WSLTimer.Stop()
    }
    
    # Kill the WSL process
    if ($global:WSLProcess -and !$global:WSLProcess.HasExited) {
        try {
            $global:WSLProcess.Kill()
            Write-Host "WSL Service Agent process terminated" -ForegroundColor Yellow
        }
        catch {
            Write-Warning "Could not terminate WSL process: $_"
        }
    }
    
    $global:AgentStarted = $false
    Show-ToastNotification "WSL Service Agent" "Agent stopped"
    Update-StatusMenuItem
}

Function Start-WSLAgent {
    Write-Host "▶️ Starting WSL Service Agent..." -ForegroundColor Green
    
    try {
        # Start WSL with sleep infinity
        $global:WSLProcess = Start-Process -FilePath "wsl" -ArgumentList "-d", $WSLDistribution, "-e", "sleep infinity" -WindowStyle Hidden -PassThru
        
        Write-Host "✅ WSL Service Agent started for '$WSLDistribution' (PID: $($global:WSLProcess.Id))" -ForegroundColor Green
        Show-ToastNotification "WSL Service Agent" "Agent started"
        
        # Start the monitoring timer
        if ($global:WSLTimer) {
            $global:WSLTimer.Start()
        }
        
        $global:AgentStarted = $true
        Update-StatusMenuItem
        return $true
    }
    catch {
        Write-Warning "Failed to start WSL Service Agent: $_"
        $global:AgentStarted = $false
        Update-StatusMenuItem
        return $false
    }
}

Function Test-WSLAvailable {
    try {
        $runningDistros = & wsl -l --running 2>$null
        # Remove null characters and check if the distribution is in the running list
        $cleanOutput = ($runningDistros -join "`n") -replace "`0", ""
        return $cleanOutput -match $config.wsl.distributionName
    }
    catch {
        return $false
    }
}

Function Start-WSLMonitoring {
    # Create timer for WSL monitoring (use configured interval)    
    $global:WSLTimer = [System.Windows.Forms.Timer]::new()
    $global:WSLTimer.Interval = $WSLKeepAliveInterval
    $global:AgentStarted = $true  # Default to started
    
    $global:WSLTimer.add_Tick({
            # Update status display
            Update-StatusMenuItem
            
            # Skip if agent is stopped 
            if (-not $global:AgentStarted) {
                return
            }
            
            # Check if the WSL process is still running
            if ($global:WSLProcess -and !$global:WSLProcess.HasExited) {
                # Process is still alive, nothing to do
                return
            }            # WSL process died - restart it
            Write-Host "🔄 WSL Service Agent died - restarting..." -ForegroundColor Yellow
            if (Start-WSLAgent) {
                Show-ToastNotification "WSL Service Agent" "Process restarted"
            }
        })
    
    $global:WSLTimer.Start()
    Write-Host "🔍 WSL monitoring started (auto-restart enabled)" -ForegroundColor Cyan
}

# Initialize WSL Service Agent
Write-Host "🚀 Starting WSL Service Agent..." -ForegroundColor Yellow
if (Start-WSLAgent) {
    Write-Host "✅ WSL Service Agent started" -ForegroundColor Green
}
else {
    Write-Host "⚠️ Failed to start WSL Service Agent" -ForegroundColor Red
    Show-ToastNotification "WSL Service Agent" "Failed to start service agent"
}

# Start monitoring regardless of initial state
Start-WSLMonitoring

# Update initial status
Update-StatusMenuItem

Write-Host "✅ $AppDisplayName started successfully" -ForegroundColor Green
#endregion WSL Service Agent

# Start the application message loop
# ================================================================================================
[System.Windows.Forms.Application]::Run([System.Windows.Forms.ApplicationContext]::new())
#endregion Main Application Logic
