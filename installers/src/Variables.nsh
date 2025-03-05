# Uncomment this line to show variables values during install or uninstall
#!define SHOW_VARIABLES "true"
!define /date INSTALL_DATE "%Y%m%d"

!ifndef BUILD_DIR
    !error "BUILD_DIR must be defined from the command line of makensis.exe"
!endif

!ifndef PRODUCT_NAME
    !error "PRODUCT_NAME must be defined from the command line of makensis.exe"
!endif

!ifndef SKYREAL_VERSION
    !error "SKYREAL_VERSION must be defined from the command line of makensis.exe"
!endif

!ifndef PRODUCT_VERSION
    !error "PRODUCT_VERSION must be defined from the command line of makensis.exe"
!endif

!ifndef PRODUCT_UPGRADE_CODE
    !error "PRODUCT_UPGRADE_CODE must be defined from the command line of makensis.exe"
!endif

!ifndef COMPANY_NAME
    !error "COMPANY_NAME must be defined from the command line of makensis.exe"
!endif

!ifndef ARCHIVE_SIZE
    !error "ARCHIVE_SIZE must be defined from the command line of makensis.exe"
!endif

!include "SplitFirstStrPart.nsh"

Var /GLOBAL ProductName
Var /GLOBAL ApplicationName
Var /GLOBAL ProductVersion
Var /GLOBAL ProductUpgradeCode
Var /GLOBAL SkyRealVersion
Var /GLOBAL CompanyName
Var /GLOBAL CompanyHelpLink
Var /GLOBAL InstallDate
Var /GLOBAL InstallLocation
Var /GLOBAL ExtensionJSonDirectoryLocation
Var /GLOBAL ExtensionJSonFileLocation
Var /GLOBAL ProductVersionIdentifier
Var /GLOBAL UninstallRegKeyPath
Var /GLOBAL UninstallLocation
Var /GLOBAL UninstallExecutable
Var /GLOBAL AppPackageName
Var /GLOBAL AppPackageUncompressedSize

!macro InitializeVariables un
    SetRegView 64
	SetShellVarContext all

    StrCpy $AppPackageUncompressedSize "${ARCHIVE_SIZE}"
    StrCpy $AppPackageName "${PRODUCT_NAME} ${PRODUCT_VERSION}.skrapp"
    StrCpy $ProductName "${PRODUCT_NAME}"
    StrCpy $ApplicationName "${PRODUCT_NAME}"
    StrCpy $SkyRealVersion "${SKYREAL_VERSION}"
    StrCpy $ProductVersion "${PRODUCT_VERSION}"
    StrCpy $ProductUpgradeCode "${PRODUCT_UPGRADE_CODE}"
    StrCpy $CompanyName "${COMPANY_NAME}"
    StrCpy $CompanyHelpLink "https://sky-real.com/"
    StrCpy $InstallDate "${INSTALL_DATE}"

	
	StrCpy $ExtensionJSonDirectoryLocation "$COMMONPROGRAMDATA\Skydea\skyrealvr\$SkyRealVersion\extensions"
	StrCpy $ExtensionJSonFileLocation "$ExtensionJSonDirectoryLocation\$ProductUpgradeCode.skrlnk"

    Push "." ;divider char
    Push "$ProductVersion" ;input string
    Call ${un}SplitFirstStrPart
    Pop $R0 ;1st part (MajorVersion)
    Pop $R1 ;rest

    Push "." ;divider char
    Push "$R1" ;input string
    Call ${un}SplitFirstStrPart
    Pop $R1 ;2nd part (MinorVersion)
    Pop $R2 ;rest

    StrCpy $ProductVersionIdentifier "$R0.$R1"

    ${If} $INSTDIR == "" ; /D not used
        StrCpy $InstallLocation "$PROGRAMFILES64\$CompanyName\$ApplicationName"
    ${Else}
        StrCpy $InstallLocation "$INSTDIR"
    ${EndIf}

    StrCpy $UninstallRegKeyPath "Software\Microsoft\Windows\CurrentVersion\Uninstall\$ProductUpgradeCode"
    StrCpy $INSTDIR "$InstallLocation"

!macroend


!macro ShowVariables
    !ifdef SHOW_VARIABLES
        DetailPrint "UserLocalAppData:$UserLocalAppData"
        DetailPrint "EXEDIR:$EXEDIR"
        DetailPrint "EXEPATH:$EXEPATH"
        DetailPrint "AppPackageName:$AppPackageName"
        DetailPrint "ProductName:$ProductName"
        DetailPrint "SkyRealVersion:$SkyRealVersion"
        DetailPrint "ProductVersion:$ProductVersion"
        DetailPrint "ProductUpgradeCode:$ProductUpgradeCode"
        DetailPrint "CompanyName:$CompanyName"
        DetailPrint "CompanyHelpLink:$CompanyHelpLink"
        DetailPrint "InstallDate:$InstallDate"
        DetailPrint "ProductVersionIdentifier:$ProductVersionIdentifier"
        DetailPrint "InstallLocation:$InstallLocation"
        DetailPrint "UninstallRegKeyPath:$UninstallRegKeyPath"
    !endif
!macroend