; HIMON-owned inline manager adapter; included under HIM_APMAN_BEGIN.
; Copy the entire command page to $1A00 before manager overlay loading; falls through.
; This is not a callable routine. Keep the parent label/local-label scope.

                        LDX             #$00
?CMD_COPY:             LDA             CMD_BUF,X
                        STA             $1A00,X
                        INX
                        BNE             ?CMD_COPY
