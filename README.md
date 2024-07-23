
# Introduction 
This repository contains scripts used to build a SkyRealVR extension. It should be used either by copying content or symlink it into another repository.

# Getting Started
To make it work, create a `Variables.json` in your root folder of your main repository (for mubmodules). The file should contains:
* **InputUnrealProject**: The playground project where your plugins will be developed
* **OutputBuildDir**: The path (relative to repo root directory) where to copy extensions after build.
* **OutputInstallDir**: The path (relative to repo root directory) where to copy installers after build.
* **ExtensionsPlugins**: The name of the plugins to package into installer.
* **InstallerName**: The name of the pack of plugins and the name of the installer.
* **ProductUpgradeCode**: The Guid used for unstall/unistall plugins pack
* **Version**: The version of the plugins (Major.Minor.Patch)
* **VersionBuildCounter**: The build counter version of the (for devops capabilities)
* **SkyRealVersion**: The version of SkyReal compatible with the plugins (Should be `X.Y` where X is major version and Y is minor version) 
* **OnlineSkyRealPluginURL**: The online URL where to find the lastest plugins of SkyRealVR
* **RemoteSkyRealPluginDirectory**: The local directory where to find the lastest plugins of SkyRealVR
* **SkyRealPluginRelease**: The release branch of SkyRealVR used to download plugins (Should be `X.Y` where X is major version and Y is minor version or `master` for latest version)
* **SkyRealPluginPatch**: The release patch of SkyRealVR used to download plugins (Should be `X.Y.Z` where X is major version, Y is minor version and Z the patch number or `latest` for latest version or `RCXX` for specific release candidate)
* **SkyRealPluginsToIgnore**: The list of SkyRealVR plugin names to ignore. This can be used to improve performances.
* **UnrealEditorEnvironmentVariable**: The environement variable used to specify the path of Unreal editor used for compilation.

For local work, a file `Variables_local.json` can be created (git ignore) in the same directory as `Variables.json`. It will automatically be loaded to override any information inside `Variables.json`.

# Content details
* `scripts\Get-Variables.ps1`: This script is used to retrieve all variables from the `Variables.json` file and edit relative path to full path.
* `scripts\Setup-Repository.ps1`: This script will setup all repository by calling all setup scripts
* `scripts\Setup-SkyRealPlugins.ps1`: This script will download latest SkyRealVR plugins from URL contained into `Variables.json`. There is an automatic fallback to URL if local directory not found.
* `scripts\Setup-SymLinks.ps1`: This script will create automatically symlink from downloaded plugins to playground project plugins directory.
* `scripts\Build-Repository`: This script will build all repository by calling all build scripts
* `scripts\Build-UEExtension.ps1`: This script will call Unreal editor to cook project and copy result into output directory.
* `scripts\Build-Installer.ps1`: This script will call NSIS to create installer based on plugins cook data.
* `installers\Common`: This directory is used for NSIS dependencies
* `installers\src\*.nsh`: NSIS scripts files for installer
* `installers\src\Assets\favicon.ico`: The icon of the installer