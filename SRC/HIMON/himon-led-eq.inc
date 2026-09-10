; ----------------------------------------------------------------------------
; HIMON PIA LED status contract.
;
; Values match the STR8-N v1.32 display vocabulary.  HIMON applies them only
; at its private console/service veneers; raw BIO_FTDI entry points remain
; LED-neutral for programs that own Port A.
; ----------------------------------------------------------------------------

HIM_LED_PIA_PORTA              EQU             $7FA0
HIM_LED_FLAG_HOST              EQU             $02

HIM_LED_STATUS_NO_HOST_WAIT    EQU             $21
HIM_LED_STATUS_HOST_INPUT_WAIT EQU             $43
HIM_LED_STATUS_RX_ACTIVITY     EQU             $07
HIM_LED_STATUS_TX_ACTIVITY     EQU             $0B
