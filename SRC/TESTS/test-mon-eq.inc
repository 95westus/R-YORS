; ----------------------------------------------------------------------------
; test-mon shared equates:
; - ZP scratch/state map
; - monitor constants used by test-mon.asm
; ----------------------------------------------------------------------------

TMON_ZP_BASE            EQU             $7B60

TMON_UP_LO              EQU             TMON_ZP_BASE+$00
TMON_UP_HI              EQU             TMON_ZP_BASE+$01
TMON_DOWN_LO            EQU             TMON_ZP_BASE+$02
TMON_DOWN_HI            EQU             TMON_ZP_BASE+$03
TMON_KEY                EQU             TMON_ZP_BASE+$04
TMON_UP_DELTA_LO        EQU             TMON_ZP_BASE+$05
TMON_UP_DELTA_HI        EQU             TMON_ZP_BASE+$06
TMON_DOWN_DELTA_LO      EQU             TMON_ZP_BASE+$07
TMON_DOWN_DELTA_HI      EQU             TMON_ZP_BASE+$08
TMON_UP_START_LO        EQU             TMON_ZP_BASE+$09
TMON_UP_START_HI        EQU             TMON_ZP_BASE+$0A
TMON_DOWN_START_LO      EQU             TMON_ZP_BASE+$0B
TMON_DOWN_START_HI      EQU             TMON_ZP_BASE+$0C
TMON_LAST_KEY_UP_LO     EQU             TMON_ZP_BASE+$0D
TMON_LAST_KEY_UP_HI     EQU             TMON_ZP_BASE+$0E
TMON_KEY_SPIN_LO        EQU             TMON_ZP_BASE+$0F
TMON_KEY_SPIN_HI        EQU             TMON_ZP_BASE+$10

TMON_SPIN_DELAY_A       EQU             $01
TMON_SPIN_DELAY_X       EQU             $01
TMON_SPIN_DELAY_Y       EQU             $E1
; ~10.0 s per 65536 spins (with current loop overhead)

TMON_LIVE_CADENCE_MASK  EQU             $03
TMON_BRK_EXIT_CODE      EQU             $65

TMON_CH_CTRL_C          EQU             $03
TMON_CH_CR              EQU             $0D
TMON_CH_LF              EQU             $0A
TMON_CH_BS              EQU             $08
TMON_CH_ESC             EQU             $1B
TMON_CH_DEL             EQU             $7F
TMON_ASCII_SPACE        EQU             $20