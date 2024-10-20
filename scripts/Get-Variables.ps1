$ParentPath = (Get-Item (Resolve-Path (Join-Path $PSScriptRoot "..")))

while ($ParentPath -ne $null) {
	$jsonVariableFile = Join-Path $ParentPath.FullName "Variables.json"
	if (Test-Path $jsonVariableFile) {
		break
	}
	$ParentPath = $ParentPath.Parent
}

$jsonVariableFileDirectory = (Get-Item $jsonVariableFile).Directory
$jsonVariableLocalFile = Join-Path $ParentPath.FullName "Variables_local.json"
$VariablesDocument = Get-Content -Path $jsonVariableFile | ConvertFrom-Json


if (Test-Path $jsonVariableLocalFile)
{
	$VariablesLocalDocument = Get-Content -Path $jsonVariableLocalFile | ConvertFrom-Json
	
	function Merge-Json ($json1, $json2) 
	{
		foreach ($prop in $json2.PSObject.Properties) 
		{
			if ($json1."$($prop.Name)" -and $prop.Value -is [PSCustomObject]) 
			{
				Merge-Json $json1."$($prop.Name)" $prop.Value
			} 
			else 
			{
				$json1."$($prop.Name)" = $prop.Value
			}
		}
	}
	
	Merge-Json $VariablesDocument $VariablesLocalDocument
}

# Uncomment this line to display JSon
# $VariablesDocument | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Host $_ }

if (-not ($VariablesDocument.PSObject.Properties.Name -contains "UnrealEditorRootDirLocalFullPath") -or (-not (Test-Path $VariablesDocument.UnrealEditorRootDirLocalFullPath)))
{
	$UEEditorEnvVariable = $VariablesDocument.UnrealEditorEnvironmentVariable
	$UEPath = (Get-Item -ErrorAction SilentlyContinue -Path "Env:$UEEditorEnvVariable").Value
	$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'UnrealEditorRootDirLocalFullPath' -Value $UEPath
	if (-not (Test-Path $VariablesDocument.UnrealEditorRootDirLocalFullPath))
	{
		Write-Warning "Warning, UnrealEditorRootDirLocalFullPath of UnrealEditorEnvironmentVariable variable in Variable.json is invalid."
	}
}

$VariablesDocument.OutputBuildDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.OutputBuildDir 
$VariablesDocument.OutputInstallDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.OutputInstallDir 
$VariablesDocument.InputUnrealProject = Join-Path $jsonVariableFileDirectory $VariablesDocument.InputUnrealProject 
$VariablesDocument.PluginDownloadDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.PluginDownloadDir 
if (-not $VariablesDocument.PSObject.Properties['AdditionalInstallersScripts']) {
    $VariablesDocument | Add-Member -MemberType NoteProperty -Name 'AdditionalInstallersScripts' -Value @()
}
$VariablesDocument.AdditionalInstallersScripts = $VariablesDocument.AdditionalInstallersScripts | ForEach-Object { Join-Path $jsonVariableFileDirectory $_ }

$VariablesDocument.Version = $VariablesDocument.Version + "." + $VariablesDocument.VersionBuildCounter
if ($VariablesDocument.Version -notmatch "^\d+(\.\d+){3}$") {
	throw [System.FormatException]::new($VariablesDocument.Version + " is not valid (should be X.X.X.X).")
}

if ($VariablesDocument.ProductUpgradeCode -eq "641C1FE1-7B3E-4184-92B4-DD701FE7F4E9") {
	Write-Warning "Warning, ProductUpgradeCode variable in Variable.json should be changed (ignore this warning on sample project)."
}

# Uncomment this line to display JSon
# $VariablesDocument | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Host $_ }

return $VariablesDocument