!include "x64.nsh"
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "ErrorCodes.nsh"
!include "Variables.nsh"
!include "Prepare7zip.nsh"
!include "AllowSingleInstance.nsh"
!include "UninstallPreviousVersion.nsh"
!include "ReadRegStrAndTrim.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "StrFunc.nsh"

Unicode true
Name "${PRODUCT_NAME}"
Icon "Assets/favicon.ico"
UninstallIcon "Assets/favicon.ico"
OutFile "${BUILD_DIR}/${PRODUCT_NAME} - Setup ${PRODUCT_VERSION}.exe"
BrandingText "${PRODUCT_NAME} - Setup ${PRODUCT_VERSION}"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "Assets/favicon.ico"
!define MUI_UNICON "Assets/favicon.ico"

Page custom InstallOptionPage InstallOptionPageLeave

Page directory SkipInstallDirPage

!insertmacro MUI_PAGE_INSTFILES

# !define MUI_FINISHPAGE_NOAUTOCLOSE
# !define MUI_FINISHPAGE_RUN
# !define MUI_FINISHPAGE_RUN_CHECKED
# !define MUI_FINISHPAGE_RUN_TEXT "Start ${PRODUCT_NAME}"
# !define MUI_FINISHPAGE_RUN_FUNCTION "StartApp"
# !insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Var InstallToMarketplaceFlag
Var MarketplaceCheckboxHandle
Var IsUninstall

function .onInit
    !insertmacro InitializeVariables ""
    !insertmacro ShowVariables
    !insertmacro AllowSingleInstance
    !insertmacro UninstallPreviousVersion
	
	StrCpy $InstallToMarketplaceFlag 1
	StrCpy $IsUninstall 0

    ${IfNot} ${FileExists} "$EXEDIR\$AppPackageName"
        MessageBox MB_OK|MB_ICONSTOP "Application package not found" /SD IDOK
        SetErrorLevel ${APPLICATION_PACKAGE_NOT_FOUND}
        Abort
    ${EndIf}

    SectionSetSize 0 "$AppPackageUncompressedSize"
FunctionEnd

${Using:StrFunc} StrStr
Var XRCenterLocation
Var ExitCode
Var Output
Var ScanDirectoryPathStart
Var ScanDirectoryPathEnd
Var LenToScanDirectoryPathStart
Var LenToScanDirectoryPathEnd

Function SearchMarketplace
  	ReadRegStr $XRCenterLocation HKLM "$XRCenterServiceRegKeyPath" "$XRCenterServiceRegKeyKey"
	
    ${IfNot} ${FileExists} $XRCenterLocation
	    DetailPrint "Failed to find XRCenter location"
        Return
    ${EndIf}
  
    nsExec::ExecToStack '"$XRCenterLocation" $XRCenterScanPathArgument'
	Pop $ExitCode
	${IfNot} $ExitCode == 0
		DetailPrint "Failed to find XRCenter location"
        Return
	${EndIf}

    Pop $Output
    ${StrStr} $ScanDirectoryPathStart $Output $MarketplaceScanDirectoryPathSearchedValue
    ${If} $ScanDirectoryPathStart == -1
		DetailPrint "Failed to find ScanDirectoryPath"
        Return
  	${EndIf}
  	
  	${StrStr} $ScanDirectoryPathEnd $ScanDirectoryPathStart "]"
  	${If} $ScanDirectoryPathEnd == -1
  		DetailPrint "Failed to find ScanDirectoryPath"
		Return
  	${EndIf}
  
  	StrLen $LenToScanDirectoryPathStart $MarketplaceScanDirectoryPathSearchedValue
  	StrLen $LenToScanDirectoryPathEnd $ScanDirectoryPathEnd
  	StrCpy $MarketplaceScanDirectoryPathValue $ScanDirectoryPathStart -$LenToScanDirectoryPathEnd $LenToScanDirectoryPathStart

	${IfNot} ${FileExists} $MarketplaceScanDirectoryPathValue
		DetailPrint "ScanDirectoryPath is not valid"
		StrCpy $MarketplaceScanDirectoryPathValue ""
	${EndIf}
FunctionEnd

Function InstallOptionPage
    ${If} $IsUninstall = 1
  	Return        ; don’t show the checkbox during uninstall
    ${EndIf}
	
    Call SearchMarketplace
    ${If} $MarketplaceScanDirectoryPathValue == ""
  	StrCpy $InstallToMarketplaceFlag 0
      Return       ; don’t show the checkbox if Marketplace path not found
    ${EndIf}
  	
    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
      Abort
    ${EndIf}
  
    ${NSD_CreateCheckbox} 0u 10u 100% 12u "Install To Marketplace?"
    Pop $MarketplaceCheckboxHandle
    ${NSD_Check} $MarketplaceCheckboxHandle  ; default = checked
  
    nsDialogs::Show
FunctionEnd

Function InstallOptionPageLeave
    ${NSD_GetState} $MarketplaceCheckboxHandle $InstallToMarketplaceFlag
    DetailPrint ">>> Checkbox state is now: $InstallToMarketplaceFlag"
FunctionEnd

;── 2) Directory page, with a PRE-hook to skip if flag=1 ──────────────────────────
Function SkipInstallDirPage
    DetailPrint ">>> SkipInstallDirPage sees flag = $InstallToMarketplaceFlag"
    ${If} $InstallToMarketplaceFlag = 1
        Abort    ; aborting this function skips the directory page
    ${EndIf}
FunctionEnd

VIProductVersion "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=1033 "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=1033 "FileDescription" "${PRODUCT_NAME} Installer"
VIAddVersionKey /LANG=1033 "CompanyName" "${COMPANY_NAME}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright ${COMPANY_NAME}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=1033 "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=1033 "OriginalFilename" "${PRODUCT_NAME}.exe"
VIAddVersionKey /LANG=1033 "InternalName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=1033 "Comments" "${PRODUCT_UPGRADE_CODE}"

Section "install"
    ClearErrors
    !insertmacro ShowVariables
	
	${If} ${Silent}
		Call SearchMarketplace
	${EndIf}
	
	${If} $InstallToMarketplaceFlag == 1
	${AndIfNot} $MarketplaceScanDirectoryPathValue == ""
		; 2) Are we already running from *inside* that directory?
		StrLen $R0 $MarketplaceScanDirectoryPathValue          ; get length of marketplace path
		StrCpy $R1 $EXEDIR $R0                   ; grab that many chars from $EXEDIR
		${If} $R1 == $MarketplaceScanDirectoryPathValue
			DetailPrint "Installer already in marketplace dir, skipping copy"
		${Else}
			DetailPrint "Installing extension to marketplace"
			
			Delete "$MarketplaceScanDirectoryPathValue\$MarketplaceScanningFile"
			
			CopyFiles /SILENT "$EXEDIR\$AppPackageName" "$MarketplaceScanDirectoryPathValue\"
			
			${If} ${FileExists} "$EXEDIR\$EditorPackageName"
				CopyFiles /SILENT "$EXEDIR\$EditorPackageName" "$MarketplaceScanDirectoryPathValue\"
			${EndIf}
			
			${If} ${Errors}
				MessageBox MB_OK|MB_ICONEXCLAMATION "Failed to install to marketplace $MarketplaceScanDirectoryPathValue"
				Abort
			${EndIf}
		${EndIf}
		
		FileOpen $0 "$MarketplaceScanDirectoryPathValue\$MarketplaceScanningFile" w
		${If} ${Errors}
			MessageBox MB_OK|MB_ICONEXCLAMATION "Can't write MarketplaceScanningFile"
			Abort
		${EndIf}
		FileWrite $0 "."
		FileClose $0
		
		Return
	${EndIf}
	
	!insertmacro Prepare7zip

    SetOutPath "$INSTDIR"

	ClearErrors
    DetailPrint "Installing extension package"
	nsExec::ExecToLog '"$PLUGINSDIR\7z\7z.exe" x -bb1 -o"$INSTDIR" "$EXEDIR\$AppPackageName"'
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONEXCLAMATION "Failed to extract skrapp to $INSTDIR"
        Abort
	${EndIf}

    WriteRegStr HKLM "$UninstallRegKeyPath" "DisplayName" "$ApplicationName $ProductVersionIdentifier"
    WriteRegStr HKLM "$UninstallRegKeyPath" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\"" # Do not quote INSTDIR
    WriteRegStr HKLM "$UninstallRegKeyPath" "QuietUninstallString" "$\"$INSTDIR\Uninstall.exe$\" /S" # Do not quote INSTDIR
    WriteRegStr HKLM "$UninstallRegKeyPath" "DisplayIcon" "$\"$INSTDIR\Uninstall.exe$\""
    WriteRegStr HKLM "$UninstallRegKeyPath" "InstallLocation" "$\"$INSTDIR$\""
    WriteRegStr HKLM "$UninstallRegKeyPath" "InstallDate" "$InstallDate"
    WriteRegStr HKLM "$UninstallRegKeyPath" "Publisher" "$CompanyName"
    WriteRegStr HKLM "$UninstallRegKeyPath" "HelpLink" "$CompanyHelpLink"
    WriteRegStr HKLM "$UninstallRegKeyPath" "DisplayVersion" "$ProductVersion"
    WriteRegDWORD HKLM "$UninstallRegKeyPath" "NoModify" "1"
    WriteRegDWORD HKLM "$UninstallRegKeyPath" "NoRepair" "1"

	# Add uninstall size to registery
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "$UninstallRegKeyPath" "EstimatedSize" "$0"
	
	# Create a new file
	ClearErrors
	CreateDirectory "$ExtensionJSonDirectoryLocation"
	FileOpen $0 "$ExtensionJSonFileLocation" w
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONEXCLAMATION "Can't write manifest in $ExtensionJSonFileLocation"
        Abort
	${EndIf}
	FileWrite $0 "$INSTDIR\SkrExtensions.json"
	FileClose $0 ;Closes the filled file

    WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

function un.onInit
	SetShellVarContext all
    SetRegView 64
	
	StrCpy $IsUninstall 0
	
    !insertmacro InitializeVariables "un."
    !insertmacro ShowVariables
    !insertmacro AllowSingleInstance

    !insertmacro ReadRegStrAndTrim $UninstallLocation "$UninstallRegKeyPath" "InstallLocation"
    !insertmacro ReadRegStrAndTrim $UninstallExecutable "$UninstallRegKeyPath" "UninstallString"

    ${IfNot} ${Silent}
        ${IfNot} ${Cmd} `MessageBox MB_OKCANCEL|MB_ICONQUESTION "Do you really want to uninstall $ApplicationName $ProductVersionIdentifier?" /SD IDOK IDOK`
            SetErrorLevel ${PREVIOUS_VERSION_UNINSTALL_CANCEL}
            Abort
        ${EndIf}
    ${EndIf}

    ${IfNot} ${FileExists} $UninstallExecutable
        ${IfNot} ${Silent}
            MessageBox MB_OK "$UninstallExecutable file doesn't exist, uninstall aborted. (PUC: $ProductUpgradeCode)" IDOK
        ${EndIf}

        SetErrorLevel ${UNSAFE_UNINSTALL_LOCATION}
        Abort ; We are not in the right uninstall location it is unsafe to delete files
    ${EndIf}
functionEnd

Section "Uninstall"
    !insertmacro ShowVariables
    SetRegView 64

    Delete $ExtensionJSonFileLocation
    RMDir /r $UninstallLocation
    DeleteRegKey HKLM "$UninstallRegKeyPath"
	Delete "$UninstallExecutable"
SectionEnd
