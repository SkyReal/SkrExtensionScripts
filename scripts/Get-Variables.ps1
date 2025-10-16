# Normalizes a boolean property in an object by forcing its value to $true or $false, or adds it with $false if missing.
function Normalize-BoolVariable {
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$VariablesDocument,

        [Parameter(Mandatory=$true)]
        [string]$PropertyName,

        [Parameter(Mandatory=$false)]
        [boolean]$DefaultValue = $false
    )

    if (-not $VariablesDocument.PSObject.Properties[$PropertyName]) {
        $VariablesDocument | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $DefaultValue
    } else {
        $value = $VariablesDocument.$PropertyName.ToString().ToLower()
        if ($value -eq "true" -or $value -eq "`$true") {
            $VariablesDocument.$PropertyName = $true
        } else {
            $VariablesDocument.$PropertyName = $false
        }
    }
}

# Main
if ($PSVersionTable.PSVersion.Major -lt 6) {
    throw "PowerShell version lower than 6 is not supported : $($PSVersionTable.PSVersion)."
}

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

# Normalize Unreal directory
if (-not ($VariablesDocument.PSObject.Properties.Name -contains "UnrealEditorRootDirLocalFullPath") -or (-not (Test-Path $VariablesDocument.UnrealEditorRootDirLocalFullPath)))
{
	$UEEditorEnvVariable = $VariablesDocument.UnrealEditorEnvironmentVariable
	$UEPath = (Get-Item -ErrorAction SilentlyContinue -Path "Env:$UEEditorEnvVariable").Value
	$VariablesDocument | Add-Member -Force -MemberType NoteProperty -Name 'UnrealEditorRootDirLocalFullPath' -Value $UEPath
	if (-not (Test-Path $VariablesDocument.UnrealEditorRootDirLocalFullPath))
	{
		Write-Warning "Warning, UnrealEditorRootDirLocalFullPath of UnrealEditorEnvironmentVariable variable in Variable.json is invalid."
	}
}

$VariablesDocument.OutputBuildDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.OutputBuildDir 
$VariablesDocument.OutputInstallDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.OutputInstallDir 
$VariablesDocument.InputUnrealProject = Join-Path $jsonVariableFileDirectory $VariablesDocument.InputUnrealProject 
$VariablesDocument.PluginDownloadDir = Join-Path $jsonVariableFileDirectory $VariablesDocument.PluginDownloadDir 
$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'OutputBuildDirCook' -Value (Join-Path $VariablesDocument.OutputBuildDir "Cook")
$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'OutputBuildDirEditor' -Value (Join-Path $VariablesDocument.OutputBuildDir "Editor")
if (-not $VariablesDocument.PSObject.Properties['Hooks']) {
    $VariablesDocument | Add-Member -MemberType NoteProperty -Name 'Hooks' -Value @()
}
foreach ($hook in $VariablesDocument.Hooks) {
    $hook.path = Join-Path $jsonVariableFileDirectory $hook.path
	if (-Not (Test-Path -Path $hook.path)) {
        Write-Warning "The hook script file doesn't exists ($fullPath)"
    }
}

if (-not $VariablesDocument.PSObject.Properties['FullVersion']) {
    $VariablesDocument | Add-Member -MemberType NoteProperty -Name 'FullVersion' -Value "0.0.0.0"
}

$VariablesDocument.FullVersion = $VariablesDocument.Version + "." + $VariablesDocument.VersionBuildCounter
if ($VariablesDocument.FullVersion -notmatch "^\d+(\.\d+){3}$") {
	throw [System.FormatException]::new($VariablesDocument.FullVersion + " is not valid (should be X.X.X.X).")
}


$outputModified = $false
# Ensure Output field exists and is an array with at least one object
if (-not $VariablesDocument.Output) {
	$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'Output' -Value @([PSCustomObject]@{})
    $outputModified = $true
}
elseif ($VariablesDocument.Output -isnot [System.Collections.IEnumerable]) {
    $VariablesDocument.Output = @($VariablesDocument.Output)
}
elseif ($VariablesDocument.Output.Count -eq 0) {
    $VariablesDocument.Output += [PSCustomObject]@{}
    $outputModified = $true
}

if ($outputModified) {
	# This means that the Variable.Json is in legacy mode
	Normalize-BoolVariable -VariablesDocument $VariablesDocument -PropertyName "OutputCook" -DefaultValue $true
	Normalize-BoolVariable -VariablesDocument $VariablesDocument -PropertyName "OutputCookAsPakFile"
	Normalize-BoolVariable -VariablesDocument $VariablesDocument -PropertyName "OutputEditor" 
	Normalize-BoolVariable -VariablesDocument $VariablesDocument -PropertyName "OutputEditorAsPakFile"
	Normalize-BoolVariable -VariablesDocument $VariablesDocument -PropertyName "OutputCompressed" -DefaultValue $true


	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'Name' -Value $VariablesDocument.InstallerName
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'ProductUpgradeCode' -Value $VariablesDocument.ProductUpgradeCode
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'ExtensionsPlugins' -Value $VariablesDocument.ExtensionsPlugins
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'OutputCook' -Value $VariablesDocument.OutputCook
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'OutputCookAsPakFile' -Value $VariablesDocument.OutputCookAsPakFile
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'OutputEditor' -Value $VariablesDocument.OutputEditor
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'OutputEditorAsPakFile' -Value $VariablesDocument.OutputEditorAsPakFile
	$VariablesDocument.Output[0] | Add-Member -MemberType NoteProperty -Name 'OutputCompressed' -Value $VariablesDocument.OutputCompressed

}
	
# Clean legacy variables
$VariablesDocument.PSObject.Properties.Remove('Name')
$VariablesDocument.PSObject.Properties.Remove('ProductUpgradeCode')
$VariablesDocument.PSObject.Properties.Remove('ExtensionsPlugins')
$VariablesDocument.PSObject.Properties.Remove('OutputCook')
$VariablesDocument.PSObject.Properties.Remove('OutputCookAsPakFile')
$VariablesDocument.PSObject.Properties.Remove('OutputEditor')
$VariablesDocument.PSObject.Properties.Remove('OutputEditorAsPakFile')
$VariablesDocument.PSObject.Properties.Remove('OutputCompressed')


$allPlugins = New-Object 'System.Collections.Generic.HashSet[System.String]'
$allPluginsToCook = New-Object 'System.Collections.Generic.HashSet[System.String]'
$allPluginsToCookAndPak = New-Object 'System.Collections.Generic.HashSet[System.String]'
$allPluginsToEditor = New-Object 'System.Collections.Generic.HashSet[System.String]'
$allPluginsToEditorAndPak = New-Object 'System.Collections.Generic.HashSet[System.String]'
foreach ($obj in $VariablesDocument.Output) {
	if ($obj.ProductUpgradeCode -eq "641C1FE1-7B3E-4184-92B4-DD701FE7F4E9") {
		Write-Warning "Warning, ProductUpgradeCode variable in Variable.json should be changed (ignore this warning on sample project)."
	}
	if ($obj.ExtensionsPlugins) {
		
        $obj.ExtensionsPlugins | ForEach-Object { $null = $allPlugins.Add($_) }
		if ($obj.OutputCook -eq $true) {
			$obj.ExtensionsPlugins | ForEach-Object { $null = $allPluginsToCook.Add($_) }
		}
		if ($obj.OutputCookAsPakFile -eq $true) {
			$obj.ExtensionsPlugins | ForEach-Object { $null = $allPluginsToCookAndPak.Add($_) }
		}
		if ($obj.OutputEditor -eq $true) {
			$obj.ExtensionsPlugins | ForEach-Object { $null = $allPluginsToEditor.Add($_) }
		}
		if ($obj.OutputEditorAsPakFile -eq $true) {
			$obj.ExtensionsPlugins | ForEach-Object { $null = $allPluginsToEditorAndPak.Add($_) }
		}
    }
	
	Normalize-BoolVariable -VariablesDocument $obj -PropertyName "OutputAsSinglePackage" -DefaultValue $false
	Normalize-BoolVariable -VariablesDocument $obj -PropertyName "OutputCook" -DefaultValue $true
	Normalize-BoolVariable -VariablesDocument $obj -PropertyName "OutputCookAsPakFile"
	Normalize-BoolVariable -VariablesDocument $obj -PropertyName "OutputEditor" 
	Normalize-BoolVariable -VariablesDocument $obj -PropertyName "OutputEditorAsPakFile"
	Normalize-BoolVariable -VariablesDocument $obj -PropertyName "OutputCompressed" -DefaultValue $true
}

$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'AllExtensionsPlugins' -Value $allPlugins
$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'AllExtensionsPlugins_Cook' -Value $allPluginsToCook
$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'AllExtensionsPlugins_CookAndPAK' -Value $allPluginsToCookAndPak
$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'AllExtensionsPlugins_Editor' -Value $allPluginsToEditor
$VariablesDocument | Add-Member -MemberType NoteProperty -Name 'AllExtensionsPlugins_EditorAndPAK' -Value $allPluginsToEditorAndPak


# Uncomment this line to display JSon
# $VariablesDocument | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Host $_ }

return $VariablesDocument