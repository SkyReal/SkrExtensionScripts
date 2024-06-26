!macro ReadRegStrAndTrim return_var sub_key name
    ReadRegStr ${return_var} HKLM ${sub_key} ${name}
    ;the registry return the double quotes in the string so I "trim" it
    StrCpy ${return_var} ${return_var} -1 1
!macroend