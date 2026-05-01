
                        XDEF            START

                        XREF            SYS_WRITE_CSTRING
                        XREF            COR_FTDI_WRITE_CRLF 
                        INCLUDE         "STASH/ftdi/ftdi-drv.inc"
                        XDEF            PIN_FTDI_WRITE_BYTE_NONBLOCK

                        CODE
START:
                        LDX             #<MSG_TITLE
                        LDY             #>MSG_TITLE
                        JSR             SYS_WRITE_CSTRING

                        LDX             #<MSG_PHASE_NO_INIT
                        LDY             #>MSG_PHASE_NO_INIT
                        JSR             SYS_WRITE_CSTRING

; ----------------------------------------------------------------------------
; PIN-L0-FTDI PHASE A: PRE-INIT
; ----------------------------------------------------------------------------
                        JSR             PIN_FTDI_POLL_RX_READY
                        BCS             PH0_POLL_READY
PH0_POLL_EMPTY:
                        LDX             #<MSG_NOINIT_POLL_EMPTY
                        LDY             #>MSG_NOINIT_POLL_EMPTY
                        JSR             SYS_WRITE_CSTRING
                        BRA             PH0_AFTER_POLL
PH0_POLL_READY:
                        LDX             #<MSG_NOINIT_POLL_READY
                        LDY             #>MSG_NOINIT_POLL_READY
                        JSR             SYS_WRITE_CSTRING
PH0_AFTER_POLL:
                        JSR             DRV_PRINT_DELAY_MSG
                        JSR             DRV_DELAY_3S_8MHZ

                        LDX             #<MSG_NOINIT_WHAT_CHAR
                        LDY             #>MSG_NOINIT_WHAT_CHAR
                        JSR             SYS_WRITE_CSTRING

                        JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCS             PH0_READ_OK
PH0_READ_FAIL:
                        LDX             #<MSG_NOINIT_READ_FAIL
                        LDY             #>MSG_NOINIT_READ_FAIL
                        JSR             SYS_WRITE_CSTRING
                        BRA             PH0_AFTER_READ
PH0_READ_OK:
                        PHA
                        LDX             #<MSG_NOINIT_READ_OK
                        LDY             #>MSG_NOINIT_READ_OK
                        JSR             SYS_WRITE_CSTRING
                        PLA
                        JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        JSR             COR_FTDI_WRITE_CRLF
PH0_AFTER_READ:
                        JSR             DRV_PRINT_DELAY_MSG
                        JSR             DRV_DELAY_3S_8MHZ

; ----------------------------------------------------------------------------
; PIN-L0-FTDI PHASE B: POST-INIT
; ----------------------------------------------------------------------------
                        JSR             PIN_FTDI_INIT
                        LDX             #<MSG_INIT_CALLED
                        LDY             #>MSG_INIT_CALLED
                        JSR             SYS_WRITE_CSTRING

                        JSR             PIN_FTDI_POLL_RX_READY
                        BCS             PH1_POLL_READY
PH1_POLL_EMPTY:
                        LDX             #<MSG_INIT_POLL_EMPTY
                        LDY             #>MSG_INIT_POLL_EMPTY
                        JSR             SYS_WRITE_CSTRING
                        BRA             PH1_AFTER_POLL
PH1_POLL_READY:
                        LDX             #<MSG_INIT_POLL_READY
                        LDY             #>MSG_INIT_POLL_READY
                        JSR             SYS_WRITE_CSTRING
PH1_AFTER_POLL:
                        JSR             DRV_PRINT_DELAY_MSG
                        JSR             DRV_DELAY_3S_8MHZ

                        LDX             #<MSG_INIT_WHAT_CHAR
                        LDY             #>MSG_INIT_WHAT_CHAR
                        JSR             SYS_WRITE_CSTRING

                        JSR             PIN_FTDI_READ_BYTE_NONBLOCK
                        BCS             PH1_READ_OK
PH1_READ_FAIL:
                        LDX             #<MSG_INIT_READ_FAIL
                        LDY             #>MSG_INIT_READ_FAIL
                        JSR             SYS_WRITE_CSTRING
                        BRA             PH1_AFTER_READ
PH1_READ_OK:
                        PHA
                        LDX             #<MSG_INIT_READ_OK
                        LDY             #>MSG_INIT_READ_OK
                        JSR             SYS_WRITE_CSTRING
                        PLA
                        JSR             PIN_FTDI_WRITE_BYTE_NONBLOCK
                        JSR             COR_FTDI_WRITE_CRLF 
PH1_AFTER_READ:
                        JSR             DRV_PRINT_DELAY_MSG
                        JSR             DRV_DELAY_3S_8MHZ

; PIN-L0-FTDI-ENUM-CHK-01
ENUM_CHECK:             JSR             PIN_FTDI_CHECK_ENUMERATED 
                        BCS             ENUM_OK 

                        BRK             01

                        BRA             DONE
ENUM_OK:
                        LDX             #<MSG_INIT_ENUMERATED
                        LDY             #>MSG_INIT_ENUMERATED
                        JSR             SYS_WRITE_CSTRING


DONE:                   BRA             PH1_AFTER_READ




                       BRK             00

; ----------------------------------------------------------------------------
; ROUTINE: DRV_PRINT_DELAY_MSG  [HASH:E5EC2D79]
; TAGS: MMIO, REGISTER, NOSTACK
; ----------------------------------------------------------------------------
DRV_PRINT_DELAY_MSG:
                        LDX             #<MSG_DELAY
                        LDY             #>MSG_DELAY
                        JSR             SYS_WRITE_CSTRING
                        RTS

; ----------------------------------------------------------------------------
; ROUTINE: DRV_DELAY_3S_8MHZ  [HASH:B61BB98A]
; TAGS: MMIO, REGISTER, NOSTACK
; PURPOSE: Busy-wait delay tuned for approximately 3.0 seconds at 8 MHz.
; IN : none
; OUT: none
; CLOBBERS: A, X, Y
; ----------------------------------------------------------------------------
DRV_DELAY_3S_8MHZ:
                        LDA             #$6A            ; 106 outer loops
DRV_DELAY3_OUTER:
                        LDX             #$B6            ; 182 middle loops
DRV_DELAY3_MIDDLE:
                        LDY             #$F8            ; 248 inner loops
DRV_DELAY3_INNER:
                        DEY
                        BNE             DRV_DELAY3_INNER
                        DEX
                        BNE             DRV_DELAY3_MIDDLE
                        DEC             A
                        BNE             DRV_DELAY3_OUTER
                        RTS

MSG_PHASE_NO_INIT:      DB              13,10,"PIN-L0-FTDI PHASE: PRE-INIT",13,10,0
MSG_TITLE:              DB              13,10,"PIN-L0-FTDI TEST SUITE",13,10,0
MSG_NOINIT_POLL_EMPTY:  DB              "PIN-L0-FTDI-POLL-NB-01: EMPTY",13,10,0
MSG_NOINIT_POLL_READY:  DB              "PIN-L0-FTDI-POLL-NB-01: READY",13,10,0
MSG_NOINIT_WHAT_CHAR:   DB              "PIN-L0-FTDI-READ-ECHO-01: TYPE CHAR",13,10,0
MSG_NOINIT_READ_FAIL:   DB              "PIN-L0-FTDI-READ-ECHO-01: READ FAIL",13,10,0
MSG_NOINIT_READ_OK:     DB              "PIN-L0-FTDI-READ-ECHO-01: CHAR=",13,10,0

MSG_INIT_CALLED:        DB              13,10,"PIN-L0-FTDI-INIT-01: CALLED",13,10,0
MSG_INIT_POLL_EMPTY:    DB              "PIN-L0-FTDI-POLL-NB-02: EMPTY",13,10,0
MSG_INIT_POLL_READY:    DB              "PIN-L0-FTDI-POLL-NB-02: READY",13,10,0
MSG_INIT_WHAT_CHAR:     DB              "PIN-L0-FTDI-READ-ECHO-02: TYPE CHAR",13,10,0
MSG_INIT_READ_FAIL:     DB              "PIN-L0-FTDI-READ-ECHO-02: READ FAIL",13,10,0
MSG_INIT_READ_OK:       DB              "PIN-L0-FTDI-READ-ECHO-02: CHAR=",13,10,0

MSG_INIT_NOT_ENUMERATED: DB              "PIN-L0-FTDI-ENUM-CHK-01: NOT ENUM",13,10,0
MSG_INIT_ENUMERATED:     DB              "PIN-L0-FTDI-ENUM-CHK-01: ENUM",13,10,0

MSG_DELAY:              DB              "DELAY 3S...",13,10,0
