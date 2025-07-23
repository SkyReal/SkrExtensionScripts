[CmdletBinding()]
param(
	[String]$CustomRessourcePluginsPath=""
)


$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)

foreach ($hook in $Variables.Hooks) {
    if ($hook.trigger -eq "setup_symlinks_before") {
        $scriptPath = $hook.path
        
        if (Test-Path -Path $scriptPath) {
            Write-Host "Execute hook before setup symlinks ($scriptPath)"
            & $scriptPath 
        }
    }
}

$InputUnrealProjectFilePath = $Variables.InputUnrealProject
$InputUnrealProjectDirectoryPath = (Get-Item $InputUnrealProjectFilePath).Directory
$RessourcesPluginsPath = $Variables.PluginDownloadDir

# You can use a custom RessourcePluginsPath folder as parameter
if($CustomRessourcePluginsPath -ne "")
{
	if(Test-Path -Path $CustomRessourcePluginsPath)
	{
		$RessourcesPluginsPath = Resolve-Path -Path "$CustomRessourcePluginsPath"
	}
}

$SkyRealPluginsToIgnore = $Variables.SkyRealPluginsToIgnore

$SymLinks = @{}
if (-not ($SkyRealPluginsToIgnore -contains "Content"))
{
	$SymLinks[[IO.Path]::Combine($InputUnrealProjectDirectoryPath, "Content", "MetaHumans")] = [IO.Path]::Combine($RessourcesPluginsPath, "Content", "MetaHumans");
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

$RootPath = $InputUnrealProjectDirectoryPath

if (-not (Test-Path $RootPath)) {
        Write-Warning "Path does not exist: $RootPath"
        return
    }

    Get-ChildItem -Path $RootPath -Recurse -Force | ForEach-Object {
        if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            try {
                Remove-Item $_.FullName -Force
                Write-Host "Removed symlink: $($_.FullName)"
            } catch {
                Write-Warning "Failed to remove symlink: $($_.FullName)"
            }
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

foreach ($hook in $Variables.Hooks) {
    if ($hook.trigger -eq "setup_symlinks_after") {
        $scriptPath = $hook.path
        
        if (Test-Path -Path $scriptPath) {
            Write-Host "Execute hook after setup symlinks ($scriptPath)"
            & $scriptPath 
        }
    }
}