; ----------------------------------------------------------------------------
; life.asm
; - Conway's Game of Life (16x16 visible grid)
; - Linked to user program area base: $2000 (wdcln -c2000)
; - Left panel = generation N
; - Right panel = generation N+1
; - Controls:
;   n/space = next, r = random, m = manual, a = auto
;   i = toggle NMI count/debug mode, q = quit/cleanup/RTS
; ----------------------------------------------------------------------------

                        MODULE          LIFE_APP
                        XDEF            START

                        XREF            SYS_FLUSH_RX
                        XREF            SYS_READ_CSTRING_EDIT_ECHO_UPPER
                        XREF            SYS_VEC_SET_NMI_XY
                        XREF            SYS_WRITE_CHAR
                        XREF            SYS_WRITE_CSTRING
                        XREF            SYS_WRITE_CRLF
                        XREF            SYS_WRITE_HEX_BYTE
                        XREF            BIO_FTDI_READ_BYTE_NONBLOCK

; ----------------------------------------------------------------------------
; Zero-page workspace (app-local scratch)
; ----------------------------------------------------------------------------
ZP_P0_LO                EQU             $D0
ZP_P0_HI                EQU             $D1
ZP_P1_LO                EQU             $D2
ZP_P1_HI                EQU             $D3
ZP_TMP                  EQU             $D4
ZP_ROW                  EQU             $D5
ZP_COL                  EQU             $D6
ZP_SUM                  EQU             $D7
ZP_VAL                  EQU             $D8
ZP_P2_LO                EQU             $D9
ZP_P2_HI                EQU             $DA
ZP_OFF                  EQU             $DB

; ----------------------------------------------------------------------------
; User program area RAM layout ($0300-$12FF reserved for user payloads)
; ----------------------------------------------------------------------------
BOARD_LEFT              EQU             $1000          ; 18x18 = 324 bytes
BOARD_RIGHT             EQU             $1144          ; BOARD_LEFT + $0144
LINE_BUF                EQU             $1288          ; manual row input
GEN_LEFT                EQU             $12F0          ; visible left generation
RNG_SEED                EQU             $12F1          ; 8-bit random state
NMI_COUNT               EQU             $12F2          ; live NMI button count
PREV_NMI_LO             EQU             $12F3          ; NMI owner before Life
PREV_NMI_HI             EQU             $12F4
INTERRUPT_FLAG          EQU             $12F5          ; 0=debug NMI, 1=count NMI
VEC_NMI_LO              EQU             $7EFA
VEC_NMI_HI              EQU             $7EFB

; Board geometry
BOARD_STRIDE            EQU             $12            ; 18
BOARD_BYTES_TAIL        EQU             $44            ; 324-256
VIS_W                   EQU             $10            ; 16
VIS_H                   EQU             $10            ; 16
VIS_ORIGIN              EQU             $13            ; (1*18)+1

                        CODE
START:
                        JSR             SYS_FLUSH_RX
                        STZ             NMI_COUNT
                        STZ             INTERRUPT_FLAG
                        LDA             VEC_NMI_LO
                        STA             PREV_NMI_LO
                        LDA             VEC_NMI_HI
                        STA             PREV_NMI_HI
                        JSR             LIFE_APPLY_NMI_VECTOR
                        JSR             LIFE_RESET_DEFAULT
                        JSR             LIFE_RENDER_PAIR

MAIN_LOOP:
                        JSR             LIFE_PROMPT_AND_DISPATCH
                        BCC             MAIN_LOOP

QUIT_EXIT:
                        JSR             LIFE_CLEANUP
                        RTS

; ----------------------------------------------------------------------------
; Life lifecycle
; ----------------------------------------------------------------------------
LIFE_RESET_DEFAULT:
                        JSR             LIFE_CLEAR_LEFT
                        JSR             LIFE_CLEAR_RIGHT
                        LDA             #$A5
                        STA             RNG_SEED
                        JSR             LIFE_SEED_GLIDER
                        LDA             #$00
                        STA             GEN_LEFT
                        JSR             LIFE_STEP_LEFT_TO_RIGHT
                        RTS

LIFE_RANDOM:
                        JSR             LIFE_CLEAR_LEFT
                        JSR             LIFE_CLEAR_RIGHT
                        JSR             LIFE_RANDOMIZE_LEFT
                        LDA             #$00
                        STA             GEN_LEFT
                        JSR             LIFE_STEP_LEFT_TO_RIGHT
                        JSR             LIFE_RENDER_PAIR
                        RTS

LIFE_MANUAL:
                        JSR             LIFE_CLEAR_LEFT
                        JSR             LIFE_CLEAR_RIGHT
                        JSR             LIFE_EDIT_MODE
                        LDA             #$00
                        STA             GEN_LEFT
                        JSR             LIFE_STEP_LEFT_TO_RIGHT
                        JSR             LIFE_RENDER_PAIR
                        RTS

LIFE_NEXT:
                        JSR             LIFE_COPY_RIGHT_TO_LEFT
                        INC             GEN_LEFT
                        JSR             LIFE_STEP_LEFT_TO_RIGHT
                        JSR             LIFE_RENDER_PAIR
                        RTS

; OUT: C=1 quit requested, C=0 otherwise
LIFE_AUTO:
                        LDX             #<MSG_AUTO_RUN
                        LDY             #>MSG_AUTO_RUN
                        JSR             LIFE_PRINT_LINE_XY
AUTO_LOOP:
                        JSR             LIFE_AUTO_CHECK_KEY
                        BCS             AUTO_QUIT
                        JSR             LIFE_NEXT
                        BRA             AUTO_LOOP
AUTO_QUIT:
                        LDX             #<MSG_QUIT
                        LDY             #>MSG_QUIT
                        JSR             LIFE_PRINT_LINE_XY
                        SEC
                        RTS

LIFE_AUTO_CHECK_KEY:
                        JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        BCC             LIFE_AUTO_KEY_NONE
                        AND             #$7F
                        CMP             #'Q'
                        BEQ             LIFE_AUTO_KEY_QUIT
                        CMP             #'q'
                        BEQ             LIFE_AUTO_KEY_QUIT
                        CMP             #'I'
                        BEQ             LIFE_AUTO_KEY_INTERRUPT
                        CMP             #'i'
                        BEQ             LIFE_AUTO_KEY_INTERRUPT
LIFE_AUTO_KEY_NONE:
                        CLC
                        RTS
LIFE_AUTO_KEY_INTERRUPT:
                        JSR             LIFE_TOGGLE_INTERRUPT
                        CLC
                        RTS
LIFE_AUTO_KEY_QUIT:
                        SEC
                        RTS

; ----------------------------------------------------------------------------
; Prompt / command dispatch
; OUT: C=1 quit, C=0 continue
; ----------------------------------------------------------------------------
LIFE_PROMPT_AND_DISPATCH:
                        LDX             #<MSG_PROMPT
                        LDY             #>MSG_PROMPT
                        JSR             LIFE_PRINT_XY
CMD_WAIT:
                        INC             RNG_SEED
                        JSR             BIO_FTDI_READ_BYTE_NONBLOCK
                        BCC             CMD_WAIT
                        AND             #$7F
                        CMP             #$0D
                        BEQ             CMD_WAIT
                        CMP             #$0A
                        BEQ             CMD_WAIT
                        CMP             #$20
                        BCC             CMD_WAIT
                        CMP             #$7F
                        BEQ             CMD_WAIT

                        STA             ZP_TMP
                        JSR             SYS_WRITE_CHAR
                        JSR             SYS_WRITE_CRLF

                        LDA             ZP_TMP
                        CMP             #' '
                        BEQ             CMD_NEXT
                        CMP             #'N'
                        BEQ             CMD_NEXT
                        CMP             #'n'
                        BEQ             CMD_NEXT
                        CMP             #'A'
                        BEQ             CMD_AUTO
                        CMP             #'a'
                        BEQ             CMD_AUTO
                        CMP             #'R'
                        BEQ             CMD_RANDOM
                        CMP             #'r'
                        BEQ             CMD_RANDOM
                        CMP             #'M'
                        BEQ             CMD_MANUAL
                        CMP             #'m'
                        BEQ             CMD_MANUAL
                        CMP             #'I'
                        BEQ             CMD_INTERRUPT
                        CMP             #'i'
                        BEQ             CMD_INTERRUPT
                        CMP             #'Q'
                        BEQ             CMD_QUIT
                        CMP             #'q'
                        BEQ             CMD_QUIT

                        LDX             #<MSG_BAD_KEY
                        LDY             #>MSG_BAD_KEY
                        JSR             LIFE_PRINT_LINE_XY
                        CLC
                        RTS

CMD_NEXT:
                        JSR             SYS_FLUSH_RX
                        JSR             LIFE_NEXT
                        CLC
                        RTS

CMD_AUTO:
                        JSR             SYS_FLUSH_RX
                        JSR             LIFE_AUTO
                        RTS

CMD_RANDOM:
                        JSR             SYS_FLUSH_RX
                        JSR             LIFE_RANDOM
                        CLC
                        RTS

CMD_MANUAL:
                        JSR             SYS_FLUSH_RX
                        JSR             LIFE_MANUAL
                        CLC
                        RTS

CMD_INTERRUPT:
                        JSR             SYS_FLUSH_RX
                        JSR             LIFE_TOGGLE_INTERRUPT
                        CLC
                        RTS

CMD_QUIT:
                        LDX             #<MSG_QUIT
                        LDY             #>MSG_QUIT
                        JSR             LIFE_PRINT_LINE_XY
                        SEC
                        RTS

LIFE_CLEANUP:
                        JSR             SYS_FLUSH_RX
                        LDX             PREV_NMI_LO
                        LDY             PREV_NMI_HI
                        JSR             SYS_VEC_SET_NMI_XY
                        RTS

LIFE_TOGGLE_INTERRUPT:
                        LDA             INTERRUPT_FLAG
                        EOR             #$01
                        STA             INTERRUPT_FLAG
                        JSR             LIFE_APPLY_NMI_VECTOR
                        JSR             LIFE_RENDER_PAIR
                        RTS

LIFE_APPLY_NMI_VECTOR:
                        LDA             INTERRUPT_FLAG
                        BEQ             LIFE_APPLY_DEBUG_VECTOR
                        LDX             #<LIFE_NMI_TRAP
                        LDY             #>LIFE_NMI_TRAP
                        JMP             SYS_VEC_SET_NMI_XY
LIFE_APPLY_DEBUG_VECTOR:
                        LDX             PREV_NMI_LO
                        LDY             PREV_NMI_HI
                        JMP             SYS_VEC_SET_NMI_XY

; ----------------------------------------------------------------------------
; Render pair (left=GEN_LEFT, right=GEN_LEFT+1)
; ----------------------------------------------------------------------------
LIFE_RENDER_PAIR:
                        JSR             SYS_WRITE_CRLF
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             LIFE_PRINT_LINE_XY

                        LDX             #<MSG_GEN_LEFT
                        LDY             #>MSG_GEN_LEFT
                        JSR             LIFE_PRINT_XY
                        LDA             GEN_LEFT
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_GEN_RIGHT
                        LDY             #>MSG_GEN_RIGHT
                        JSR             LIFE_PRINT_XY
                        LDA             GEN_LEFT
                        CLC
                        ADC             #$01
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_NMI_COUNT
                        LDY             #>MSG_NMI_COUNT
                        JSR             LIFE_PRINT_XY
                        LDA             NMI_COUNT
                        JSR             SYS_WRITE_HEX_BYTE
                        LDX             #<MSG_INT_FLAG
                        LDY             #>MSG_INT_FLAG
                        JSR             LIFE_PRINT_XY
                        LDA             INTERRUPT_FLAG
                        JSR             SYS_WRITE_HEX_BYTE
                        JSR             SYS_WRITE_CRLF
                        JSR             LIFE_RENDER_NMI_VECTORS

                        LDA             #<BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_HI
                        LDA             #<BOARD_RIGHT+VIS_ORIGIN
                        STA             ZP_P1_LO
                        LDA             #>BOARD_RIGHT+VIS_ORIGIN
                        STA             ZP_P1_HI
                        LDA             #VIS_H
                        STA             ZP_ROW
RENDER_ROW_LOOP:
                        JSR             LIFE_RENDER_ONE_ROW
                        ; move row pointers by stride (18)
                        CLC
                        LDA             ZP_P0_LO
                        ADC             #BOARD_STRIDE
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P0_HI
                        CLC
                        LDA             ZP_P1_LO
                        ADC             #BOARD_STRIDE
                        STA             ZP_P1_LO
                        LDA             ZP_P1_HI
                        ADC             #$00
                        STA             ZP_P1_HI
                        DEC             ZP_ROW
                        BNE             RENDER_ROW_LOOP
                        RTS

LIFE_RENDER_NMI_VECTORS:
                        LDX             #<MSG_VEC_EFFECT
                        LDY             #>MSG_VEC_EFFECT
                        JSR             LIFE_PRINT_XY
                        JSR             LIFE_PRINT_ACTIVE_NMI_ADDR
                        LDX             #<MSG_VEC_TOGGLE
                        LDY             #>MSG_VEC_TOGGLE
                        JSR             LIFE_PRINT_XY
                        LDA             INTERRUPT_FLAG
                        BEQ             LIFE_RENDER_TOGGLE_COUNT
                        JSR             LIFE_PRINT_DEBUG_NMI_ADDR
                        BRA             LIFE_RENDER_NMI_VECTORS_DONE
LIFE_RENDER_TOGGLE_COUNT:
                        JSR             LIFE_PRINT_COUNT_NMI_ADDR
LIFE_RENDER_NMI_VECTORS_DONE:
                        JSR             SYS_WRITE_CRLF
                        RTS

LIFE_PRINT_ACTIVE_NMI_ADDR:
                        LDA             VEC_NMI_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             VEC_NMI_LO
                        JMP             SYS_WRITE_HEX_BYTE

LIFE_PRINT_DEBUG_NMI_ADDR:
                        LDA             PREV_NMI_HI
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             PREV_NMI_LO
                        JMP             SYS_WRITE_HEX_BYTE

LIFE_PRINT_COUNT_NMI_ADDR:
                        LDA             #>LIFE_NMI_TRAP
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #<LIFE_NMI_TRAP
                        JMP             SYS_WRITE_HEX_BYTE

LIFE_RENDER_ONE_ROW:
                        LDA             #VIS_W
                        STA             ZP_COL
RENDER_LEFT_LOOP:
                        LDY             #$00
                        LDA             (ZP_P0_LO),Y
                        JSR             LIFE_CELL_CHAR
                        JSR             SYS_WRITE_CHAR
                        INC             ZP_P0_LO
                        BNE             RENDER_LEFT_PTR_OK
                        INC             ZP_P0_HI
RENDER_LEFT_PTR_OK:
                        DEC             ZP_COL
                        BNE             RENDER_LEFT_LOOP

                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #'|'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        LDA             #VIS_W
                        STA             ZP_COL
RENDER_RIGHT_LOOP:
                        LDY             #$00
                        LDA             (ZP_P1_LO),Y
                        JSR             LIFE_CELL_CHAR
                        JSR             SYS_WRITE_CHAR
                        INC             ZP_P1_LO
                        BNE             RENDER_RIGHT_PTR_OK
                        INC             ZP_P1_HI
RENDER_RIGHT_PTR_OK:
                        DEC             ZP_COL
                        BNE             RENDER_RIGHT_LOOP

                        SEC
                        LDA             ZP_P0_LO
                        SBC             #VIS_W
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        SBC             #$00
                        STA             ZP_P0_HI
                        SEC
                        LDA             ZP_P1_LO
                        SBC             #VIS_W
                        STA             ZP_P1_LO
                        LDA             ZP_P1_HI
                        SBC             #$00
                        STA             ZP_P1_HI

                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #'|'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        LDA             #VIS_W
                        STA             ZP_COL
RENDER_LEFT_STATUS_LOOP:
                        LDY             #$00
                        LDA             (ZP_P0_LO),Y
                        JSR             LIFE_STATUS_CHAR
                        JSR             SYS_WRITE_CHAR
                        INC             ZP_P0_LO
                        BNE             RENDER_LEFT_STATUS_PTR_OK
                        INC             ZP_P0_HI
RENDER_LEFT_STATUS_PTR_OK:
                        DEC             ZP_COL
                        BNE             RENDER_LEFT_STATUS_LOOP

                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #'|'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        LDA             #VIS_W
                        STA             ZP_COL
RENDER_RIGHT_STATUS_LOOP:
                        LDY             #$00
                        LDA             (ZP_P1_LO),Y
                        JSR             LIFE_STATUS_CHAR
                        JSR             SYS_WRITE_CHAR
                        INC             ZP_P1_LO
                        BNE             RENDER_RIGHT_STATUS_PTR_OK
                        INC             ZP_P1_HI
RENDER_RIGHT_STATUS_PTR_OK:
                        DEC             ZP_COL
                        BNE             RENDER_RIGHT_STATUS_LOOP
                        JSR             SYS_WRITE_CRLF

                        ; row routine consumed the status pass last.
                        ; caller adds +18, so back up 16 now to net +2 here.
                        SEC
                        LDA             ZP_P0_LO
                        SBC             #VIS_W
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        SBC             #$00
                        STA             ZP_P0_HI
                        SEC
                        LDA             ZP_P1_LO
                        SBC             #VIS_W
                        STA             ZP_P1_LO
                        LDA             ZP_P1_HI
                        SBC             #$00
                        STA             ZP_P1_HI
                        RTS

; ----------------------------------------------------------------------------
; Step: LEFT -> RIGHT
; ----------------------------------------------------------------------------
LIFE_STEP_LEFT_TO_RIGHT:
                        JSR             LIFE_CLEAR_RIGHT

                        LDA             #<BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_HI
                        LDA             #<BOARD_RIGHT+VIS_ORIGIN
                        STA             ZP_P1_LO
                        LDA             #>BOARD_RIGHT+VIS_ORIGIN
                        STA             ZP_P1_HI
                        LDA             #VIS_H
                        STA             ZP_ROW
STEP_ROW_LOOP:
                        LDA             #VIS_W
                        STA             ZP_COL
STEP_CELL_LOOP:
                        JSR             LIFE_STEP_ONE_CELL

                        INC             ZP_P0_LO
                        BNE             STEP_P0_OK
                        INC             ZP_P0_HI
STEP_P0_OK:
                        INC             ZP_P1_LO
                        BNE             STEP_P1_OK
                        INC             ZP_P1_HI
STEP_P1_OK:
                        DEC             ZP_COL
                        BNE             STEP_CELL_LOOP

                        ; advance from col16 border to next row col1 ( +2 )
                        CLC
                        LDA             ZP_P0_LO
                        ADC             #$02
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P0_HI
                        CLC
                        LDA             ZP_P1_LO
                        ADC             #$02
                        STA             ZP_P1_LO
                        LDA             ZP_P1_HI
                        ADC             #$00
                        STA             ZP_P1_HI

                        DEC             ZP_ROW
                        BNE             STEP_ROW_LOOP
                        RTS

LIFE_STEP_ONE_CELL:
                        STZ             ZP_SUM

                        LDA             #$ED            ; -19
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$EE            ; -18
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$EF            ; -17
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$FF            ; -1
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$01            ; +1
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$11            ; +17
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$12            ; +18
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM
                        LDA             #$13            ; +19
                        JSR             LIFE_READ_REL_P0
                        CLC
                        ADC             ZP_SUM
                        STA             ZP_SUM

                        LDY             #$00
                        LDA             (ZP_P0_LO),Y
                        BEQ             STEP_DEAD_RULE
                        ; alive survives on 2 or 3
                        LDA             ZP_SUM
                        CMP             #$03
                        BEQ             STEP_STORE_SURVIVOR
                        CMP             #$02
                        BEQ             STEP_STORE_SURVIVOR
                        BRA             STEP_STORE_DEAD
STEP_DEAD_RULE:
                        ; dead births on 3
                        LDA             ZP_SUM
                        CMP             #$03
                        BEQ             STEP_STORE_BIRTH
STEP_STORE_DEAD:
                        LDA             #$00
                        LDY             #$00
                        STA             (ZP_P1_LO),Y
                        RTS
STEP_STORE_BIRTH:
                        LDA             #$01
                        LDY             #$00
                        STA             (ZP_P1_LO),Y
                        RTS
STEP_STORE_SURVIVOR:
                        LDY             #$00
                        LDA             (ZP_P0_LO),Y
                        CMP             #$09
                        BCS             STEP_SURVIVOR_MAX
                        CLC
                        ADC             #$01
STEP_SURVIVOR_MAX:
                        STA             (ZP_P1_LO),Y
                        RTS

; IN : A = signed 8-bit offset from cell pointer in ZP_P0_LO/HI
; OUT: A = byte at [ZP_P0 + signed offset]
LIFE_READ_REL_P0:
                        STA             ZP_OFF
                        CLC
                        LDA             ZP_P0_LO
                        ADC             ZP_OFF
                        STA             ZP_P2_LO
                        BIT             ZP_OFF
                        BMI             LIFE_READ_REL_NEG
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P2_HI
                        BRA             LIFE_READ_REL_FETCH
LIFE_READ_REL_NEG:
                        LDA             ZP_P0_HI
                        ADC             #$FF
                        STA             ZP_P2_HI
LIFE_READ_REL_FETCH:
                        LDY             #$00
                        LDA             (ZP_P2_LO),Y
                        BEQ             LIFE_READ_REL_DEAD
                        LDA             #$01
LIFE_READ_REL_DEAD:
                        RTS

; ----------------------------------------------------------------------------
; Board utilities
; ----------------------------------------------------------------------------
LIFE_CLEAR_LEFT:
                        LDA             #<BOARD_LEFT
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT
                        STA             ZP_P0_HI
                        JMP             LIFE_CLEAR_P0

LIFE_CLEAR_RIGHT:
                        LDA             #<BOARD_RIGHT
                        STA             ZP_P0_LO
                        LDA             #>BOARD_RIGHT
                        STA             ZP_P0_HI
                        JMP             LIFE_CLEAR_P0

LIFE_CLEAR_P0:
                        LDY             #$00
                        LDA             #$00
CLEAR_256_LOOP:
                        STA             (ZP_P0_LO),Y
                        INY
                        BNE             CLEAR_256_LOOP
                        INC             ZP_P0_HI
                        LDY             #$00
                        LDX             #BOARD_BYTES_TAIL
CLEAR_TAIL_LOOP:
                        STA             (ZP_P0_LO),Y
                        INY
                        DEX
                        BNE             CLEAR_TAIL_LOOP
                        RTS

LIFE_COPY_RIGHT_TO_LEFT:
                        LDA             #<BOARD_RIGHT
                        STA             ZP_P0_LO
                        LDA             #>BOARD_RIGHT
                        STA             ZP_P0_HI
                        LDA             #<BOARD_LEFT
                        STA             ZP_P1_LO
                        LDA             #>BOARD_LEFT
                        STA             ZP_P1_HI
                        LDY             #$00
COPY_256_LOOP:
                        LDA             (ZP_P0_LO),Y
                        STA             (ZP_P1_LO),Y
                        INY
                        BNE             COPY_256_LOOP
                        INC             ZP_P0_HI
                        INC             ZP_P1_HI
                        LDY             #$00
                        LDX             #BOARD_BYTES_TAIL
COPY_TAIL_LOOP:
                        LDA             (ZP_P0_LO),Y
                        STA             (ZP_P1_LO),Y
                        INY
                        DEX
                        BNE             COPY_TAIL_LOOP
                        RTS

; OUT: C=1 equal, C=0 different (full 324-byte compare)
LIFE_BOARDS_EQUAL:
                        LDA             #<BOARD_LEFT
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT
                        STA             ZP_P0_HI
                        LDA             #<BOARD_RIGHT
                        STA             ZP_P1_LO
                        LDA             #>BOARD_RIGHT
                        STA             ZP_P1_HI
                        LDY             #$00
EQ_256_LOOP:
                        LDA             (ZP_P0_LO),Y
                        CMP             (ZP_P1_LO),Y
                        BNE             EQ_NO
                        INY
                        BNE             EQ_256_LOOP
                        INC             ZP_P0_HI
                        INC             ZP_P1_HI
                        LDY             #$00
                        LDX             #BOARD_BYTES_TAIL
EQ_TAIL_LOOP:
                        LDA             (ZP_P0_LO),Y
                        CMP             (ZP_P1_LO),Y
                        BNE             EQ_NO
                        INY
                        DEX
                        BNE             EQ_TAIL_LOOP
                        SEC
                        RTS
EQ_NO:
                        CLC
                        RTS

; ----------------------------------------------------------------------------
; Default seed pattern (glider) in LEFT board
; ----------------------------------------------------------------------------
LIFE_SEED_GLIDER:
                        ; (1,0), (2,1), (0,2), (1,2), (2,2)
                        LDA             #$01
                        LDX             #$01
                        LDY             #$00
                        JSR             LIFE_SET_LEFT_XY
                        LDA             #$01
                        LDX             #$02
                        LDY             #$01
                        JSR             LIFE_SET_LEFT_XY
                        LDA             #$01
                        LDX             #$00
                        LDY             #$02
                        JSR             LIFE_SET_LEFT_XY
                        LDA             #$01
                        LDX             #$01
                        LDY             #$02
                        JSR             LIFE_SET_LEFT_XY
                        LDA             #$01
                        LDX             #$02
                        LDY             #$02
                        JSR             LIFE_SET_LEFT_XY
                        RTS

LIFE_RANDOMIZE_LEFT:
                        LDA             RNG_SEED
                        BNE             LIFE_RANDOM_SEED_OK
                        LDA             #$A5
                        STA             RNG_SEED
LIFE_RANDOM_SEED_OK:
                        LDA             #<BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_HI
                        LDA             #VIS_H
                        STA             ZP_ROW
RANDOM_ROW_LOOP:
                        LDA             #VIS_W
                        STA             ZP_COL
RANDOM_CELL_LOOP:
                        JSR             LIFE_RAND8
                        AND             #$03
                        CMP             #$01
                        LDA             #$00
                        BCS             RANDOM_STORE
                        JSR             LIFE_RAND8
                        AND             #$03
                        CLC
                        ADC             #$01
RANDOM_STORE:
                        LDY             #$00
                        STA             (ZP_P0_LO),Y
                        INC             ZP_P0_LO
                        BNE             RANDOM_PTR_OK
                        INC             ZP_P0_HI
RANDOM_PTR_OK:
                        DEC             ZP_COL
                        BNE             RANDOM_CELL_LOOP

                        CLC
                        LDA             ZP_P0_LO
                        ADC             #$02
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P0_HI
                        DEC             ZP_ROW
                        BNE             RANDOM_ROW_LOOP
                        RTS

LIFE_RAND8:
                        LDA             RNG_SEED
                        ASL             A
                        BCC             RAND_NO_TAP
                        EOR             #$1D
RAND_NO_TAP:
                        BNE             RAND_STORE
                        LDA             #$A5
RAND_STORE:
                        STA             RNG_SEED
                        RTS

LIFE_CELL_CHAR:
                        BEQ             LIFE_CELL_CHAR_DEAD
                        CMP             #$0A
                        BCC             LIFE_CELL_CHAR_DIGIT
                        LDA             #$09
LIFE_CELL_CHAR_DIGIT:
                        CLC
                        ADC             #'0'
                        RTS
LIFE_CELL_CHAR_DEAD:
                        LDA             #'.'
                        RTS

LIFE_STATUS_CHAR:
                        BEQ             LIFE_STATUS_CHAR_DEAD
                        LDA             #'#'
                        RTS
LIFE_STATUS_CHAR_DEAD:
                        LDA             #'.'
                        RTS

; ----------------------------------------------------------------------------
; Manual mode
; - Enter up to 16 chars per row. 1-9 set live age, . or 0 set dead.
; - Blank keeps row. / as first char exits early.
; ----------------------------------------------------------------------------
LIFE_EDIT_MODE:
                        LDX             #<MSG_EDIT_HDR_1
                        LDY             #>MSG_EDIT_HDR_1
                        JSR             LIFE_PRINT_LINE_XY
                        LDX             #<MSG_EDIT_HDR_2
                        LDY             #>MSG_EDIT_HDR_2
                        JSR             LIFE_PRINT_LINE_XY

                        LDA             #<BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_HI
                        LDA             #$00
                        STA             ZP_ROW
EDIT_ROW_LOOP:
                        LDA             #'R'
                        JSR             SYS_WRITE_CHAR
                        LDA             ZP_ROW
                        JSR             SYS_WRITE_HEX_BYTE
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        LDA             #VIS_W
                        STA             ZP_COL
EDIT_PRINT_CUR_LOOP:
                        LDY             #$00
                        LDA             (ZP_P0_LO),Y
                        JSR             LIFE_CELL_CHAR
                        JSR             SYS_WRITE_CHAR
                        INC             ZP_P0_LO
                        BNE             EDIT_CUR_PTR_OK
                        INC             ZP_P0_HI
EDIT_CUR_PTR_OK:
                        DEC             ZP_COL
                        BNE             EDIT_PRINT_CUR_LOOP

                        SEC
                        LDA             ZP_P0_LO
                        SBC             #VIS_W
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        SBC             #$00
                        STA             ZP_P0_HI

                        LDA             #' '
                        JSR             SYS_WRITE_CHAR
                        LDA             #':'
                        JSR             SYS_WRITE_CHAR
                        LDA             #' '
                        JSR             SYS_WRITE_CHAR

                        LDX             #<LINE_BUF
                        LDY             #>LINE_BUF
                        JSR             SYS_READ_CSTRING_EDIT_ECHO_UPPER
                        JSR             SYS_WRITE_CRLF
                        CMP             #$00
                        BEQ             EDIT_ROW_KEEP

                        LDA             LINE_BUF
                        CMP             #'/'
                        BEQ             EDIT_DONE

                        LDA             ZP_P0_LO
                        STA             ZP_P1_LO
                        LDA             ZP_P0_HI
                        STA             ZP_P1_HI
                        LDY             #$00
EDIT_PARSE_LOOP:
                        CPY             #VIS_W
                        BEQ             EDIT_ROW_KEEP
                        LDA             LINE_BUF,Y
                        BEQ             EDIT_ROW_KEEP
                        CMP             #'1'
                        BCC             EDIT_PARSE_DEAD
                        CMP             #':'
                        BCS             EDIT_PARSE_DEAD
                        SEC
                        SBC             #'0'
                        STA             (ZP_P1_LO),Y
                        BRA             EDIT_NEXT_CHAR
EDIT_PARSE_DEAD:
                        CMP             #'.'
                        BEQ             EDIT_SET_DEAD
                        CMP             #'0'
                        BEQ             EDIT_SET_DEAD
                        CMP             #'-'
                        BEQ             EDIT_SET_DEAD
                        CMP             #'_'
                        BNE             EDIT_NEXT_CHAR
EDIT_SET_DEAD:
                        LDA             #$00
                        STA             (ZP_P1_LO),Y
EDIT_NEXT_CHAR:
                        INY
                        BRA             EDIT_PARSE_LOOP

EDIT_ROW_KEEP:
                        CLC
                        LDA             ZP_P0_LO
                        ADC             #BOARD_STRIDE
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P0_HI
                        INC             ZP_ROW
                        LDA             ZP_ROW
                        CMP             #VIS_H
                        BEQ             EDIT_DONE
                        JMP             EDIT_ROW_LOOP
EDIT_DONE:
                        RTS

; IN: A=value(0/1), X=col(0..15), Y=row(0..15)
LIFE_SET_LEFT_XY:
                        STA             ZP_VAL
                        STX             ZP_COL
                        STY             ZP_ROW

                        LDA             #<BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_LO
                        LDA             #>BOARD_LEFT+VIS_ORIGIN
                        STA             ZP_P0_HI

SET_ROW_ADV_LOOP:
                        LDA             ZP_ROW
                        BEQ             SET_COL_ADV
                        DEC             ZP_ROW
                        CLC
                        LDA             ZP_P0_LO
                        ADC             #BOARD_STRIDE
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P0_HI
                        BRA             SET_ROW_ADV_LOOP

SET_COL_ADV:
                        CLC
                        LDA             ZP_P0_LO
                        ADC             ZP_COL
                        STA             ZP_P0_LO
                        LDA             ZP_P0_HI
                        ADC             #$00
                        STA             ZP_P0_HI

                        LDY             #$00
                        LDA             ZP_VAL
                        STA             (ZP_P0_LO),Y
                        RTS

; ----------------------------------------------------------------------------
; NMI trap for LIFE session:
; - I=0 chains to the previous owner, normally Himonia-f debug NMI.
; - I=1 silently counts button presses and returns to interrupted code.
; ----------------------------------------------------------------------------
LIFE_NMI_TRAP:
                        PHA
                        PHP
                        LDA             INTERRUPT_FLAG
                        BNE             LIFE_NMI_COUNT
                        PLP
                        PLA
                        JMP             (PREV_NMI_LO)
LIFE_NMI_COUNT:
                        PLP
                        PLA
                        INC             NMI_COUNT
                        RTI

; ----------------------------------------------------------------------------
; tiny print helpers
; ----------------------------------------------------------------------------
LIFE_PRINT_XY:
                        JSR             SYS_WRITE_CSTRING
                        RTS

LIFE_PRINT_LINE_XY:
                        JSR             SYS_WRITE_CSTRING
                        JSR             SYS_WRITE_CRLF
                        RTS

                        DATA
MSG_TITLE:              DB              "Conway Life 16x16  age N | age N+1 | live N | live N+1",$00
MSG_GEN_LEFT:           DB              "Left G=$",$00
MSG_GEN_RIGHT:          DB              "   Right G=$",$00
MSG_NMI_COUNT:          DB              "   NMI=$",$00
MSG_INT_FLAG:           DB              "   I=$",$00
MSG_VEC_EFFECT:         DB              "Vector in effect=$",$00
MSG_VEC_TOGGLE:         DB              "   Toggled vector=$",$00
MSG_PROMPT:             DB              "[n]=next  [r]=random  [m]=manual  [a]=auto  [i]=int  [q]=quit > ",$00
MSG_BAD_KEY:            DB              "Use n/space, r, m, a, i, or q.",$00
MSG_AUTO_RUN:           DB              "Auto: running; i toggles NMI, q quits.",$00
MSG_EDIT_HDR_1:         DB              "Manual: enter 16 chars per row; blank keeps row.",$00
MSG_EDIT_HDR_2:         DB              "1-9 live age, . or 0 dead, / done.",$00
MSG_QUIT:               DB              "Life: quit.",$00

                        ENDMOD
                        END
