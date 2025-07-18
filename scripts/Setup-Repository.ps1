param(
	[Switch]$SkipExtraction
)

if($SkipExtraction -eq $false)
{
	# Execute extractions
	& (Join-Path $PSScriptRoot Setup-SkyRealPlugins.ps1)
}

# setup symlinks 
& (Join-Path $PSScriptRoot Setup-SymLinks.ps1)

# create SkrManifest files if they don't exist
& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -NullVersion
