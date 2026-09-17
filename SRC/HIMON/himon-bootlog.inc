; ----------------------------------------------------------------------------
; Reset boot telemetry. BOOT COLD is emitted only after the RAM-clear path
; completes; BOOT WARM means user RAM was preserved.
; One caller and one flag; text lives in the fixed HIMON message page.
; ----------------------------------------------------------------------------

                        CODE
; 2026-05-07T19:14-05:00        WLP2        Bootlog now prints compact cold/warm status.
MON_BOOTLOG_RESET:
                        LDA             BOOT_REASON
                        BNE             MON_BOOTLOG_HAVE_REASON
                        RTS
MON_BOOTLOG_HAVE_REASON:
                        STZ             BOOT_REASON
                        CMP             #BOOT_REASON_WARM
                        BEQ             MON_BOOTLOG_WARM
                        LDX             #<MSG_BOOTLOG_COLD
                        JMP             HIM_WRITE_PAGE_LINE
MON_BOOTLOG_WARM:
                        LDX             #<MSG_BOOTLOG_WARM
                        JMP             HIM_WRITE_PAGE_LINE
