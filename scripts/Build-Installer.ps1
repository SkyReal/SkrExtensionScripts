$Variables = & (Join-Path $PSScriptRoot Get-Variables.ps1)
$Version = $Variables.Version
$SkyRealVersion = $Variables.SkyRealVersion
$ProductUpgradeCode = $Variables.ProductUpgradeCode
$InstallerName = $Variables.InstallerName
$OutputBuildDir = $Variables.OutputBuildDir
$OutputInstallDir = $Variables.OutputInstallDir

$RepositoryPath = Resolve-Path (Join-Path $PSScriptRoot "..")
$ExtensionInstallerSourcePath = (Join-Path (Join-Path $RepositoryPath "installers") "src")
$SkrAppBaseFileName = $InstallerName + " " + $Version
$SkrAppZipFilePath = (Join-Path $OutputInstallDir ($SkrAppBaseFileName + ".zip"))
$SkrAppFilePath = (Join-Path $OutputInstallDir ($SkrAppBaseFileName + ".skrapp"))

Write-Host "Clean and recreate output directory $OutputInstallDir"
If (Test-Path -Path $OutputInstallDir)
{
	Remove-Item -path $OutputInstallDir -Force -Recurse
}
New-Item -Path $OutputInstallDir -ItemType Directory -ErrorAction SilentlyContinue

Write-Host "Create skrapp file"
Compress-Archive -Path (Join-Path $OutputBuildDir "*") -DestinationPath $SkrAppZipFilePath -Force
Move-Item -Path $SkrAppZipFilePath -Destination $SkrAppFilePath

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




Write-Host "Building installer using NSIS Compiler: $NSISCompilerPath"
$location = Get-Location
Set-Location $ExtensionInstallerSourcePath

& "$NSISCompilerPath" /D"PRODUCT_VERSION=$Version" /D"PRODUCT_UPGRADE_CODE=$ProductUpgradeCode" /D"PRODUCT_NAME=$InstallerName" /D"SKYREAL_VERSION=$SkyRealVersion" /D"BUILD_DIR=$OutputInstallDir" main.nsi


If ($? -ne $true) {
    Write-Error "NSIS Failed"
}
else {
    Write-Host "NSIS Completed"
}

Set-Location $location