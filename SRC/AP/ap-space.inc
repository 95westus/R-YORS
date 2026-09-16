HIM_AP_FIND_HOLE:
                        STZ             CMDP_PTR_LO
                        LDA             #$80
                        STA             CMDP_PTR_HI
HIM_AP_FIND_HOLE_LOOP:
                        JSR             HIM_AP_HOLE_AT_SCAN
                        BCS             HIM_AP_FIND_HOLE_FOUND
                        INC             CMDP_PTR_LO
                        BNE             HIM_AP_FIND_HOLE_NEXT
                        INC             CMDP_PTR_HI
HIM_AP_FIND_HOLE_NEXT:
                        LDA             CMDP_PTR_HI
                        CMP             #$FF
                        BCC             HIM_AP_FIND_HOLE_LOOP
                        JMP             HIM_AP_BAD_RANGE
HIM_AP_FIND_HOLE_FOUND:
                        LDA             CMDP_PTR_LO
                        STA             HIM_AP_INSTALL_LO
                        LDA             CMDP_PTR_HI
                        STA             HIM_AP_INSTALL_HI
                        SEC
                        RTS

HIM_AP_HOLE_AT_SCAN:
                        LDA             HIM_AP_PKG_LEN_LO
                        SEC
                        SBC             #$01
                        STA             HIM_AP_TMP_LO
                        LDA             HIM_AP_PKG_LEN_HI
                        SBC             #$00
                        STA             HIM_AP_TMP_HI
                        LDA             CMDP_PTR_LO
                        CLC
                        ADC             HIM_AP_TMP_LO
                        STA             HIM_AP_TMP2_LO
                        LDA             CMDP_PTR_HI
                        ADC             HIM_AP_TMP_HI
                        BCS             HIM_AP_HOLE_NO
                        CMP             #$FF
                        BCS             HIM_AP_HOLE_NO
                        LDA             CMDP_PTR_LO
                        STA             CMDP_ADDR_LO
                        LDA             CMDP_PTR_HI
                        STA             CMDP_ADDR_HI
                        LDA             HIM_AP_PKG_LEN_LO
                        STA             LOAD_LEN_LO
                        LDA             HIM_AP_PKG_LEN_HI
                        STA             LOAD_LEN_HI
HIM_AP_HOLE_CHECK_LOOP:
                        LDA             LOAD_LEN_LO
                        ORA             LOAD_LEN_HI
                        BEQ             HIM_AP_HOLE_YES
                        LDY             #$00
                        LDA             (CMDP_ADDR_LO),Y
                        CMP             #$FF
                        BNE             HIM_AP_HOLE_NO
                        INC             CMDP_ADDR_LO
                        BNE             HIM_AP_HOLE_COUNT
                        INC             CMDP_ADDR_HI
HIM_AP_HOLE_COUNT:
                        DEC             LOAD_LEN_LO
                        LDA             LOAD_LEN_LO
                        CMP             #$FF
                        BNE             HIM_AP_HOLE_CHECK_LOOP
                        DEC             LOAD_LEN_HI
                        BRA             HIM_AP_HOLE_CHECK_LOOP
HIM_AP_HOLE_YES:
                        SEC
                        RTS
HIM_AP_HOLE_NO:
                        CLC
                        RTS

HIM_AP_BAD_FIX:
                        LDA             #HIM_AP_STATUS_BAD_FIX
                        BRA             HIM_AP_FAIL_A
HIM_AP_BAD_RANGE:
                        LDA             #HIM_AP_STATUS_BAD_RANGE
                        BRA             HIM_AP_FAIL_A
HIM_AP_BAD_LINE:
                        LDA             #HIM_AP_STATUS_BAD_LINE
HIM_AP_FAIL_A:
                        STA             HIM_AP_STATUS
                        CLC
                        RTS
