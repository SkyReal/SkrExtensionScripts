$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)

foreach ($hook in $Variables.Hooks) {
    if ($hook.trigger -eq "build_extension_before") {
        $scriptPath = $hook.path
        
        if (Test-Path -Path $scriptPath) {
            Write-Host "Execute hook before building extension with Unreal ($scriptPath)"
            & $scriptPath 
        }
    }
}

$UEPath = $Variables.UnrealEditorRootDirLocalFullPath

if ($UEPath -ne $null -And (Test-Path ($UEPath))) {
	Write-Host "UnrealInstallDir FOUND : $UEPath" -ForegroundColor Green
}
else {
	Write-Host "UnrealInstallDir NOT FOUND : $UEPath" -ForegroundColor Red
	return -1;
}


# Change $PluginName and $ProjectName according to your project
$Plugins = $Variables.ExtensionsPlugins
$ProjectName = "Playground"

# define variables
Write-Host "Define variables" -ForegroundColor Green
$UProjectfile = $Variables.InputUnrealProject
$UProjectPath = (Get-Item $UProjectfile).Directory

#Output directory path
$OutputDir = $Variables.OutputBuildDir
$OutputCookDir = $Variables.OutputBuildDirCook
$OutputEditorDir = $Variables.OutputBuildDirEditor

function Clean-Dir
{
	param([String]$DirToClean)
    if (Test-Path $DirToClean) {
        Write-Host "Directory $DirToClean exists, delete it." -ForegroundColor Green
        Remove-Item -Recurse -Force $DirToClean
    }
    else {
        Write-Host "Directory $DirToClean doesn't 'exists, ignore delete step." -ForegroundColor Green
    }
}

function Execute-SkrProcess([String]$ProgramToRun, [String]$ProgramArgs)
{
    $buildProcess = [System.Diagnostics.Process]@{
      StartInfo = @{
        FileName = $ProgramToRun
        Arguments = $ProgramArgs
        RedirectStandardOutput = $true
        RedirectStandardError = $true
        UseShellExecute = $false
        CreateNoWindow = $true
        WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        WorkingDirectory = $PSScriptRoot
      }
    }

    # Add IO redirection
    $stdout = New-Object System.Text.StringBuilder
    $stderr = New-Object System.Text.StringBuilder
    $stdoutEvent = Register-ObjectEvent $buildProcess -EventName OutputDataReceived -MessageData $stdout -Action {
        $Event.MessageData.AppendLine($Event.SourceEventArgs.Data)
    }

    $stderrEvent = Register-ObjectEvent $buildProcess -EventName ErrorDataReceived -MessageData $stderr -Action {
        $Event.MessageData.AppendLine($Event.SourceEventArgs.Data)
    }
    
    # Run process
	Write-Host "Call $ProgramToRun with params $ProgramArgs" -ForegroundColor Green
	try { $buildProcess.Start() | out-null }
	catch {
        Write-Error "Exception while trying to build SLN => $_"
        return -1
	}
    $buildProcess.BeginOutputReadLine()
    $buildProcess.BeginErrorReadLine()
	$buildProcess.WaitForExit()
    [int] $result = $buildProcess.ExitCode
    $buildProcess.Close()

    # Unregister and write IO redirection
    Unregister-Event $stdoutEvent.Id
    Unregister-Event $stderrEvent.Id
    if (!([string]::IsNullOrWhiteSpace($stdout.ToString())))
	{
        Write-Host $stdout.ToString() -ForegroundColor Green
    }
    if (!([string]::IsNullOrWhiteSpace($stderr.ToString())))
	{
        Write-Error $stderr.ToString()
    }
	Write-Host "Process execution return code : $result" -ForegroundColor Green
    return $result
}


# Clean Output Directory
Clean-Dir -DirToClean $OutputDir
New-Item -ItemType Directory -Force -Path $OutputDir | out-null
	
$unrealPAK=[System.IO.Path]::Combine($UEPath,"Engine","Binaries","Win64","UnrealPak.exe")
$unrealPAKCompressOptions="-compress -compressionformats=oodle -primarycompressionformat=oodle -compressionblocksize=1048576"
$unrealEditorExe=[System.IO.Path]::Combine($UEPath,"Engine","Binaries","Win64","UnrealEditor-Cmd.exe")
$unrealEditorUAT=[System.IO.Path]::Combine($UEPath,"Engine","Build","BatchFiles","RunUAT.bat")

# Cook content
if ($Variables.OutputCook)
{
	# Add Plugin to always cook directories
	$PluginDefaultGameIniPath = Join-Path (Join-Path $UProjectPath "Config") "DefaultGame.ini"
	if(Test-Path -Path $PluginDefaultGameIniPath)
	{
		foreach($Plugin in $Plugins)
		{
			$AlwaysCookPluginLine = (Get-Content -Path $PluginDefaultGameIniPath | Where-Object {$_ -like "*DirectoriesToAlwaysCook=(Path=`"/$Plugin`")"})
			if ($AlwaysCookPluginLine.Count -lt 1)
			{
				Write-Host "Adding $Plugin to Directories to always cook"
				Add-Content -Path $PluginDefaultGameIniPath -Value "+DirectoriesToAlwaysCook=(Path=`"/$Plugin`")"
			}
			else
			{
				Write-Host "$Plugin already registered in directories to always cook" -ForegroundColor Green
			}
		}
	}
	else
	{
		Write-Error "No DefaultGame.ini found" 
		return 14
	}

	# Clean Cooked Directory
	Clean-Dir -DirToClean ([System.IO.Path]::Combine($UProjectPath, "Saved", "Cooked"))

	# Run Cook commandlet
	[String]$cookCommandLine = "  BuildCookRun -nop4 -utf8output -nocompileeditor -skipbuildeditor -cook -project=""$UProjectfile"" -unrealexe=""$unrealEditorExe"" -platform=Win64 -installed -skipstage"
	Write-Host "Cook project with cmd line: $unrealEditorUAT $cookCommandLine" -ForegroundColor Green
	
	$cookResult = (Execute-SkrProcess -ProgramToRun "$unrealEditorUAT" -ProgramArgs "$cookCommandLine")
	if ($cookResult -ne 0) {
		Write-Error "Error while trying to cook. Code=$cookResult"
		return 13
	}
	
	# Check success
	$UECookPluginsOutput = [System.IO.Path]::Combine($UProjectPath, "Saved", "Cooked", "Windows", $ProjectName, "Plugins")
	foreach($Plugin in $Plugins)
	{
		$UECookPluginOutput = [System.IO.Path]::Combine($UECookPluginsOutput, $Plugin)
		Write-Host "Check if plugin has been successfully build by verifiying path $UECookPluginOutput"  -ForegroundColor Green
		if (!(Test-Path "$UECookPluginOutput")) {
			Write-Error "Failed to cook plugin"
			Clean-Dir -DirToClean $OutputDir
			return 1
		}
	}
	
	# Move cook result into output directory
	$plugin_paths = @()
	Write-Host "Move $UECookPluginsOutput to $OutputCookDir"  -ForegroundColor Green
	New-Item -ItemType Directory -Force -Path $OutputCookDir | out-null
	
	foreach($Plugin in $Plugins)
	{
		$UECookPluginOutput = [System.IO.Path]::Combine($UECookPluginsOutput, $Plugin, "Content")
		$OutputCookPluginDir = Join-Path $OutputCookDir $Plugin
		New-Item -ItemType Directory -Force -Path $OutputCookPluginDir | out-null
		
		# Generate Pak of cook data if necessary
		if($Variables.OutputCookAsPakFile)
		{
			$outputCookPakPath = (Join-Path $OutputCookPluginDir "Content.pak")
			[String]$pakCommandLine = "$outputCookPakPath -create=""$UECookPluginOutput"" $unrealPAKCompressOptions"
			$PAKResult = (Execute-SkrProcess -ProgramToRun "$unrealPAK" -ProgramArgs "$pakCommandLine")
			if ($PAKResult -ne 0) {
				Write-Error "Error while trying to PAK $UECookPluginOutput. Code=$PAKResult"
				return 14
			}
		}
		else 
		{
			Move-Item -path $UECookPluginOutput -destination $OutputCookPluginDir 
		}
		
		# Copy plugin files into cook output
		Copy-Item -path (Join-Path (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin) "*.uplugin") -destination $OutputCookPluginDir 
		Copy-Item -path (Join-Path (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin) "Resources") -destination $OutputCookPluginDir  -Recurse
		$manifestPath = (Join-Path (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin) "$Plugin.skrmanifest")
		if(Test-Path $manifestPath)
		{
			Copy-Item $manifestPath -destination $OutputCookPluginDir
		}
		
		# Set ExplicitlyLoaded field to True for cook content
		$pluginOutputPath = (Join-Path $OutputCookPluginDir $Plugin) + ".uplugin"
		$jsonContent = Get-Content -Raw -Path $pluginOutputPath | ConvertFrom-Json
		$jsonContent | Add-Member -MemberType NoteProperty -Name "ExplicitlyLoaded" -Value $true -Force
		$jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $pluginOutputPath
		
		# Register plugin local path
		$pluginOutputRelativePath = (Join-Path $Plugin $Plugin) + ".uplugin"
		$plugin_paths += $pluginOutputRelativePath
	}
	
	# Create extension.json file for cook content
	$json_data = @{
		"api" = 1
		"plugins" = $plugin_paths
	}
	$json_filePath = (Join-Path $OutputCookDir "SkrExtensions.json")
	$json_string = ConvertTo-Json -InputObject $json_data
	$json_string | Set-Content -Path $json_filePath
	
	# Create the .skrlnk file for cook content (use [System.IO.File] to avoid new line at the end of the file)
	$skrlnk_fileName = $Variables.InstallerName + ".skrlnk"
	[System.IO.File]::WriteAllText((Join-Path $OutputCookDir $skrlnk_fileName), $json_filePath)

}


# Move editor plugins to output directories
if ($Variables.OutputEditor)
{
	New-Item -ItemType Directory -Force -Path $OutputEditorDir | out-null
	
	& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true -EditorManifest $true
	
	$plugin_paths = @()
	foreach($Plugin in $Plugins)
	{
		# Register plugin local path
		$pluginOutputRelativePath = (Join-Path $Plugin $Plugin) + ".uplugin"
		$plugin_paths += $pluginOutputRelativePath
		$currentEditorPuginPath = (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin)
		$OutputEditorPluginDir = Join-Path $OutputEditorDir $Plugin
		
		if($Variables.OutputEditorAsPakFile)
		{
			# Generate Pak of editor data if necessary
			$UEEditorPlugin = (Join-Path $currentEditorPuginPath "Content")
			
			$outputEditorPakPath = (Join-Path $OutputEditorPluginDir "Content.pak")
			[String]$pakCommandLine = "$outputEditorPakPath -create=""$UEEditorPlugin"" $unrealPAKCompressOptions"
			$PAKResult = (Execute-SkrProcess -ProgramToRun "$unrealPAK" -ProgramArgs "$pakCommandLine")
			if ($PAKResult -ne 0) {
				Write-Error "Error while trying to PAK $UEEditorPlugin. Code=$PAKResult"
				return 15
			}
			# Copy plugin files into editor output
			Copy-Item -path (Join-Path $currentEditorPuginPath "*.uplugin") -destination $OutputEditorPluginDir 
			Copy-Item -path (Join-Path $currentEditorPuginPath "Resources") -destination $OutputEditorPluginDir  -Recurse
			$manifestPath = (Join-Path $currentEditorPuginPath "$Plugin.skrmanifest")
			if(Test-Path $manifestPath)
			{
				Copy-Item $manifestPath -destination $OutputEditorPluginDir
			}
			
			# Set ExplicitlyLoaded field to True for editor
			$pluginOutputPath = (Join-Path $OutputEditorPluginDir $Plugin) + ".uplugin"
			$jsonContent = Get-Content -Raw -Path $pluginOutputPath | ConvertFrom-Json
			$jsonContent | Add-Member -MemberType NoteProperty -Name "ExplicitlyLoaded" -Value $true -Force
			$jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $pluginOutputPath
		}
		else
		{
			# Create symlink to the editor plugin
			$SymlinkFrom = $currentEditorPuginPath
			$SymlinkTo = $OutputEditorPluginDir
			Write-Host "From = " + $SymlinkFrom + " / to = " $SymlinkTo
			If (Test-Path -Path $SymlinkTo) {
				# Delete legacy directory if exists to replace it by symlink
				Remove-Item -Recurse -Force $SymlinkTo
			}
			New-Item -ItemType Directory -Force -Path $SymlinkFrom | Out-Null
			New-Item -ItemType Directory -Force -Path (Split-Path $SymlinkTo) | Out-Null
			New-Item -ItemType SymbolicLink -Path $SymlinkTo -Target $SymlinkFrom -Force
		}
	}
	
	# Create extension.json file for editor content
	$json_data = @{
		"api" = 1
		"plugins" = $plugin_paths
	}
	$json_filePath = (Join-Path $OutputEditorDir "SkrExtensions.json")
	$json_string = ConvertTo-Json -InputObject $json_data
	$json_string | Set-Content -Path $json_filePath
	
	# Create the .skrlnk file for editor content (use [System.IO.File] to avoid new line at the end of the file)
	$skrlnk_fileName = $Variables.InstallerName + ".skrlnk"
	[System.IO.File]::WriteAllText((Join-Path $OutputEditorDir $skrlnk_fileName), $json_filePath)
		
	& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true -NullVersion
}


foreach ($hook in $Variables.Hooks) {
    if ($hook.trigger -eq "build_extension_after") {
        $scriptPath = $hook.path
        
        if (Test-Path -Path $scriptPath) {
            Write-Host "Execute hook after building extension with Unreal ($scriptPath)"
            & $scriptPath 
        }
    }
}

return 0