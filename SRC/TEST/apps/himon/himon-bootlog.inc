; ----------------------------------------------------------------------------
; Reset boot telemetry.
; Keep this include removable: one caller, one flag, local strings only.
; ----------------------------------------------------------------------------

                        CODE
; 260507-1914        WLP2        Bootlog now prints compact cold/warm status.
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
                        RTS
MON_BOOTLOG_WARM:
                        LDX             #<MSG_BOOTLOG_WARM
                        LDY             #>MSG_BOOTLOG_WARM
                        JMP             MON_BOOTLOG_LINE_XY

MON_BOOTLOG_LINE_XY:
                        JSR             HIM_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

                        DATA
MSG_BOOTLOG_COLD:       DB              "BOOT COL",('D'+$80)
MSG_BOOTLOG_WARM:       DB              "BOOT WAR",('M'+$80)
MSG_BOOTLOG_RAM:        DB              "RAM ZERO O",('K'+$80)
