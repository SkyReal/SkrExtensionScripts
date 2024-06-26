param(
	[Switch]$SkipExtraction
)

$ScriptsRepositoryPath = Resolve-Path (Join-Path $PSScriptRoot "..")

if($SkipExtraction -eq $false)
{
	# Execute extractions
	& (Join-Path (Join-Path $ScriptsRepositoryPath "scripts") Setup-SkyRealPlugins.ps1)
}

# setup symlinks 
& (Join-Path (Join-Path $ScriptsRepositoryPath "scripts") Setup-SymLinks.ps1)
