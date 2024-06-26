
$RepositoryPath = Resolve-Path (Join-Path $PSScriptRoot "..")
& (Join-Path $PSScriptRoot Build-UEExtension.ps1)
& (Join-Path $PSScriptRoot Build-Installer.ps1)