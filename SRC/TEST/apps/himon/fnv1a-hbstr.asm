; ----------------------------------------------------------------------------
; fnv1a-hbstr.asm
; Standalone W65C02S serial FNV-1a hash tool.
;
; UI:
;   - Reads one echoed input line into a HIBIT-terminated linear buffer.
;   - Hashes the HIBIT string bytes with FNV-1a 32-bit.
;   - Prints the hash as 8 hex digits and repeats.
;   - Ctrl-C exits the loop.
;
; Output strings use the local HIBIT convention:
;   - The first byte with bit 7 set is the final character.
;   - SYS_WRITE_HBSTRING masks bit 7 before output.
;
; Hash result:
;   - FNV_HASH0..FNV_HASH3 hold the 32-bit hash, little-endian.
; ----------------------------------------------------------------------------

                        CHIP            65C02
                        PW              132
                        MODULE          FNV1A_HBSTR_APP

                        XDEF            START
                        XDEF            APP_PRINT_HASH
                        XDEF            FNV1A_HBSTR_XY
                        XDEF            FNV1A_INIT
                        XDEF            FNV1A_UPDATE_A
                        XDEF            FNV1A_MUL_PRIME
                        XDEF            MATH_COPY_HASH_TO_TERM
                        XDEF            MATH_SHLADD_TERM_N
                        XDEF            MATH_SHL_TERM_N
                        XDEF            MATH_ADD_TERM_TO_HASH
                        XDEF            MATH_ADD_TERM1_TO_HASH3

                        XREF            COR_FTDI_INIT
                        XREF            SYS_FLUSH_RX
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HBSTRING
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            SYS_READ_HBSTRING_CTRL_C_ECHO

FNV_PTR_LO              EQU             $E0
FNV_PTR_HI              EQU             $E1
FNV_HASH0               EQU             $79E2
FNV_HASH1               EQU             $79E3
FNV_HASH2               EQU             $79E4
FNV_HASH3               EQU             $79E5
FNV_TERM0               EQU             $79E6
FNV_TERM1               EQU             $79E7
FNV_TERM2               EQU             $79E8
FNV_TERM3               EQU             $79E9
FNV_INPUT_LEN           EQU             $79EA

FNV_INPUT_BUF           EQU             $7A00

                        CODE

START:
                        SEI
                        CLD
                        LDX             #$FF
                        TXS
                        JSR             COR_FTDI_INIT
                        JSR             SYS_FLUSH_RX

                        LDX             #<MSG_BANNER
                        LDY             #>MSG_BANNER
                        JSR             SYS_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF

MAIN_LOOP:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             SYS_WRITE_HBSTRING

                        LDX             #<FNV_INPUT_BUF
                        LDY             #>FNV_INPUT_BUF
                        JSR             SYS_READ_HBSTRING_CTRL_C_ECHO
                        BCS             MAIN_HAVE_LINE
                        CMP             #$03
                        BEQ             MAIN_EXIT
                        LDX             #<MSG_FULL
                        LDY             #>MSG_FULL
                        JSR             SYS_WRITE_HBSTRING
                        JSR             SYS_WRITE_CRLF
                        BRA             MAIN_LOOP

MAIN_HAVE_LINE:
                        STA             FNV_INPUT_LEN
                        JSR             FNV1A_TRIM_TRAILING_CRLF
                        LDX             #<FNV_INPUT_BUF
                        LDY             #>FNV_INPUT_BUF
                        JSR             FNV1A_BUF_XY_LEN
                        JSR             APP_PRINT_HASH
                        BRA             MAIN_LOOP

MAIN_EXIT:
                        BRK             $00
                        JMP             MAIN_LOOP

; ----------------------------------------------------------------------------
; ROUTINE: APP_PRINT_HASH
; OUT: emits FNV_HASH as high-to-low 8 hex digits
; ----------------------------------------------------------------------------
APP_PRINT_HASH:
                        LDX             #<MSG_HASH
                        LDY             #>MSG_HASH
                        JSR             SYS_WRITE_HBSTRING
                        LDA             FNV_HASH3
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             FNV_HASH2
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             FNV_HASH1
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             FNV_HASH0
                        JSR             SYS_WRITE_HEX_BYTE
                        JMP             SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_TRIM_TRAILING_CRLF
; IN : FNV_INPUT_LEN = count returned by read routine
; OUT: FNV_INPUT_LEN trimmed of trailing CR/LF bytes (defensive)
; ----------------------------------------------------------------------------
FNV1A_TRIM_TRAILING_CRLF:
                        LDA             FNV_INPUT_LEN
                        BEQ             FNV1A_TRIM_DONE
                        SEC
                        SBC             #$01
                        TAY
                        LDA             FNV_INPUT_BUF,Y
                        AND             #$7F
                        CMP             #$0D
                        BEQ             FNV1A_TRIM_DROP
                        CMP             #$0A
                        BNE             FNV1A_TRIM_DONE
FNV1A_TRIM_DROP:
                        DEC             FNV_INPUT_LEN
                        BRA             FNV1A_TRIM_TRAILING_CRLF
FNV1A_TRIM_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_BUF_XY_LEN
; IN : X/Y = pointer to input buffer, FNV_INPUT_LEN = byte count
; OUT: FNV_HASH0..FNV_HASH3 = FNV-1a hash, little-endian
; NOTE: Input bytes are masked to 7-bit ASCII before hash update.
; ----------------------------------------------------------------------------
FNV1A_BUF_XY_LEN:
                        STX             FNV_PTR_LO
                        STY             FNV_PTR_HI
                        JSR             FNV1A_INIT
                        LDA             FNV_INPUT_LEN
                        BEQ             FNV1A_BUF_DONE
                        LDY             #$00
FNV1A_BUF_LOOP:
                        LDA             (FNV_PTR_LO),Y
                        AND             #$7F
                        JSR             FNV1A_UPDATE_A
                        INY
                        BNE             FNV1A_BUF_NEXT
                        INC             FNV_PTR_HI
FNV1A_BUF_NEXT:
                        DEC             FNV_INPUT_LEN
                        BNE             FNV1A_BUF_LOOP
FNV1A_BUF_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_HBSTR_XY
; IN : X/Y = pointer to HIBIT-terminated string
; OUT: FNV_HASH0..FNV_HASH3 = FNV-1a hash, little-endian
; NOTE: $80 at offset 0 is treated as an empty HBSTR sentinel.
; ----------------------------------------------------------------------------
FNV1A_HBSTR_XY:
                        STX             FNV_PTR_LO
                        STY             FNV_PTR_HI
                        JSR             FNV1A_INIT
                        LDY             #$00
                        LDA             (FNV_PTR_LO),Y
                        CMP             #$80
                        BEQ             FNV1A_HBSTR_DONE
FNV1A_HBSTR_LOOP:
                        LDA             (FNV_PTR_LO),Y
                        PHA
                        AND             #$7F
                        JSR             FNV1A_UPDATE_A
                        PLA
                        BMI             FNV1A_HBSTR_DONE
                        INY
                        BNE             FNV1A_HBSTR_LOOP
                        INC             FNV_PTR_HI
                        BRA             FNV1A_HBSTR_LOOP
FNV1A_HBSTR_DONE:
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_INIT
; OUT: FNV_HASH = 32-bit FNV offset basis $811C9DC5, little-endian
; ----------------------------------------------------------------------------
FNV1A_INIT:
                        LDX             #$03
FNV1A_INIT_LOOP:
                        LDA             FNV1A_OFFSET_BASIS,X
                        STA             FNV_HASH0,X
                        DEX
                        BPL             FNV1A_INIT_LOOP
                        RTS

FNV1A_OFFSET_BASIS:
                        DB              $C5,$9D,$1C,$81

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_UPDATE_A
; IN : A = next input byte
; OUT: FNV_HASH *= $01000193 after low byte xor
; ----------------------------------------------------------------------------
FNV1A_UPDATE_A:
                        EOR             FNV_HASH0
                        STA             FNV_HASH0
                        JMP             FNV1A_MUL_PRIME

; ----------------------------------------------------------------------------
; ROUTINE: FNV1A_MUL_PRIME
; OUT: FNV_HASH = FNV_HASH * $01000193 mod 2^32
;
; $01000193 = 1 + 2 + 16 + 128 + 256 + 16777216.
; Keep the original hash in FNV_TERM and add shifted copies.
; ----------------------------------------------------------------------------
FNV1A_MUL_PRIME:
                        JSR             MATH_COPY_HASH_TO_TERM
                        LDX             #$01
                        JSR             MATH_SHLADD_TERM_N
                        LDX             #$03
                        JSR             MATH_SHLADD_TERM_N
                        LDX             #$03
                        JSR             MATH_SHLADD_TERM_N
                        LDX             #$01
                        JSR             MATH_SHLADD_TERM_N
                        JMP             MATH_ADD_TERM1_TO_HASH3

; ----------------------------------------------------------------------------
; ROUTINE: MATH_COPY_HASH_TO_TERM
; OUT: FNV_TERM = FNV_HASH
; ----------------------------------------------------------------------------
MATH_COPY_HASH_TO_TERM:
                        LDX             #$03
MATH_COPY_HASH_LOOP:
                        LDA             FNV_HASH0,X
                        STA             FNV_TERM0,X
                        DEX
                        BPL             MATH_COPY_HASH_LOOP
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: MATH_SHLADD_TERM_N
; IN : X = number of left shifts, must be nonzero
; OUT: FNV_TERM <<= X; FNV_HASH += FNV_TERM
; ----------------------------------------------------------------------------
MATH_SHLADD_TERM_N:
                        JSR             MATH_SHL_TERM_N
                        JMP             MATH_ADD_TERM_TO_HASH

; ----------------------------------------------------------------------------
; ROUTINE: MATH_SHL_TERM_N
; IN : X = number of left shifts, must be nonzero
; OUT: FNV_TERM <<= X
; ----------------------------------------------------------------------------
MATH_SHL_TERM_N:
                        ASL             FNV_TERM0
                        ROL             FNV_TERM1
                        ROL             FNV_TERM2
                        ROL             FNV_TERM3
                        DEX
                        BNE             MATH_SHL_TERM_N
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: MATH_ADD_TERM_TO_HASH
; OUT: FNV_HASH += FNV_TERM mod 2^32
; ----------------------------------------------------------------------------
MATH_ADD_TERM_TO_HASH:
                        CLC
                        LDA             FNV_HASH0
                        ADC             FNV_TERM0
                        STA             FNV_HASH0
                        LDA             FNV_HASH1
                        ADC             FNV_TERM1
                        STA             FNV_HASH1
                        LDA             FNV_HASH2
                        ADC             FNV_TERM2
                        STA             FNV_HASH2
                        LDA             FNV_HASH3
                        ADC             FNV_TERM3
                        STA             FNV_HASH3
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: MATH_ADD_TERM1_TO_HASH3
; OUT: FNV_HASH += original_hash << 24 mod 2^32
; NOTE: After the previous shift-add, FNV_TERM1 contains original_hash byte 0.
; ----------------------------------------------------------------------------
MATH_ADD_TERM1_TO_HASH3:
                        LDA             FNV_HASH3
                        CLC
                        ADC             FNV_TERM1
                        STA             FNV_HASH3
                        RTS

MSG_BANNER:
                        DB              "FNV-1A HASH. CTRL-C EXIT",$D3
MSG_PROMPT:
                        DB              "input> ",$A0
MSG_HASH:
                        DB              "hash: ",$A0
MSG_FULL:
                        DB              "line too lon",$E7

                        ENDMOD
                        END
