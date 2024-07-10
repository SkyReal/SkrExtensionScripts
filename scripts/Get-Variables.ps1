$ParentPath = (Get-Item (Resolve-Path (Join-Path $PSScriptRoot "..")))

while ($ParentPath -ne $null) {
	$jsonVariableFile = Join-Path $ParentPath.FullName "Variables.json"
	if (Test-Path $jsonVariableFile) {
		break
	}
	$ParentPath = $ParentPath.Parent
}

$jsonVariableFileDirectory = (Get-Item $jsonVariableFile).Directory
$VariablesDocument = Get-Content -Path $jsonVariableFile | ConvertFrom-Json

$VariablesDocument.OutputBuildDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.OutputBuildDir 
$VariablesDocument.OutputInstallDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.OutputInstallDir 
$VariablesDocument.InputUnrealProject = Join-Path $jsonVariableFileDirectory $VariablesDocument.InputUnrealProject 
$VariablesDocument.PluginDownloadDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.PluginDownloadDir 

$VariablesDocument.Version = $VariablesDocument.Version + "." + $VariablesDocument.VersionBuildCounter
if ($VariablesDocument.Version -notmatch "^\d+(\.\d+){3}$") {
	throw [System.FormatException]::new($VariablesDocument.Version + " is not valid (should be X.X.X.X).")
}

return $VariablesDocument