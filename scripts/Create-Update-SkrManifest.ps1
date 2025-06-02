[CmdletBinding()]
param(
    [switch]$ForceUpdate,
	[switch]$EditorManifest
)

# Load variables
$Variables        = & (Join-Path $PSScriptRoot 'Get-Variables.ps1')
$ManifestExtension = '.skrmanifest'
$UProjectfile      = $Variables.InputUnrealProject
$UProjectPath      = (Get-Item $UProjectfile).Directory

function Get-VersionString {
	param(
        [Switch]$FullVersionString
    )
    $RawVersion = $Variables.FullVersion

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

function Update-PluginManifestFile {
    param(
        [string]$PluginName,
        [string]$PluginPath,
        [string]$ManifestFilePath
    )

    # Locate .uplugin
    $UPluginFile = Join-Path $PluginPath "$PluginName.uplugin"
    if (-not (Test-Path $UPluginFile)) {
        Write-Warning "Cannot find .uplugin file at $UPluginFile. Skipping."
        return
    }
	
	$FullVersionString = Get-VersionString -FullVersionString
	$ShortVersionString = Get-VersionString

    # Parse .uplugin JSON
    $UPluginJson = Get-Content $UPluginFile -Raw | ConvertFrom-Json

	# Initialize manifest: load existing if present, else new ordered hashtable
    if (Test-Path $ManifestFilePath) {
        $Existing = Get-Content $ManifestFilePath -Raw | ConvertFrom-Json
        $Manifest = [ordered]@{}
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
    } else {
        $Manifest = [ordered]@{}
    }

    # Helper: set if missing or empty
    function Set-Field { param($Name, $Value, $forceUpdate)
        if ($forceUpdate -or -not $Manifest.Contains($Name) -or -not $Manifest[$Name]) { $Manifest[$Name] = $Value }
    }

    # Populate fields only if absent
    Set-Field Name          	$PluginName
    Set-Field DisplayName   	$UPluginJson.FriendlyName
	Set-Field Description   	$UPluginJson.Description
    Set-Field Version       	$FullVersionString $true
	Set-Field PackageCategory   "Extension"

	# Handle PackageDependencies: convert to map of Name->Version
    if (-not $Manifest.Contains('PackageDependencies') -or -not $Manifest['PackageDependencies']) 
	{
        $depsMap = [ordered]@{}
        foreach ($Dep in $UPluginJson.Plugins) {
            if ($Variables.ExtensionsPlugins -contains $Dep.Name) {
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
            if ($Variables.ExtensionsPlugins -contains $name) {
                $existingPD[$name] = $ShortVersionString
            }
        }
        # Add any new dependencies from .uplugin
        foreach ($Dep in $UPluginJson.Plugins) {
            if ($Variables.ExtensionsPlugins -contains $Dep.Name -and -not $existingPD.Contains($Dep.Name)) {
                $existingPD[$Dep.Name] = $ShortVersionString
            }
        }
        $Manifest['PackageDependencies'] = $existingPD
    }
	
	# Handle PackageMetadatas: ensure ShowInExtensionList and Cooked
    if (-not $Manifest.Contains('PackageMetadatas') -or -not $Manifest['PackageMetadatas']) {
        $Manifest['PackageMetadatas'] = [ordered]@{
            'ShowInExtensionList' = 'true'
			'IsEnabledByDefault' = 'false'
        }
    } else {
        $Meta = $Manifest['PackageMetadatas']
        if (-not $Meta.Contains('ShowInExtensionList')) { $Meta.Add('ShowInExtensionList', 'true') }
		if (-not $Meta.Contains('IsEnabledByDefault')) { $Meta.Add('IsEnabledByDefault', 'false') }
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
}

# Main loop
foreach ($PluginName in $Variables.ExtensionsPlugins) {
    $PluginFolder     = Join-Path $UProjectPath (Join-Path 'Plugins' $PluginName)
    $ManifestFilePath = Join-Path $PluginFolder ("$PluginName$ManifestExtension")

    if (!(Test-Path $ManifestFilePath) -or $ForceUpdate) {
        Update-PluginManifestFile -PluginName $PluginName -PluginPath $PluginFolder -ManifestFilePath $ManifestFilePath
    } else {
        Write-Host "$PluginName already has a manifest file, skipping" -ForegroundColor Green
    }
}
