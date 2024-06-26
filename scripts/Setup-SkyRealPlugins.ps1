$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)

$SkyRealRelease = $Variables.SkyRealRelease
$SkyRealPatch = $Variables.SkyRealPatch
$RessourcesPluginsPath = $Variables.PluginDownloadDir

# Clean legacy plugins
If (Test-Path -Path $RessourcesPluginsPath)
{
	Remove-Item -path $RessourcesPluginsPath -Force -Recurse  | Out-Null
}
New-Item -ItemType Directory -Force -Path $RessourcesPluginsPath | Out-Null

$SourcePluginsDir = [IO.Path]::Combine("\\192.168.0.6", "SkyRealDownload", "SkyRealSuite", $SkyRealRelease, "SkrPlugins")
$SourcePluginsPathFile = [IO.Path]::Combine($SourcePluginsDir, $SkyRealPatch + ".json")
If (Test-Path -Path $SourcePluginsPathFile)
{
	# Load json file
	$SourcePluginsDocument = Get-Content -Path $SourcePluginsPathFile | ConvertFrom-Json
	
	# Foreach input files
	foreach ($FileSubPath in $SourcePluginsDocument.files) 
	{
		if ($FileSubPath -like "*.zip")
		{
			$InputFilePath = (Join-Path $SourcePluginsDir $FileSubPath)
			$OutputFilePath = (Join-Path $RessourcesPluginsPath $FileSubPath)
			# Copy online zip to local ressource directory
			Copy-Item -Path $InputFilePath -Destination $OutputFilePath 
			
			# Expand Zip Zip
			Expand-Archive $OutputFilePath -DestinationPath $RessourcesPluginsPath -Force
			
			# Delete Zip
			Remove-Item -path $OutputFilePath -Force -Recurse
		} 
		else
		{
			Write-Host "File " $FileSubPath " is not a zip"
		}
	}
}
else 
{
	# TODO retreive data from web adress
	Write-Host "File " + $SourcePluginsPathFile + " is missing"
}