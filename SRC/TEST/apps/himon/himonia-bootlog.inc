; ----------------------------------------------------------------------------
; Cold-reset boot telemetry.
; Keep this include removable: one caller, one flag, local strings only.
; ----------------------------------------------------------------------------

                        CODE
MON_BOOTLOG_COLD:
                        LDA             BOOT_COLD_FLAG
                        BNE             MON_BOOTLOG_HAVE_COLD
                        RTS
MON_BOOTLOG_HAVE_COLD:
                        STZ             BOOT_COLD_FLAG

                        LDX             #<MSG_BOOTLOG_BOOT
                        LDY             #>MSG_BOOTLOG_BOOT
                        JSR             MON_BOOTLOG_LINE_XY
                        LDX             #<MSG_BOOTLOG_WAIT
                        LDY             #>MSG_BOOTLOG_WAIT
                        JSR             MON_BOOTLOG_LINE_XY
                        LDX             #<MSG_BOOTLOG_RAM
                        LDY             #>MSG_BOOTLOG_RAM
                        JSR             MON_BOOTLOG_LINE_XY
                        LDX             #<MSG_BOOTLOG_FTDI
                        LDY             #>MSG_BOOTLOG_FTDI
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

                        DATA
MSG_BOOTLOG_BOOT:       DB              "BOOT COL",('D'+$80)
MSG_BOOTLOG_WAIT:       DB              "WAIT O",('K'+$80)
MSG_BOOTLOG_RAM:        DB              "RAM ZERO O",('K'+$80)
MSG_BOOTLOG_FTDI:       DB              "FTDI INI",('T'+$80)
MSG_BOOTLOG_RST:        DB              "RST 7EF8",('='+$80)
MSG_BOOTLOG_NMI:        DB              "NMI 7EFA",('='+$80)
MSG_BOOTLOG_IRQ:        DB              "IRQ 7EFE",('='+$80)
MSG_BOOTLOG_BRK:        DB              "BRK 7EFC",('='+$80)
