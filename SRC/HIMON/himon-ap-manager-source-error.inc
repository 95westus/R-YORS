; HIMON-owned inline manager adapter; included under HIM_APMAN_SOURCE_BAD.
; Render the already-set manager source error; AP reloads status and returns C=0.
; This is not a callable routine. Keep the parent label/local-label scope.

                        LDX             #<MSG_AP_ERR
                        JSR             HIM_WRITE_PAGE_TEXT
                        LDA             APMAN_STATUS
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
