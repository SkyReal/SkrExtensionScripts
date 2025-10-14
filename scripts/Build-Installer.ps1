# Load the .net assembly for ZipArchive and ZipFile:
Add-Type -AssemblyName 'System.IO.Compression'
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'

# Load variables
$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)
foreach ($hook in $Variables.Hooks) {
    if ($hook.trigger -eq "build_installer_before") {
        $scriptPath = $hook.path
        
        if (Test-Path -Path $scriptPath) {
            Write-Host "Execute hook before building installer ($scriptPath)"
            & $scriptPath 
        }
    }
}

$Version = $Variables.FullVersion
$SkyRealVersion = $Variables.SkyRealVersion
$ProductUpgradeCode = $Variables.ProductUpgradeCode
$InstallerName = $Variables.InstallerName
$OutputBuildDir = $Variables.OutputBuildDir
$OutputCookDir = $Variables.OutputBuildDirCook
$OutputEditorDir = $Variables.OutputBuildDirEditor
$OutputInstallDir = $Variables.OutputInstallDir
$CompanyName = $Variables.CompanyName
$AdditionalInstallersScripts = $Variables.AdditionalInstallersScripts

$Plugins = $Variables.ExtensionsPlugins
$UProjectfile = $Variables.InputUnrealProject
$UProjectPath = (Get-Item $UProjectfile).Directory

$RepositoryPath = Resolve-Path (Join-Path $PSScriptRoot "..")
$ExtensionInstallerSourcePath = (Join-Path (Join-Path $RepositoryPath "installers") "src")
$SkrAppBaseFileName = $InstallerName + " " + $Version
$SkrTmpZipFilePath = (Join-Path $OutputInstallDir "tmp.zip")
$SkrAppFilePath = (Join-Path $OutputInstallDir ($SkrAppBaseFileName + ".skrapp"))
$EditorZipFilePath = (Join-Path $OutputInstallDir ($SkrAppBaseFileName + "_Editor.zip"))

$barLength = 40
$consoleWidth = $Host.UI.RawUI.WindowSize.Width

Write-Host "Clean and recreate output directory $OutputInstallDir"
If (Test-Path -Path $OutputInstallDir)
{
	Remove-Item -path $OutputInstallDir -Force -Recurse
}
New-Item -Path $OutputInstallDir -ItemType Directory -ErrorAction SilentlyContinue



function Compress-FolderToZip {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceFolder,

        [Parameter(Mandatory=$true)]
        [string]$ZipPath
    )

    Add-Type -AssemblyName 'System.IO.Compression'
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'

	$totalDecompressedSize = 0
    $zipStream = $null
    $archive = $null
    $startTime = Get-Date
    $stopRequested = $false

    # Ctrl+C event
    $cancelEvent = Register-EngineEvent PowerShell.Exiting -Action {
		$global:stopRequested = $true
		Write-Host "`n⛔ Compression process aborted. Cleaning up..."
    }
	
	$startTime = Get-Date
	$index = 0
	
	$zipStream = $null
	$archive = $null
	$outputStream = $null
	$inputStream = $null
	try
	{
		Write-Host "Archive directory $SourceFolder to $ZipPath"
		
		$zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
		$archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
		
		$files = Get-ChildItem -Path $SourceFolder -Exclude *.skrlnk -Recurse -File
	
		foreach ($file in $files) {
			if ($global:stopRequested) { break }
			$index++
			$relativePath = $file.FullName.Substring($SourceFolder.Length + 1)
			$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
			if ($file.Extension -ieq ".pak") {
				$compressionLevel = [System.IO.Compression.CompressionLevel]::NoCompression
			}
			$entry = $archive.CreateEntry($relativePath, $compressionLevel)
			$inputStream = [System.IO.File]::OpenRead($file.FullName)
			$totalDecompressedSize += $inputStream.Length
			$outputStream = $entry.Open()
			$inputStream.CopyTo($outputStream)
			$outputStream.Dispose()
			$outputStream = $null
			$inputStream.Dispose()
			$inputStream = $null
			

			
			$elapsed = (Get-Date) - $startTime
			$percent = [math]::Round(($index / $files.Count) * 100, 1)
			$filled = [int](($percent / 100) * $barLength)
			$bar = ('#' * $filled).PadRight($barLength, '-')
			
			Write-Host "`r" -NoNewline
			Write-Host (" " * ($consoleWidth - 1)) -NoNewline
			Write-Host "`r" -NoNewline
			Write-Host ("`r[{0}] {1}% ({2}/{3}) - {4}s - {5}" -f $bar, $percent, $index, $files.Count, [int]$elapsed.TotalSeconds, $file.Name) -NoNewline
		}
	}
	finally 
	{
		Write-Host ""
		Write-Host "Cleaning memory"
		if ($outputStream) { 
			try { $outputStream.Dispose() } catch {}
		}
		if ($inputStream) { 
			try { $inputStream.Dispose() } catch {}
		}
		if ($archive) { 
			try { $archive.Dispose() } catch {}
		}
		if ($zipStream) { 
			try { $zipStream.Dispose() } catch {}
		}
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
	}
	Write-Host ("Done creating archive file in {0:N1} secondes" -f ((Get-Date) - $startTime).TotalSeconds)
	Write-Host "totalDecompressedSize is $totalDecompressedSize" 
	return $totalDecompressedSize
}



$ArchiveSize = 0

# Zip cook dir
If ($Variables.OutputCook)
{
	Write-Host "Create cook skrapp file"
	$ArchiveSize += Compress-FolderToZip -SourceFolder $OutputCookDir -ZipPath $SkrAppFilePath
}

# Zip editor dir
if($Variables.OutputEditor)
{
	Write-Host "Create editor zip file"
	& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true -EditorManifest $true
	$ArchiveSize += Compress-FolderToZip -SourceFolder $OutputEditorDir -ZipPath $EditorZipFilePath
	& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true -NullVersion
}


# Compute installer size
$ArchiveSize /= 1000
Write-Host "Total archive size will be " $ArchiveSize

# Get NSIS path to create installer
if ($env:NSIS)
{
	$NSISCompilerPath = (Join-Path $env:NSIS "makensis.exe")
}
else 
{
	$NSISCompilerPath = 'C:\Program Files (x86)\NSIS\makensis.exe'
}
If (-not (Test-Path -Path $NSISCompilerPath))
{
	Write-Error "NSIS path not found. Please specify it with NSIS environment variable."
	return
}

# Call NSIS to create installer
Write-Host "Building installer using NSIS Compiler: $NSISCompilerPath"
$location = Get-Location
Set-Location $ExtensionInstallerSourcePath

& "$NSISCompilerPath" /D"PRODUCT_VERSION=$Version" /D"PRODUCT_UPGRADE_CODE=$ProductUpgradeCode" /D"PRODUCT_NAME=$InstallerName" /D"SKYREAL_VERSION=$SkyRealVersion" /D"BUILD_DIR=$OutputInstallDir" /D"COMPANY_NAME=$CompanyName" /D"ARCHIVE_SIZE=$ArchiveSize" main.nsi


If ($? -ne $true) {
    Write-Error "NSIS Failed"
}
else {
    Write-Host "NSIS Completed"
}

Set-Location $location

foreach	($AdditionalInstallersScript in $AdditionalInstallersScripts)
{
	& "$AdditionalInstallersScript" 
}


foreach ($hook in $Variables.Hooks) {
    if ($hook.trigger -eq "build_installer_after") {
        $scriptPath = $hook.path
        
        if (Test-Path -Path $scriptPath) {
            Write-Host "Execute hook after building installer ($scriptPath)"
            & $scriptPath 
        }
    }
}