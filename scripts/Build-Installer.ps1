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
$OutputBuildDir = $Variables.OutputBuildDir
$OutputCookDir = $Variables.OutputBuildDirCook
$OutputEditorDir = $Variables.OutputBuildDirEditor
$OutputInstallDir = $Variables.OutputInstallDir
$CompanyName = $Variables.CompanyName

$UProjectfile = $Variables.InputUnrealProject
$UProjectPath = (Get-Item $UProjectfile).Directory

$RepositoryPath = Resolve-Path (Join-Path $PSScriptRoot "..")
$ExtensionInstallerSourcePath = (Join-Path (Join-Path $RepositoryPath "installers") "src")

$barLength = 40
$consoleWidth = $Host.UI.RawUI.WindowSize.Width

Write-Host "Clean and recreate output directory $OutputInstallDir"
If (Test-Path -Path $OutputInstallDir)
{
	Remove-Item -path $OutputInstallDir -Force -Recurse
}
New-Item -Path $OutputInstallDir -ItemType Directory -ErrorAction SilentlyContinue

function Create-Zip {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ZipPath
    )
	$zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
	$archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
	
	return @{
        ZipStream = $zipStream
        Archive   = $archive
    }
}

function Close-Zip {
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory=$true)]
        [System.IO.FileStream]$ZipStream
    )
	if ($Archive) { 
		try { $Archive.Dispose() } catch {}
	}
	if ($ZipStream) { 
		try { $ZipStream.Dispose() } catch {}
	}
	[System.GC]::Collect()
	[System.GC]::WaitForPendingFinalizers()
}

function Compress-FileToZip {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceFolder,
		
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$SourceFile,

        [Parameter(Mandatory=$true)]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter(Mandatory=$false)]
        [string]$InnerArchiveRootPath,

        [Parameter(Mandatory=$true)]
        [bool]$OutputCompressed
    )
	
	try
	{
		$relativePath = $SourceFile.FullName.Substring($SourceFolder.Length + 1)
		if ($InnerArchiveRootPath) {
			$relativePath = Join-Path $InnerArchiveRootPath $relativePath
		}
		$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
		if (($SourceFile.Extension -ieq ".pak") -or (-not $OutputCompressed)) {
			$compressionLevel = [System.IO.Compression.CompressionLevel]::NoCompression
		}
		$entry = $Archive.CreateEntry($relativePath, $compressionLevel)
		$inputStream = [System.IO.File]::OpenRead($SourceFile.FullName)
		$totalDecompressedSize += $inputStream.Length
		$outputStream = $entry.Open()
		$inputStream.CopyTo($outputStream)
	} finally {
		if ($outputStream) { 
			try { $outputStream.Dispose() } catch {}
		}
		if ($inputStream) { 
			try { $inputStream.Dispose() } catch {}
		}
	}
}

function Compress-FolderToZip {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceFolder,
		
        [Parameter(Mandatory = $true)]
        [string[]]$SubFoldersToInclude,

        [Parameter(Mandatory=$true)]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter(Mandatory=$false)]
        [string]$InnerArchiveRootPath,

        [Parameter(Mandatory=$true)]
        [bool]$OutputCompressed
    )
	$totalDecompressedSize = 0
    $startTime = Get-Date
	$index = 0
	
	Write-Host "Archive directory $SourceFolder"
	
	foreach ($subFolder in $SubFoldersToInclude) {
		$subFolderFullPath = Join-Path $SourceFolder $subFolder
		
		$files = Get-ChildItem -Path $subFolderFullPath -Exclude *.skrlnk -Recurse -File
	
		foreach ($file in $files) {
			$index++
			
			Compress-FileToZip -SourceFolder $SourceFolder -SourceFile $file -Archive $Archive -OutputCompressed $OutputCompressed -InnerArchiveRootPath $InnerArchiveRootPath
			
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
	
	Write-Host ("Done archiving directory in {0:N1} secondes" -f ((Get-Date) - $startTime).TotalSeconds)
	Write-Host "totalDecompressedSize is $totalDecompressedSize" 
	return $totalDecompressedSize
}


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


# Generate installers
Write-Host "Generate installers"
foreach ($outputItem in $Variables.Output) {

	# Extract fields into variables
	$name                   = $outputItem.Name
	$productUpgradeCode     = $outputItem.ProductUpgradeCode
	$outputAsSinglePackage  = $outputItem.OutputAsSinglePackage
	$outputCook             = $outputItem.OutputCook
	$outputCookAsPakFile    = $outputItem.OutputCookAsPakFile
	$outputEditor           = $outputItem.OutputEditor
	$outputEditorAsPakFile  = $outputItem.OutputEditorAsPakFile
	$outputCompressed  		= $outputItem.OutputCompressed
	
	$SkrAppBaseFileName = $name + " " + $Version

	Write-Host "Generate package $name"
	$ArchiveSize = 0
	try{
		$globalZip = $null
		if ($outputAsSinglePackage -eq $true)
		{
			$globalZip = Create-Zip -ZipPath (Join-Path $OutputInstallDir ($SkrAppBaseFileName + ".skrmkt"))
		}
		
		if ($outputCook)
		{
			try {
				$zip = $outputAsSinglePackage -eq $true ? $globalZip : (Create-Zip -ZipPath (Join-Path $OutputInstallDir ($SkrAppBaseFileName + ".skrapp")))
				$subPath = $outputAsSinglePackage -eq $true ? "cook" : $null

				$extensionJsonFilePath = [System.IO.FileInfo]::new((Join-Path $OutputCookDir "$name.json"))
				if ($extensionJsonFilePath.Exists) {
					Compress-FileToZip -SourceFolder $OutputCookDir -SourceFile $extensionJsonFilePath -Archive $zip.Archive -OutputCompressed $outputCompressed -InnerArchiveRootPath $subPath
				}
				$ArchiveSize += Compress-FolderToZip -SourceFolder $OutputCookDir -Archive $zip.Archive -OutputCompressed $outputCompressed -SubFoldersToInclude $outputItem.ExtensionsPlugins -InnerArchiveRootPath $subPath
			} finally {
				if ($outputAsSinglePackage -eq $false) {
					Close-Zip -Archive $zip.Archive -ZipStream $zip.ZipStream
				}
			}
			Write-Host "Create cook skrapp file for output $name"
		}
		if ($outputEditor)
		{
			Write-Host "Create editor zip file for output $name"
			& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true -EditorManifest $true
			
			try {
				$zip = $outputAsSinglePackage -eq $true ? $globalZip : (Create-Zip -ZipPath (Join-Path $OutputInstallDir ($SkrAppBaseFileName + "_Editor.zip")))
				$subPath = $outputAsSinglePackage -eq $true ? "editor" : $null
				
				$extensionJsonFilePath = [System.IO.FileInfo]::new((Join-Path $OutputEditorDir "$name.json"))
				if ($extensionJsonFilePath.Exists) {
					Compress-FileToZip -SourceFolder $OutputEditorDir -SourceFile $extensionJsonFilePath -Archive $zip.Archive -OutputCompressed $outputCompressed -InnerArchiveRootPath $subPath
				}
				$ArchiveSize += Compress-FolderToZip -SourceFolder $OutputEditorDir -Archive $zip.Archive -OutputCompressed $outputCompressed -SubFoldersToInclude $outputItem.ExtensionsPlugins -InnerArchiveRootPath $subPath
			} finally {
				if ($outputAsSinglePackage -eq $false) {
					Close-Zip -Archive $zip.Archive -ZipStream $zip.ZipStream
				}
			}
					
			& (Join-Path $PSScriptRoot 'Create-Update-AllManifests.ps1') -ForceUpdate $true -NullVersion
		}
	} finally {
		if ($globalZip) { 
			Close-Zip -Archive $globalZip.Archive -ZipStream $globalZip.ZipStream
		}
	}
	
	
	# Build installer if required
	if ($outputAsSinglePackage -eq $false)
	{
		try{
			# Compute installer size
			$ArchiveSize /= 1000
			Write-Host "Total $name archive size will be " $ArchiveSize
			
			
			# Call NSIS to create installer
			Write-Host "Building installer using NSIS Compiler: $NSISCompilerPath"
			$location = Get-Location
			Set-Location $ExtensionInstallerSourcePath
			
			& "$NSISCompilerPath" /D"PRODUCT_VERSION=$Version" /D"PRODUCT_UPGRADE_CODE=$productUpgradeCode" /D"PRODUCT_NAME=$name" /D"SKYREAL_VERSION=$SkyRealVersion" /D"BUILD_DIR=$OutputInstallDir" /D"COMPANY_NAME=$CompanyName" /D"ARCHIVE_SIZE=$ArchiveSize" main.nsi
			
			If ($? -ne $true) {
				Write-Error "NSIS Failed"
			}
			else {
				Write-Host "NSIS Completed"
			}
		} finally {
			Set-Location $location
		}
	}
	
	
}



# Call aditional scripts
foreach	($AdditionalInstallersScript in $Variables.AdditionalInstallersScripts)
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