; ----------------------------------------------------------------------------
; himon-debug-proof.asm
; RAM-loaded HIMON debug proof, linked at $3000.
; Use this under HIMON to test BRK trap capture, B breakpoints, and N/S step.
; ----------------------------------------------------------------------------

                        MODULE          HIMON_DEBUG_PROOF_APP

                        XDEF            START

                        XREF            SYS_FLUSH_RX
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF

                        CODE
START:
                        JSR             SYS_FLUSH_RX
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             DBGPROOF_PRINT_LINE
                        LDX             #<MSG_USE_N
                        LDY             #>MSG_USE_N
                        JSR             DBGPROOF_PRINT_LINE
                        BRK             $41

DBGPROOF_BEGIN:
                        CLC
DBGPROOF_BCC:
                        BCC             DBGPROOF_BCC_TAKEN
DBGPROOF_BAD_BCC:
                        BRK             $E1

DBGPROOF_BCC_TAKEN:
                        SEC
DBGPROOF_BCS:
                        BCS             DBGPROOF_BCS_TAKEN
DBGPROOF_BAD_BCS:
                        BRK             $E2

DBGPROOF_BCS_TAKEN:
                        CLV
DBGPROOF_BVC:
                        BVC             DBGPROOF_BVC_TAKEN
DBGPROOF_BAD_BVC:
                        BRK             $E3

DBGPROOF_BVC_TAKEN:
                        LDA             #$7F
                        CLC
                        ADC             #$01
DBGPROOF_BVS:
                        BVS             DBGPROOF_BVS_TAKEN
DBGPROOF_BAD_BVS:
                        BRK             $E4

DBGPROOF_BVS_TAKEN:
DBGPROOF_BMI:
                        BMI             DBGPROOF_BMI_TAKEN
DBGPROOF_BAD_BMI:
                        BRK             $E5

DBGPROOF_BMI_TAKEN:
                        LDA             #$00
DBGPROOF_BEQ:
                        BEQ             DBGPROOF_BEQ_TAKEN
DBGPROOF_BAD_BEQ:
                        BRK             $E6

DBGPROOF_BEQ_TAKEN:
DBGPROOF_BPL:
                        BPL             DBGPROOF_BPL_TAKEN
DBGPROOF_BAD_BPL:
                        BRK             $E7

DBGPROOF_BPL_TAKEN:
                        LDA             #$01
DBGPROOF_BNE:
                        BNE             DBGPROOF_BNE_TAKEN
DBGPROOF_BAD_BNE:
                        BRK             $E8

DBGPROOF_BNE_TAKEN:
DBGPROOF_BRA:
                        BRA             DBGPROOF_DONE
DBGPROOF_BAD_BRA:
                        BRK             $E9

DBGPROOF_DONE:
                        LDX             #<MSG_DONE
                        LDY             #>MSG_DONE
                        JSR             DBGPROOF_PRINT_LINE
                        BRK             $42
DBGPROOF_PASS_IDLE:
                        BRA             DBGPROOF_PASS_IDLE

DBGPROOF_PRINT_LINE:
                        JSR             SYS_WRITE_CSTRING
                        JMP             SYS_WRITE_CRLF

                        DATA
MSG_TITLE:              DB              "HIMON DEBUG PROOF $3000",0
MSG_USE_N:              DB              "BRK $41: USE N OR S TO STEP",0
MSG_DONE:               DB              "DEBUG PROOF DONE",0

                        END
