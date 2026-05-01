; ----------------------------------------------------------------------------
; Reset boot telemetry.
; Keep this include removable: one caller, one flag, local strings only.
; ----------------------------------------------------------------------------

                        IF              ROM_ABI
HIMON_BOOTLOG           SECTION         OFFSET $F3D1
                        ELSE
                        CODE
                        ENDIF
MON_BOOTLOG_RESET:
                        LDA             BOOT_REASON
                        BNE             MON_BOOTLOG_HAVE_REASON
                        RTS
MON_BOOTLOG_HAVE_REASON:
                        STZ             BOOT_REASON

                        CMP             #BOOT_REASON_WARM
                        BEQ             MON_BOOTLOG_WARM
                        LDX             #<MSG_BOOTLOG_COLD
                        LDY             #>MSG_BOOTLOG_COLD
                        JSR             MON_BOOTLOG_LINE_XY
                        LDX             #<MSG_BOOTLOG_RAM
                        LDY             #>MSG_BOOTLOG_RAM
                        JSR             MON_BOOTLOG_LINE_XY
                        BRA             MON_BOOTLOG_AFTER_REASON
MON_BOOTLOG_WARM:
                        LDX             #<MSG_BOOTLOG_WARM
                        LDY             #>MSG_BOOTLOG_WARM
                        JSR             MON_BOOTLOG_LINE_XY
MON_BOOTLOG_AFTER_REASON:
                        LDX             #<MSG_BOOTLOG_FTDI
                        LDY             #>MSG_BOOTLOG_FTDI
                        JSR             MON_BOOTLOG_LINE_XY
                        LDX             #<MSG_BOOTLOG_WAIT
                        LDY             #>MSG_BOOTLOG_WAIT
                        JSR             HIM_WRITE_HBSTRING
                        JSR             MON_BOOTLOG_WAIT_DOTS
                        LDX             #<MSG_BOOTLOG_OK
                        LDY             #>MSG_BOOTLOG_OK
                        JSR             MON_BOOTLOG_LINE_XY

                        LDX             #<MSG_BOOTLOG_RST
                        LDY             #>MSG_BOOTLOG_RST
                        JSR             HIM_WRITE_HBSTRING
                        LDA             #>SYS_VEC_DEFAULT_RESET
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #<SYS_VEC_DEFAULT_RESET
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_BOOTLOG_NMI
                        LDY             #>MSG_BOOTLOG_NMI
                        JSR             HIM_WRITE_HBSTRING
                        LDA             #>MON_NMI_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #<MON_NMI_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_BOOTLOG_IRQ
                        LDY             #>MSG_BOOTLOG_IRQ
                        JSR             HIM_WRITE_HBSTRING
                        LDA             #>MON_IRQ_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #<MON_IRQ_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF

                        LDX             #<MSG_BOOTLOG_BRK
                        LDY             #>MSG_BOOTLOG_BRK
                        JSR             HIM_WRITE_HBSTRING
                        LDA             #>MON_BRK_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #<MON_BRK_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
MON_BOOTLOG_DONE:
                        RTS

MON_BOOTLOG_LINE_XY:
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

MON_BOOTLOG_WAIT_DOTS:
                        LDX             #$0D
?DOT:
                        PHX
                        LDA             #$6F
                        LDX             #$7B
                        LDY             #$39
                        JSR             UTL_DELAY_AXY_8MHZ
                        LDA             #'.'
                        JSR             BIO_FTDI_WRITE_BYTE_BLOCK
                        PLX
                        DEX
                        BNE             ?DOT
                        RTS

                        IF              ROM_ABI
                        ELSE
                        DATA
                        ENDIF
MSG_BOOTLOG_COLD:       DB              "BOOT COL",('D'+$80)
MSG_BOOTLOG_WARM:       DB              "BOOT WAR",('M'+$80)
MSG_BOOTLOG_WAIT:       DB              "WAIT",(' '+$80)
MSG_BOOTLOG_OK:         DB              " O",('K'+$80)
MSG_BOOTLOG_RAM:        DB              "RAM ZERO O",('K'+$80)
MSG_BOOTLOG_FTDI:       DB              "FTDI INI",('T'+$80)
MSG_BOOTLOG_RST:        DB              "RST 7EF8",('='+$80)
MSG_BOOTLOG_NMI:        DB              "NMI 7EFA",('='+$80)
MSG_BOOTLOG_IRQ:        DB              "IRQ 7EFE",('='+$80)
MSG_BOOTLOG_BRK:        DB              "BRK 7EFC",('='+$80)
                        IF              ROM_ABI
                        ENDS
                        ENDIF
