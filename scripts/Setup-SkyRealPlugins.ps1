$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)

$SkyRealPluginRelease = $Variables.SkyRealPluginRelease
$SkyRealPluginPatch = $Variables.SkyRealPluginPatch
$RessourcesPluginsPath = $Variables.PluginDownloadDir
$OnlineSkyRealPluginURL = $Variables.OnlineSkyRealPluginURL
$RemoteSkyRealPluginDirectory = $Variables.RemoteSkyRealPluginDirectory

# Clean legacy plugins
If (Test-Path -Path $RessourcesPluginsPath)
{
	Remove-Item -path $RessourcesPluginsPath -Force -Recurse  | Out-Null
}
New-Item -ItemType Directory -Force -Path $RessourcesPluginsPath | Out-Null

$SourcePluginsDir = [IO.Path]::Combine($RemoteSkyRealPluginDirectory, $SkyRealPluginRelease, "SkrPlugins")
$SourcePluginsPathFile = [IO.Path]::Combine($SourcePluginsDir, $SkyRealPluginPatch + ".json")
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
			# Copy zip to local ressource directory
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
	Write-Host "File " + $SourcePluginsPathFile + " is missing, switch to online repository"
	$OnlineSkyRealPluginURL_base = $OnlineSkyRealPluginURL + "/" + $SkyRealPluginRelease + "/SkrPlugins/"
	$OnlineSkyRealPluginURL_json = $OnlineSkyRealPluginURL_base + $SkyRealPluginPatch + ".json"
	$response = Invoke-WebRequest -Uri $OnlineSkyRealPluginURL_json
	$SourcePluginsDocument = $response.Content | ConvertFrom-Json
	foreach ($FileSubPath in $SourcePluginsDocument.files) 
	{
		if ($FileSubPath -like "*.zip")
		{
			$InputFilePath = $OnlineSkyRealPluginURL_base + $FileSubPath
			$OutputFilePath = (Join-Path $RessourcesPluginsPath $FileSubPath)
			
			# Download online zip to local ressource directory
			Invoke-WebRequest -Uri $InputFilePath -OutFile $OutputFilePath
			
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
	Write-Host $content
}