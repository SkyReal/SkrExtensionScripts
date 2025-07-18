[CmdletBinding()]
param(
    [bool]$ForceUpdate=$false,
	[bool]$EditorManifest=$false,
	[switch]$NullVersion=$false
)

$PSScriptPath = Resolve-Path (Join-Path $PSScriptRoot "Create-Update-SkrManifest.ps1")

# Load variables
$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)
$UProjectfile = $Variables.InputUnrealProject
$UProjectPath = (Get-Item $UProjectfile).Directory
$AllPluginNames = $Variables.ExtensionsPlugins
$FullVersion = $Variables.FullVersion
if($NullVersion)
{
	$FullVersion = ""
}
$ProjectPluginsFolder = Join-Path $UProjectPath 'Plugins'

# Get All potential dependencies

$SkrPlugins = @(Get-ChildItem -Path "$ProjectPluginsFolder\*" -Recurse -Filter *.uplugin | Select-Object -ExpandProperty DirectoryName -Unique)
$EditorDependenciesWhiteList = $SkrPlugins | ForEach-Object { Split-Path $_ -Leaf }

# Main loop
foreach ($PluginName in $AllPluginNames) {
    $PluginPath     = Join-Path $ProjectPluginsFolder $PluginName
	& $PSScriptPath -PluginName $PluginName -PluginPath $PluginPath -FullVersion $FullVersion -DependenciesWhiteList $AllPluginNames -EditorDependenciesWhiteList $EditorDependenciesWhiteList -ForceUpdate $ForceUpdate -EditorManifest $EditorManifest
}