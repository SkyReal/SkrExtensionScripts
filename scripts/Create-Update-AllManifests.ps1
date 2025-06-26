[CmdletBinding()]
param(
    [bool]$ForceUpdate=$false,
	[bool]$EditorManifest=$false
)

$PSScriptPath = Resolve-Path (Join-Path $PSScriptRoot "Create-Update-SkrManifest.ps1")

# Load variables
$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)
$UProjectfile = $Variables.InputUnrealProject
$UProjectPath = (Get-Item $UProjectfile).Directory
$AllPluginNames = $Variables.ExtensionsPlugins
$FullVersion = $Variables.FullVersion


# Main loop
foreach ($PluginName in $AllPluginNames) {
    $PluginPath     = Join-Path $UProjectPath (Join-Path 'Plugins' $PluginName)
	& $PSScriptPath -PluginName $PluginName -PluginPath $PluginPath -FullVersion $FullVersion -DependencyWhiteList $AllPluginNames -ForceUpdate $ForceUpdate -EditorManifest $EditorManifest
}