
$RepositoryPath = Resolve-Path (Join-Path $PSScriptRoot "..")
& (Join-Path (Join-Path $RepositoryPath "scripts") Build-UEExtension.ps1)
& (Join-Path (Join-Path $RepositoryPath "scripts") Build-Installer.ps1)