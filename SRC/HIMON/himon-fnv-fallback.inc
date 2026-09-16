; Called only after the unchanged resident executable-record lookup misses.
; The original command pointer still names its first nonblank byte.
HIM_FNV_FALLBACK:
                        LDA             STR8_CONFIG_FNV_POLICY
                        LDX             #$07
                        JSR             FNV_SCOPE_POLICY
                        BNE             HIM_FNV_FALLBACK_ENABLED
                        JMP             HIM_FNV_RESIDENT_MISS
HIM_FNV_FALLBACK_ENABLED:
                        LDX             #$1F
?CLEAR:                 STZ             FNV_SCOPE_BASE,X
                        DEX
                        BPL             ?CLEAR
                        LDA             #$07
                        STA             FNV_REQUEST_BANKS
                        LDA             #$FF
                        STA             FNV_BANK_WINDOWS
                        LDA             #FNV_FORMAT_AP_EXPORT
                        STA             FNV_FORMAT
                        LDA             CMDP_PTR_LO
                        STA             FNV_NAME_LO
                        LDA             #$1A
                        STA             FNV_NAME_HI
                        LDA             #APMAN_MODE_SCOPE
                        STA             APMAN_MODE
                        JMP             HIM_APMAN_BOOTSTRAP
