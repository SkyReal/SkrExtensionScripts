# Update manifests to include build version
& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true

& (Join-Path $PSScriptRoot Build-UEExtension.ps1)
& (Join-Path $PSScriptRoot Build-Installer.ps1)