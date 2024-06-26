# https://nsis.sourceforge.io/Auto-uninstall_old_before_installing_new
!include LogicLib.nsh


!macro UninstallPreviousVersion
    ${If} ${Silent}
        ReadRegStr $R0 HKLM "$UninstallRegKeyPath" "QuietUninstallString"
    ${Else}
        ReadRegStr $R0 HKLM "$UninstallRegKeyPath" "UninstallString"
    ${EndIf}

    ${If} $R0 != ""
        ${If} ${Cmd} `MessageBox MB_YESNO|MB_ICONQUESTION "Uninstall previous version?" /SD IDYES IDYES`
            ExecWait "$R0 /UPGRADE=yes _?=$INSTDIR" $1

            ${If} $1 <> 0
		        MessageBox MB_OK|MB_ICONSTOP "Failed to uninstall previous version!" /SD IDOK
                SetErrorLevel ${PREVIOUS_VERSION_UNINSTALL_FAIL}
                Abort
	        ${EndIf}
        ${Else}
            MessageBox MB_OK|MB_ICONSTOP "Previous version must be uninstalled first!" /SD IDOK
            SetErrorLevel ${PREVIOUS_VERSION_UNINSTALL_FAIL}
            Abort
        ${EndIf}
    ${EndIf}
!macroend