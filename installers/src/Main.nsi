!include "x64.nsh"
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "ErrorCodes.nsh"
!include "Variables.nsh"
!include "Prepare7zip.nsh"
!include "AllowSingleInstance.nsh"
!include "UninstallPreviousVersion.nsh"
!include "ReadRegStrAndTrim.nsh"

Unicode true
Name "${PRODUCT_NAME}"
Icon "Assets/favicon.ico"
UninstallIcon "Assets/favicon.ico"
OutFile "${BUILD_DIR}/${PRODUCT_NAME} Setup ${PRODUCT_VERSION}.exe"
BrandingText "${PRODUCT_NAME} Setup ${PRODUCT_VERSION}"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "Assets/favicon.ico"
!define MUI_UNICON "Assets/favicon.ico"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

# !define MUI_FINISHPAGE_NOAUTOCLOSE
# !define MUI_FINISHPAGE_RUN
# !define MUI_FINISHPAGE_RUN_CHECKED
# !define MUI_FINISHPAGE_RUN_TEXT "Start ${PRODUCT_NAME}"
# !define MUI_FINISHPAGE_RUN_FUNCTION "StartApp"
# !insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"


function .onInit
    !insertmacro InitializeVariables ""
    !insertmacro ShowVariables
    !insertmacro AllowSingleInstance
    !insertmacro UninstallPreviousVersion

    ${IfNot} ${FileExists} "$EXEDIR\$AppPackageName"
        MessageBox MB_OK|MB_ICONSTOP "Application package not found" /SD IDOK
        SetErrorLevel ${APPLICATION_PACKAGE_NOT_FOUND}
        Abort
    ${EndIf}

    SectionSetSize 0 "$AppPackageUncompressedSize"
functionEnd

VIProductVersion "${SKYREAL_VERSION}.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=1033 "FileDescription" "${PRODUCT_NAME} Installer"
VIAddVersionKey /LANG=1033 "CompanyName" "SkrTech"
VIAddVersionKey /LANG=1033 "LegalCopyright" "© SkrTech"
VIAddVersionKey /LANG=1033 "ProductVersion" "${SKYREAL_VERSION}.0.0"
VIAddVersionKey /LANG=1033 "FileVersion" "${SKYREAL_VERSION}.0.0"
VIAddVersionKey /LANG=1033 "OriginalFilename" "${PRODUCT_NAME}.exe"
VIAddVersionKey /LANG=1033 "InternalName" "${PRODUCT_NAME}"
	
Section "install"
	ClearErrors
    !insertmacro ShowVariables
    !insertmacro Prepare7zip

    SetOutPath "$INSTDIR"

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
	
    DetailPrint $ExtensionJSonFileLocation

    WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd


function un.onInit
	SetShellVarContext all
    SetRegView 64
    !insertmacro InitializeVariables "un."
    !insertmacro ShowVariables
    !insertmacro AllowSingleInstance

    !insertmacro ReadRegStrAndTrim $UninstallExecutable "$UninstallRegKeyPath" "UninstallString"

    ${IfNot} ${Silent}
        ${IfNot} ${Cmd} `MessageBox MB_OKCANCEL|MB_ICONQUESTION "Do you really want to uninstall $ApplicationName $ProductVersionIdentifier?" /SD IDOK IDOK`
            SetErrorLevel ${PREVIOUS_VERSION_UNINSTALL_CANCEL}
            Abort
        ${EndIf}
    ${EndIf}

    ${IfNot} ${FileExists} $UninstallExecutable
        ${IfNot} ${Silent}
            MessageBox MB_OK "$UninstallExecutable file doesn't exist, uninstall aborted." IDOK
        ${EndIf}

        SetErrorLevel ${UNSAFE_UNINSTALL_LOCATION}
        Abort ; We are not in the right uninstall location it is unsafe to delete files
    ${EndIf}
functionEnd

Section "Uninstall"
    !insertmacro ShowVariables
    SetRegView 64

    !insertmacro ReadRegStrAndTrim $UninstallLocation "$UninstallRegKeyPath" "InstallLocation"
    !insertmacro ReadRegStrAndTrim $UninstallExecutable "$UninstallRegKeyPath" "UninstallString"

    Delete $ExtensionJSonFileLocation
	
    Delete $UninstallExecutable

    RMDir /r $UninstallLocation

    DeleteRegKey HKLM "$UninstallRegKeyPath"
SectionEnd