# 🐧 WSL Service Agent (WSLaaS)

*Made with ❤️ by @SaltSpectre*

### *WSL Service Agent - Keeping your WSL distributions alive, one sleep at a time* 🐧🌟

## 🚀 Quick Start 🚀

**TL;DR**: Keep your WSL distributions running in the background without Docker Desktop. Perfect for running Linux services, Docker containers, or any background processes that need persistent WSL instances.

---

## 🎯 Overview 🎯

WSL Service Agent solves a common problem: **WSL distributions terminate when no interactive terminal is active**. This service agent addresses this by:

- Creating a hidden interactive WSL terminal
- Running `sleep infinity` to maintain the distribution's active state
- Providing a clean system tray interface for management
- Operating transparently without interfering with normal WSL usage
- Restarting the instance if an *oopsie* happens

### Perfect For:
- 🐳 Running Docker containers without Docker Desktop
- 🌐 Hosting web services in WSL
- 📊 Background data processing tasks
- 🔧 Development environments that need persistent state
- ✨ Running local AI models

### How It Works:
The agent launches a hidden WSL session that executes an infinite sleep command, effectively "tricking" WSL into thinking there's an active user session. This keeps your WSL Linux distribution running continuously while remaining completely invisible to your normal workflow.

---

## ⭐ Key Features ⭐

- **🔄 Persistent WSL Sessions**: Keeps distributions alive indefinitely
- **🎛️ System Tray Management**: Clean, minimal, intuitive interface
- **⚡ Zero Interference**: Works alongside your normal WSL usage
- **📦 Multiple Instance Support (kinda)**: Run several distributions simultaneously. *(See the multiple instances section for details.)*
- **🎨 Custom Icons**: Personalize your system tray experience
- **🚀 Auto-start Support**: Launch on logon

---

## ⚙️ Configuration ⚙️

All settings are managed through the `config.json` file. The configuration is divided into logical sections for easy management.

### 📱 Application Settings (`app`) 📱

| Setting | Description | Default Value|
|---------|-------------|---------|
| `publisher` | Used for the install path parent directory. You can change this if you want a different parent directory for the app. A value MUST be provided, even if you modify the install path to not use it. | `"SaltDeception"` |
| `displayName` | The name of the app as it will appear in the Windows Start Menu. | `"WSLaaS Service Agent"` |
| `shortName` | The name of the app as it will appear in the file system, the registry, and the tool tip for the system tray icon. | `"WSLaaS"` |
| `customIcon` | The icon that will be used for the app in the Windows Start Menu and the system tray. You can use any icon file you want, but it must be in the same directory as this config file. Supported formats are `.ico`, `.png`, and `.bmp`. **Ensure the manifest section is updated as well!** | `"wsl.ico"` |
| `fallbackIcon` | The system library containing the icon that will be used if the custom icon cannot be found. It must be a valid path to an icon file or a resource in a DLL. If you do not want a fallback icon, set this to an empty string. | `"$env:SystemRoot\\system32\\shell32.dll"` |
| `fallbackIconIndex` | The index of the icon in the fallback icon file that will be used if the custom icon cannot be found. Indexes start at 0, so the first icon in the file is index 0, the second icon is index 1, and so on. A value MUST be provided, even if you do not want a fallback icon. | `43` |
| `manifest` | The list of files that will be copied to the install path when the app is installed. The files will be copied to the install path as-is, so you can use relative paths to organize your files. In general, unless you are adding an icon file, there is no reason to modify this. | `["WSLaaS.ps1", "assets.psm1", "config.json", "wsl.ico"]` |

### 📂 Path Configuration (`paths`) 📂

| Setting | Description | Default Value|
|---------|-------------|---------|
| `installPath` | The path where the app will be installed. It can be any valid path, but it is recommended to use a path in the user's local app data directory. The path can use environment variables, such as `$env:LocalAppData`, and PowerShell variables, such as `$app.publisher` and `$app.shortName`. | `"$env:LocalAppData\\$($app.publisher)\\$($app.shortName)"` |

### 🐧 WSL Service Settings (`WSLaaS.distribution`) 🐧

| Setting | Description | Default Value|
|---------|-------------|---------|
| `name` | The name of the WSL distribution to manage. It must match the name of the distribution as it appears in `WSL.exe --list`. | `"Arch"` |
| `wtProfileGuid` | Used to identify the Windows Terminal profile for the WSL distribution. When a WSL distribution is installed, a Windows Terminal profile is created for it. You can find the GUID by looking for the profile name in the Windows Terminal settings file. Ensure the GUID value is enclosed in curly braces. | `"{84cb5bcf-7400-5041-8a5e-51dc455a5776}"` |
| `keepAliveInterval` | The interval in milliseconds at which the WSL distribution will be kept alive. Under most circumstances, this should be set to `5000` (5 seconds) or less. Note that setting this value too low may cause performance issues, and there is no benefit to shortening intervals unless you are experiencing issues with the WSL distribution not staying alive. | `5000` |

### 📋 Complete (Default) Configuration Example 📋

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

---

### 🔍 Finding Your Windows Terminal Profile GUID 🔍

1. Open Windows Terminal settings (`Ctrl + ,`)
2. Click "Open JSON file" in the bottom left corner
3. Look for your WSL distribution in the `profiles.list` array
4. Copy the `guid` value (including curly braces) for your distribution

---

## 🔀 Multiple Instances 🔀

This script is designed to manage the lifecycle of a single WSL distribution. However, it can be run multiple times with different configurations to manage multiple distributions. **To use it in this manner, you must install the script multiple times** - once for each distribution you want to manage. Each installation uses different values in the `config.json` file for each instance. Each instance will run independently and manage its own WSL distribution.

### Required Unique Values Per Instance:
The minimum values that must be configured in the `config.json` file for each instance are:

- **`app.displayName`** → `"WSLaaS Service Agent - Ubuntu"` (recommend `WSLaaS Service Agent-<distro>`)
- **`app.shortName`** → `"WSLaaS-Ubuntu"` (recommend `WSLaaS-<distro>`)
- **`WSLaaS.distribution.name`** → `"Ubuntu-20.04"` (this will always be the distro name as it appears in `WSL.exe --list`)
- **`WSLaaS.distribution.wtProfileGuid`** → `"{your-guid-here}"` (this will be the Windows Terminal profile GUID for the WSL distribution)

### Example Multi-Instance Setup:

```
📁 WSLaaS-Ubuntu/
├── WSLaaS.ps1
├── config.json (configured for Ubuntu)
└── ...

📁 WSLaaS-Arch/
├── WSLaaS.ps1
├── config.json (configured for Arch)
└── ...
```

---

## 📋 Requirements 📋

### PowerShell Version
- **PowerShell 7.5+** (Required)
- Earlier versions are not supported

**Installation Options:**
```pwsh
# Via winget (recommended)
winget install --id Microsoft.Powershell --source winget
```

Or download from: https://aka.ms/powershell

### WSL Prerequisites
- **WSL 2** (Required)
- At least one WSL distribution installed and configured

### System Requirements
- Windows 11 (Windows 10 has not been tested)
- PowerShell execution policy allowing script execution `Set-ExecutionPolicy Bypass`
- Standard user permissions (no admin required)

---

## 🚀 Installation and Usage 🚀

### 1. ⏬ Download & Setup ⏬

```pwsh
# Clone the repository
git clone https://github.com/SaltSpectre/ps-WSLaaS.git
cd ps-WSLaaS
```
Or download the latest release!

### 2. 🪄 Configure 🪄

Edit `config.json` with your WSL distribution details.

At *minimim* you must:
- Set `WSLaaS.distribution.name` to your distribution name
- Set `WSLaaS.distribution.wtProfileGuid` to your Windows Terminal profile GUID

### 3. 💿 Install 💿

```pwsh
# Install and set up auto-start (recommended)
.\WSLaaS.ps1 -AutoStart

# Or install without auto-start
.\WSLaaS.ps1 -Install

# Or run without installing
.\WSLaaS.ps1
```

### 4. 👨‍💻 Manage 👨‍💻

- **System Tray Icon**: 
  - Double-click to launch the Windows Terminal profile for your distribution
  - Right-click to access the context menu.
- **Context Menu**: 
  - Displays the current status of the WSL Service Agent
  - Stop or Start the agent (useful if you need to take down WSL for a bit)
  - Launch the Windows Terminal profile for your distribution
  - Exit: Stops the agent and quits the WSL Service Agent

### 🗑️ Uninstallation 🗑️

```pwsh
.\WSLaaS.ps1 -Uninstall
```

**⚠️ IMPORTANT ⚠️:** Uninstalling requires `config.json` to be present in the same directory as the script **WITH THE CORRECT CONFIGURATION**!

- If you no longer have the `config.json` file, you can manually remove the files from the install path and delete the Start Menu shortcut
- If you selected the `-AutoStart` switch during installation, you will also need to remove the registry entry from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`

---

## ⛔ Known Issues ⛔

### PowerShell Constrained Language Mode
- **Issue**: WSLaaS cannot function in PowerShell CLM environments
- **Cause**: Security restrictions prevent required script operations
- **Impact**: Rare (typically enterprise environments only)
- **Solution**: None available (by design)

---

## 📁 File Structure 📁

```
WSLaaS/
├── 📄 WSLaaS.ps1          # Main application script
├── ⚙️ config.json         # Configuration file
├── 🎨 assets.psm1         # Base64 encoded system tray icons
└── 🖼️ wsl.ico             # Default application icon
```

### File Descriptions

| File | Purpose | Required |
|------|---------|----------|
| `WSLaaS.ps1` | Core application logic and system tray management | ✅ |
| `config.json` | All configuration settings and customization | ✅ |
| `assets.psm1` | Embedded icon resources for system tray | ✅ |
| `wsl.ico` | Default application icon (customizable) | ⚠️ |

---

## 🤝 Contributing 🤝

Found a bug or have a feature request? Get in contact!

- 🐛 **Report Issues**: [GitHub Issues](https://github.com/SaltSpectre/ps-WSLaaS/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/SaltSpectre/ps-WSLaaS/discussions)
- 🔧 **Pull Requests**: Always welcome!

---

## 📜 License 📜

This project is proudly open source. Please refer to `LICENSE.md` for licensing information.
