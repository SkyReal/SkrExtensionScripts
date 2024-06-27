$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)

$InputUnrealProjectFilePath = $Variables.InputUnrealProject
$InputUnrealProjectDirectoryPath = (Get-Item $InputUnrealProjectFilePath).Directory
$RessourcesPluginsPath = $Variables.PluginDownloadDir
$SkyRealPluginsToIgnore = $Variables.SkyRealPluginsToIgnore

$SymLinks = @{
	[IO.Path]::Combine($InputUnrealProjectDirectoryPath, "Content", "MetaHumans") = [IO.Path]::Combine($RessourcesPluginsPath, "Content", "MetaHumans");
}

Get-ChildItem -Path $RessourcesPluginsPath -Recurse -Filter "*.uplugin" | ForEach-Object {
    if ($SkyRealPluginsToIgnore -contains $_.BaseName) 
	{
		Write-Host "Ignoring plugin " + $_.BaseName
	}
	else
	{
		$fi_info = Get-Item -Path $_.FullName
		$SymLinks[[IO.Path]::Combine($InputUnrealProjectDirectoryPath, "Plugins", $fi_info.Directory.Name)] = $fi_info.Directory.FullName
    }
}

foreach ($symlinkRelativePath in $SymLinks.Keys) 
{
	$SymlinkFrom = $SymLinks[$symlinkRelativePath]
	$SymlinkTo = $symlinkRelativePath
	Write-Host "From = " + $SymlinkFrom + " / to = " $SymlinkTo
	If (Test-Path -Path $SymlinkTo) {
		# Delete legacy directory if exists to replace it by symlink
		Remove-Item -Recurse -Force $SymlinkTo
	}
	New-Item -ItemType Directory -Force -Path $SymlinkFrom | Out-Null
	New-Item -ItemType Directory -Force -Path (Split-Path $SymlinkTo) | Out-Null
	New-Item -ItemType SymbolicLink -Path $SymlinkTo -Target $SymlinkFrom -Force
}
