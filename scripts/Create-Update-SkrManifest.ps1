[CmdletBinding()]
param(
    [switch]$ForceUpdate
)

# Load variables
$Variables        = & (Join-Path $PSScriptRoot 'Get-Variables.ps1')
$ManifestExtension = '.skrmanifest'
$UProjectfile      = $Variables.InputUnrealProject
$UProjectPath      = (Get-Item $UProjectfile).Directory

# Shorten version: trim wildcard and drop zero patch
$RawVersion = $Variables.Version
# Split into parts, remove trailing wildcard if present
$VersionParts = ($RawVersion -split '\.') | Where-Object { $_ -ne '*' }

if ($VersionParts.Count -ge 3) {
    # If patch is non-zero, include it; otherwise omit
    if ($VersionParts[2] -ne '0') {
        $ShortVersion = "$($VersionParts[0]).$($VersionParts[1]).$($VersionParts[2])"
    } else {
        $ShortVersion = "$($VersionParts[0]).$($VersionParts[1])"
    }
} elseif ($VersionParts.Count -ge 2) {
    $ShortVersion = "$($VersionParts[0]).$($VersionParts[1])"
} else {
    $ShortVersion = $RawVersion
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
    Set-Field Version       	$ShortVersion $true
	Set-Field PackageCategory   "Extension"

	# Handle PackageDependencies: convert to map of Name->Version
    if (-not $Manifest.Contains('PackageDependencies') -or -not $Manifest['PackageDependencies']) 
	{
        $depsMap = [ordered]@{}
        foreach ($Dep in $UPluginJson.Plugins) {
            if ($Variables.ExtensionsPlugins -contains $Dep.Name) {
                $depsMap[$Dep.Name] = $ShortVersion
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
                $existingPD[$name] = $ShortVersion
            }
        }
        # Add any new dependencies from .uplugin
        foreach ($Dep in $UPluginJson.Plugins) {
            if ($Variables.ExtensionsPlugins -contains $Dep.Name -and -not $existingPD.Contains($Dep.Name)) {
                $existingPD[$Dep.Name] = $ShortVersion
            }
        }
        $Manifest['PackageDependencies'] = $existingPD
    }
	
	# Handle PackageMetadatas: ensure ShowInExtensionList and Cooked
    if (-not $Manifest.Contains('PackageMetadatas') -or -not $Manifest['PackageMetadatas']) {
        $Manifest['PackageMetadatas'] = [ordered]@{
            'ShowInExtensionList' = 'True'
        }
    } else {
        $Meta = $Manifest['PackageMetadatas']
        if (-not $Meta.Contains('ShowInExtensionList')) { $Meta.Add('ShowInExtensionList', 'True') }
    }

	if (-not $Manifest.Contains('HostApps') -or -not $Manifest['HostApps']) {
        # Represent HostApps as a map of app names to version strings
        $Manifest['HostApps'] = [ordered]@{
            'SkyrealVR' = $ShortVersion
        }
    }
	else
	{
		# Update existing SkyrealVR version
		$HostApps = $Manifest['HostApps']
        if ($HostApps.Contains('SkyrealVR')) {
            $HostApps['SkyrealVR'] = $ShortVersion
		}
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
