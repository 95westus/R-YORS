; HIMON-owned inline manager adapter; included under HIM_APMAN_BEGIN.
; Render absent/corrupt manager text; AP then sets DA in both status cells and returns C=0.
; This is not a callable routine. Keep the parent label/local-label scope.

                        LDX             #<MSG_APMAN_NF
                        LDY             #>MSG_APMAN_NF
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
