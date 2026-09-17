; ----------------------------------------------------------------------------
; # ! NAME  -- explicitly call one resident executable FNV and report its RET line.
; # !+ NAME -- make the same call and also report its hash/entry identity.
; Enter with CMDP_PTR at '!'. Ordinary # lookup and bare-name policy are unchanged.
; No AP fallback, parameter assignment, or additional fixed RAM is used.
; Refuse a live stopped context: the common reporter owns the NMI_CTX snapshot.
; A returning target must obey the ordinary HIMON call/stack contract.
; ----------------------------------------------------------------------------
CMD_HASH_CALL:
                        LDA             #CMD_EXEC_KIND_DIAG_QUIET
                        STA             CMD_EXEC_KIND
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
                        CMP             #'+'
                        BNE             CMD_HASH_CALL_DELIM
                        LDA             #CMD_EXEC_KIND_DIAG
                        STA             CMD_EXEC_KIND
                        JSR             CMD_ADV_PTR
                        JSR             CMD_PEEK
CMD_HASH_CALL_DELIM:
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCC             CMD_HASH_CALL_USAGE
                        JSR             CMD_SKIP_SPACES
                        JSR             CMD_PEEK
                        BEQ             CMD_HASH_CALL_USAGE

                        LDA             CMDP_PTR_LO
                        STA             CMDP_START_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_START_HI
                        JSR             FNV1A_INIT
; Hash the whole name, including a leading quote if present. CMD_HASH_TOKEN's
; immediate-quote shorthand is deliberately not part of this exact-name form.
CMD_HASH_CALL_TOKEN:
                        JSR             CMD_PEEK
                        JSR             CMD_IS_DELIM_OR_NUL
                        BCS             CMD_HASH_CALL_TOKEN_DONE
                        AND             #$7F
                        JSR             FNV1A_UPDATE_A_FAST
                        JSR             CMD_ADV_PTR
                        BRA             CMD_HASH_CALL_TOKEN
CMD_HASH_CALL_TOKEN_DONE:
                        JSR             CMD_SAVE_HASH
                        JSR             CMD_REQUIRE_EOL
                        BCC             CMD_HASH_CALL_USAGE
; Confirmation and monitor-compatible callees expect their name at CMDP_PTR.
                        LDA             CMDP_START_LO
                        STA             CMDP_PTR_LO
                        LDA             CMDP_START_HI
                        STA             CMDP_PTR_HI
                        LDA             NMI_CTX_FLAG
                        CMP             #$01
                        BEQ             CMD_HASH_CALL_LIVE
                        JSR             THE_JOIN_EXEC
                        BCC             CMD_HASH_CALL_MISS
                        JSR             CMD_HASH_CONFIRM_EXEC
                        BCC             CMD_HASH_CALL_DONE
                        JSR             CMD_SAVE_ENTRY
                        JSR             CMD_EXEC_ADDR
                        BRA             CMD_HASH_CALL_DONE

CMD_HASH_CALL_USAGE:
                        LDX             #<MSG_HASH_CALL_USAGE
                        LDY             #>MSG_HASH_CALL_USAGE
                        BRA             CMD_HASH_CALL_PRINT
CMD_HASH_CALL_LIVE:
                        LDX             #<MSG_HASH_CALL_LIVE
                        LDY             #>MSG_HASH_CALL_LIVE
                        BRA             CMD_HASH_CALL_PRINT
CMD_HASH_CALL_MISS:
                        LDX             #<MSG_HASH_CALL_MISS
                        LDY             #>MSG_HASH_CALL_MISS
CMD_HASH_CALL_PRINT:
                        JSR             HIM_WRITE_HBLINE
CMD_HASH_CALL_DONE:
; The outer CMD_EXEC_ADDR belongs to '#', not the diagnosed target. Keep it
; quiet and successful even if the target returned C=0 with nonzero A.
                        STZ             CMD_EXEC_KIND
                        SEC
                        RTS

MSG_HASH_CALL_USAGE:     DB              "# ![+] NAM",('E'+$80)
MSG_HASH_CALL_LIVE:      DB              "# ! LIVE CT",('X'+$80)
MSG_HASH_CALL_MISS:      DB              "# ! NF/EXE",('C'+$80)
HIM_HASH_CALL_END:
