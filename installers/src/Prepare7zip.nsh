
!macro Prepare7zip
    InitPluginsDir
    SetOutPath "$PLUGINSDIR\7z"
    File "..\Common\7z.dll"
    File "..\Common\7z.exe"
!macroend