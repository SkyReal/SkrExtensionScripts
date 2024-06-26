#https://nsis.sourceforge.io/Allow_only_one_installer_instance

!ifndef NSIS_PTR_SIZE & SYSTYPE_PTR
    !define SYSTYPE_PTR i ; NSIS v2.x
!else
    !define /ifndef SYSTYPE_PTR p ; NSIS v3.0+
!endif

!macro AllowSingleInstance
    System::Call 'KERNEL32::CreateMutex(${SYSTYPE_PTR}0, i1, t"$ProductUpgradeCode")?e'
    Pop $0
    IntCmpU $0 183 "" launch launch ;
        ${GetParameters} $1
        ClearErrors
        ${GetOptions} $1 "/UPGRADE=" $2

        ${IfNot} ${Errors}
            Goto launch
        ${EndIf}

        MessageBox MB_OK|MB_ICONSTOP "Only a single instance of this installer is allowed. Verify other users as well." /SD IDOK
        SetErrorLevel ${INSTANCE_ALREADY_RUNNING}
        Abort
    launch:
!macroend