[CmdletBinding()]
param(
	[String]$PluginName,
    [String]$PluginPath,
	[String]$FullVersion,
	[String[]]$DependencyWhiteList=@(),
	[bool]$ForceUpdate=$false,
	[bool]$EditorManifest=$false,
	[switch]$IsPlugin=$false
)

# Manifest extension
$ManifestExtension = '.skrmanifest'

# Vérification des paramètres obligatoires
if (-not $PluginName) {
    throw "Parameter 'PluginName' required"
}
if (-not $FullVersion) {
    throw "Parameter 'FullVersion' required"
}
if (-not $PluginPath) {
    throw "Parameter 'PluginPath' required"
}

$ManifestFilePath = Join-Path $PluginPath "$PluginName$ManifestExtension"

if ((Test-Path $ManifestFilePath) -and -not $ForceUpdate) {
	Write-Host "$PluginName already has a manifest file, skipping" -ForegroundColor Green
	return
}

Write-Host "Creating or updating SkrManifest for plugin '$PluginName' with version '$FullVersion'" -ForegroundColor Yellow
Write-Host "Plugin path: $PluginPath" -ForegroundColor Yellow

function Get-VersionString {
	param(
        [Switch]$FullVersionString
    )
    $RawVersion = $FullVersion

    # 1. Split into parts and remove any "*" segments
    $VersionParts = ($RawVersion -split '\.')

    if ($VersionParts.Count -ge 4) {
        # Expecting: Major.Minor.Patch.Build
        $major  = $VersionParts[0]
        $minor  = $VersionParts[1]
        $patch  = [int]$VersionParts[2]
        $build  = [int]$VersionParts[3]

		$VersionOutput = "$major.$minor"
		if($FullVersionString)
		{
			# Zero-pad:
			#   patch → 2 digits, build → 3 digits
			$patchPadded = $patch.ToString("00")
			$buildPadded = $build.ToString("000")

			# Combine as: major.minor.PPBBB
			$VersionOutput = "$major.$minor.$patchPadded$buildPadded"
		}
		
	}
	else {
		throw "Version not formated like XX.XX.XX.XX"
	}
    
    return $VersionOutput
}

# Locate and read .uplugin if found
$UPluginFile = Join-Path $PluginPath "$PluginName.uplugin"
Write-Host "Looking for .uplugin file at $UPluginFile" -ForegroundColor Yellow

# Set default values
$UPluginJson = [PSCustomObject]@{
	FriendlyName = $PluginName
	Description  = "Content plugin for $PluginName"
	CreatedBy    = "SkrTechnologies"
	Plugins      = @()
}

$LoadType = ""
if (-not (Test-Path $UPluginFile)) {
	Write-Host "Cannot find .uplugin file at $UPluginFile. Import as content plugin"
	$LoadType = "Content"
}
else
{
	# Parse .uplugin JSON
	$UPluginJson = Get-Content $UPluginFile -Raw | ConvertFrom-Json
}

$FullVersionString = Get-VersionString -FullVersionString
$ShortVersionString = Get-VersionString

# Initialize manifest: load existing if present, else new ordered hashtable
$Manifest = [ordered]@{}
if (Test-Path $ManifestFilePath) {
	$Existing = Get-Content $ManifestFilePath -Raw | ConvertFrom-Json
	foreach ($prop in $Existing.PSObject.Properties) {
		# Copy primitive props
		if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
			# Convert nested objects to ordered hashtable
			$sub = [ordered]@{}
			foreach ($subProp in $prop.Value.PSObject.Properties) {
				$sub[$subProp.Name] = $subProp.Value
			}
			$Manifest[$prop.Name] = $sub
		} else {
			$Manifest[$prop.Name] = $prop.Value
		}
	}
}

# Helper: set if missing or empty
function Set-Field { param($Name, $Value, $forceUpdate)
	if ($forceUpdate -or -not $Manifest.Contains($Name) -or -not $Manifest[$Name]) { $Manifest[$Name] = $Value }
}

$packageCategory = "Extension"
if($IsPlugin)
{
	$packageCategory = "Plugin"
}

# Populate fields only if absent
Set-Field Name          	$PluginName
Set-Field DisplayName   	$UPluginJson.FriendlyName
Set-Field Description   	$UPluginJson.Description
Set-Field Version       	$FullVersionString $true
Set-Field PackageCategory   $packageCategory

# Handle PackageDependencies: convert to map of Name->Version
if (-not $Manifest.Contains('PackageDependencies') -or -not $Manifest['PackageDependencies']) 
{
	$depsMap = [ordered]@{}
	foreach ($Dep in $UPluginJson.Plugins) {
		if ($DependencyWhiteList -contains $Dep.Name) {
			$depsMap[$Dep.Name] = $ShortVersionString
		}
	}
	$Manifest['PackageDependencies'] = $depsMap
}
else 
{
	# Ensure existing entries map properly
	$existingPD = $Manifest['PackageDependencies']
	
	# Update existing entries
	foreach ($name in @($existingPD.Keys)) {
		if ($DependencyWhiteList -contains $name) {
			$existingPD[$name] = $ShortVersionString
		}
	}
	# Add any new dependencies from .uplugin
	foreach ($Dep in $UPluginJson.Plugins) {
		if ($DependencyWhiteList -contains $Dep.Name -and -not $existingPD.Contains($Dep.Name)) {
			$existingPD[$Dep.Name] = $ShortVersionString
		}
	}
	$Manifest['PackageDependencies'] = $existingPD
}

# Handle PackageMetadatas
if (-not $Manifest.Contains('PackageMetadatas') -or -not $Manifest['PackageMetadatas']) {
	if($IsPlugin)
	{
		$Manifest['PackageMetadatas'] = [ordered]@{
			'OptionalPlugin' = 'false'
			'LoadType' = 'Plugin'
		}
	}
	else
	{
		$Manifest['PackageMetadatas'] = [ordered]@{
			'ShowInExtensionList' = 'true'
			'IsEnabledByDefault' = 'false'
		}
	}
} else {
	$Meta = $Manifest['PackageMetadatas']
	if($IsPlugin)
	{
		if (-not $Meta.Contains('OptionalPlugin')) { $Meta.Add('OptionalPlugin', 'false') }
		if (-not $Meta.Contains('LoadType')) { $Meta.Add('LoadType', 'Plugin') }
	}
	else
	{
		if (-not $Meta.Contains('ShowInExtensionList')) { $Meta.Add('ShowInExtensionList', 'true') }
		if (-not $Meta.Contains('IsEnabledByDefault')) { $Meta.Add('IsEnabledByDefault', 'false') }
	}
}

$HostAppName = 'SkyrealVR'
if($EditorManifest)
{
	$HostAppName = 'Unreal'
}

if (-not $Manifest.Contains('HostApps') -or -not $Manifest['HostApps']) {
	# Represent HostApps as a map of app names to version strings
	$Manifest['HostApps'] = [ordered]@{
		$HostAppName = $ShortVersionString
	}
}
else
{
	# Update existing SkyrealVR version
	$HostApps = $Manifest['HostApps']
	$HostApps.Clear()
	$HostApps[$HostAppName] = $ShortVersionString
}

Set-Field Description $UPluginJson.Description
Set-Field Author      $UPluginJson.CreatedBy

# Write out
$Manifest | ConvertTo-Json -Depth 10 |
	Out-File -FilePath $ManifestFilePath -Encoding UTF8

Write-Host "Updated manifest for '$PluginName'" -ForegroundColor Cyan