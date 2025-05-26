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

# Clean Output Directory
Clean-Dir -DirToClean $OutputDir

# Clean Cooked Directory
Clean-Dir -DirToClean ([System.IO.Path]::Combine($UProjectPath, "Saved", "Cooked"))

# Cook content
# Run Cook commandlet
$unrealEditorExe=[System.IO.Path]::Combine($UEPath,"Engine","Binaries","Win64","UnrealEditor-Cmd.exe")
$unrealEditorUAT=[System.IO.Path]::Combine($UEPath,"Engine","Build","BatchFiles","RunUAT.bat")
[String]$cookCommandLine = "  BuildCookRun -nop4 -utf8output -nocompileeditor -skipbuildeditor -cook -project=""$UProjectfile"" -unrealexe=""$unrealEditorExe"" -platform=Win64 -installed -skipstage"
Write-Host "Cook project with cmd line: $unrealEditorUAT $cookCommandLine" -ForegroundColor Green

$cookResult = (Execute-SkrProcess -ProgramToRun "$unrealEditorUAT" -ProgramArgs "$cookCommandLine")
if ($cookResult -ne 0) {
	Write-Error "Error while trying to cook. Code=$cookResult"
	return 13
}


# Check success
$outputCookDir = [System.IO.Path]::Combine($UProjectPath, "Saved", "Cooked", "Windows", $ProjectName, "Plugins")
foreach($Plugin in $Plugins)
{
	$outputCookDirTmp = [System.IO.Path]::Combine($outputCookDir, $Plugin)
	Write-Host "Check if plugin has been successfully build by verifiying path $outputCookDir"  -ForegroundColor Green
	if (!(Test-Path "$outputCookDir")) {
		Write-Error "Failed to cook plugin"
		Clean-Dir -DirToClean $OutputDir
		return 1
	}
}


# Move result into output directory
$plugin_paths = @()
$outputCookDirContent = (Join-Path $outputCookDir "*")
Write-Host "Move $outputCookDirContent to $OutputDir"  -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $OutputDir | out-null

foreach($Plugin in $Plugins)
{
	$outputCookDirTmp = [System.IO.Path]::Combine($outputCookDir, $Plugin, "Content")
	$OutputPluginDir = Join-Path $OutputDir $Plugin
	New-Item -ItemType Directory -Force -Path $OutputPluginDir | out-null
	Move-Item -path $outputCookDirTmp -destination $OutputPluginDir 
	Copy-Item -path (Join-Path (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin) "*.uplugin") -destination $OutputPluginDir 
	Copy-Item -path (Join-Path (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin) "Resources") -destination $OutputPluginDir  -Recurse
	
	$manifestPath = (Join-Path (Join-Path (Join-Path $UProjectPath "Plugins") $Plugin) "$Plugin.skrmanifest")
	if(Test-Path $manifestPath)
	{
		Copy-Item $manifestPath -destination $OutputPluginDir
	}
	
	# Set ExplicitlyLoaded field to True
	$pluginOutputPath = (Join-Path $OutputPluginDir $Plugin) + ".uplugin"
	$jsonContent = Get-Content -Raw -Path $pluginOutputPath | ConvertFrom-Json
	$jsonContent | Add-Member -MemberType NoteProperty -Name "ExplicitlyLoaded" -Value $true -Force
	$jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $pluginOutputPath
	
	# Register plugin local path
	$pluginOutputRelativePath = (Join-Path $Plugin $Plugin) + ".uplugin"
	$plugin_paths += $pluginOutputRelativePath
}

# Create extension.json file
$json_data = @{
    "api" = 1
    "plugins" = $plugin_paths
}
$json_filePath = (Join-Path $OutputDir "SkrExtensions.json")
$json_string = ConvertTo-Json -InputObject $json_data
$json_string | Set-Content -Path $json_filePath

# Create the .skrlnk file
$skrlnk_fileName = $Variables.InstallerName + ".skrlnk"
$json_filePath | Set-Content -Path (Join-Path $OutputDir $skrlnk_fileName)


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