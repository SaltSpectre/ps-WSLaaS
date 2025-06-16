# WSL Service Agent (WSLaaS)

*Made with ❤️ by @SaltSpectre*

A PowerShell-based service agent keeps a WSL distribution running in the background through a system tray application and an infinite sleep loop.

## Overview

This script manages the installation, uninstallation, and operation of the WSL Service Agent. It is designed to live in the system tray and keep the specified WSL distribution running in the background.

Have you ever wanted to run a service or Docker image in WSL without Docker Desktop? Does your WSL instance die because there is no interactive terminal keeping it alive? This service agent is for you! 

When the WSL Service Agent launches, it creates a hidden interactive WSL terminal in which it starts the command `sleep infinity`. The practical effect of this is that it keeps the WSL distribution active in order to allow your Linux based service to run in the background. 

Running the WSL Service Agent will not interfere with your normal interactions with WSL. In fact, you won't even notice it is running aside from a System Tray icon where you can manage the agent.

Run multiple instances of WSL for different purposes? While WSL Service Agent is only designed to handle one WSL instance at a time, you can easily install multiple instances with different configurations and have them run in parallel. See the Configuration section for more details.

## Configuration

All options are configured in the `config.json` file located in the same directory as this script. The `assets.psm1` file contains base64 encoded icons used in the system tray.

### Configuration Reference

#### App Settings (`app`)

- **`publisher`** - Used for the install path parent directory. You can change this if you want a different parent directory for the app. A value MUST be provided, even if you modify the install path to not use it.
- **`displayName`** - The name of the app as it will appear in the Windows Start Menu.
- **`shortName`** - The name of the app as it will appear in the file system, the registry, and the tool tip for the system tray icon.
- **`customIcon`** - The icon that will be used for the app in the Windows Start Menu and the system tray. You can use any icon file you want, but it must be in the same directory as this config file. Supported formats are `.ico`, `.png`, and `.bmp`. **Ensure the manifest section is updated as well!**
- **`fallbackIcon`** - The system library containing the icon that will be used if the custom icon cannot be found. It must be a valid path to an icon file or a resource in a DLL. If you do not want a fallback icon, set this to an empty string.
- **`fallbackIconIndex`** - The index of the icon in the fallback icon file that will be used if the custom icon cannot be found. Indexes start at 0, so the first icon in the file is index 0, the second icon is index 1, and so on. A value MUST be provided, even if you do not want a fallback icon.
- **`manifest`** - The list of files that will be copied to the install path when the app is installed. The files will be copied to the install path as-is, so you can use relative paths to organize your files. In general, unless you are adding an icon file, there is no reason to modify this.

#### Paths (`paths`)

- **`installPath`** - The path where the app will be installed. It can be any valid path, but it is recommended to use a path in the user's local app data directory. The path can use environment variables, such as `$env:LocalAppData`, and PowerShell variables, such as `$app.publisher` and `$app.shortName`.

#### WSL Service Settings (`WSLaaS.distribution`)

- **`name`** - The name of the WSL distribution to manage. It must match the name of the distribution as it appears in `WSL.exe --list`.
- **`wtProfileGuid`** - Used to identify the Windows Terminal profile for the WSL distribution. When a WSL distribution is installed, a Windows Terminal profile is created for it. You can find the GUID by looking for the profile name in the Windows Terminal settings file. Ensure the GUID value is enclosed in curly braces.
- **`keepAliveInterval`** - The interval in milliseconds at which the WSL distribution will be kept alive. Under most circumstances, this should be set to 5000 (5 seconds) or less. Note that setting this value too low may cause performance issues, and there is no benefit to shortening intervals unless you are experiencing issues with the WSL distribution not staying alive.

### Example Configuration

```json
{
  "app": {
    "publisher": "SaltDeception",
    "displayName": "WSLaaS Service Agent",
    "shortName": "WSLaaS",
    "customIcon": "wsl.ico",
    "fallbackIcon": "$env:SystemRoot\\system32\\shell32.dll",
    "fallbackIconIndex": 43,
    "manifest": [
      "WSLaaS.ps1",
      "assets.psm1",
      "config.json",
      "wsl.ico"
    ]
  },
  "paths": {
    "installPath": "$env:LocalAppData\\$($app.publisher)\\$($app.shortName)"
  },
  "WSLaaS": {
    "distribution": {
      "name": "Arch",
      "wtProfileGuid": "{84cb5bcf-7400-5041-8a5e-51dc455a5776}",
      "keepAliveInterval": 5000
    }
  }
}
```

## Multiple Instances

This script is designed to manage the lifecycle of a single WSL distribution. However, it can be run multiple times with different configurations to manage multiple distributions. To use it in this manner, install the script multiple times using different values in the `config.json` file for each instance. Each instance will run independently and manage its own WSL distribution.

### Required Configuration Values

The minimum values that must be configured in the `config.json` file for each instance are:

- `app.displayName` (recommend `WSLaaS Service Agent-<distro>`)
- `app.shortName` (recommend `WSLaaS-<distro>`)
- `WSLaaS.distribution.name` (this will always be the distro name as it appears in `WSL.exe --list`)
- `WSLaaS.distribution.wtProfileGuid` (this will be the Windows Terminal profile GUID for the WSL distribution)

## Requirements

### PowerShell Version

This script has only been tested on **PowerShell 7.5** and above. It may not work correctly on earlier versions of PowerShell. To ensure compatibility, please use the recommended PowerShell version or later.

**Install PowerShell 7.5 or later:**
- From the official Microsoft website: https://aka.ms/powershell
- Or with winget:
  ```pwsh
  winget install --id Microsoft.Powershell --source winget
  ```

### WSL

- WSL Version 2 is supported
- WSL **MUST** be installed and a distribution configured prior to installation of WSLaaS.

## Usage

### Download

You can download this repository or use `git clone`. All files, including the configuration file and icons are included.

### Set configuration

For simple usage, most configuration values can be left at their default values. At a minimum, you must change
- `WSLaaS.distribution.name`
- `WSLaaS.distribution.wtProfileGuid`

See the configuration section for more details.

### Installation

To install the WSLaaS service agent, run the script with the `-Install` or `-AutoStart` (recommended) switch:

```pwsh
.\WSLaaS.ps1 -Install
```

This will:
- Copy the necessary files to the specified install path
- Create a Start Menu shortcut
- **Set up the service to start automatically on user login if the `-AutoStart` switch is used**

### Uninstallation

To uninstall the WSLaaS service agent, run the script with the `-Uninstall` switch:

```pwsh
.\WSLaaS.ps1 -Uninstall
```

This will:
- Remove the files from the install path
- Delete the Start Menu shortcut

> **⚠️ IMPORTANT ⚠️**: Uninstalling requires `config.json` to be present in the same directory as the script **WITH THE CORRECT CONFIGURATION**!
> 
> - If you no longer have the `config.json` file, you can manually remove the files from the install path and delete the Start Menu shortcut
> - If you selected the `-AutoStart` switch during installation, you will also need to remove the registry entry from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`

### Running Without Installation

To run the WSLaaS service agent without installing, simply run the script:

```pwsh
.\WSLaaS.ps1
```

This will start the service agent in the system tray without installing it.

## ⛔ Known Issues ⛔
- The app will not function if PowerShell Constrained Language Mode (CLM) is enforced. This is a rarely implemented security feature applied by system administrators, but it prevents many of the methods in this script from being used. There is no workaround (nor would I support one if there was.)

## Files

- `WSLaaS.ps1` - Main script file
- `config.json` - Configuration file
- `assets.psm1` - Contains base64 encoded icons for the system tray
- `wsl.ico` - The default icon used for the app (See configuration section for more info)