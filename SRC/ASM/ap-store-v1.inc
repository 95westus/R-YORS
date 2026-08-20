; ----------------------------------------------------------------------------
; AP Store V1 candidate on-media constants.
; Host-frozen before firmware implementation. This storage container carries
; unchanged AP v2 envelopes; it is not part of ASM ABI v1.
; ----------------------------------------------------------------------------

APS_SECTOR_BYTES            EQU             $1000
APS_SECTOR_HEADER_BYTES     EQU             $0010
APS_SECTOR_SIG0             EQU             'A'
APS_SECTOR_SIG1             EQU             'S'
APS_SECTOR_SIG2             EQU             '1'
APS_SECTOR_STATE_STAGED     EQU             $FF
APS_SECTOR_STATE_ACTIVE     EQU             $FE
APS_SECTOR_STATE_RETIRED    EQU             $FC
APS_SECTOR_STATE_BAD        EQU             $FA
APS_SECTOR_STATE_RETIRED_BAD EQU            $F8

APS_RECORD_HEADER_BYTES     EQU             $0014
APS_RECORD_TRAILER_BYTES    EQU             $0001
APS_RECORD_SIG0             EQU             'A'
APS_RECORD_SIG1             EQU             'R'
APS_RECORD_VERSION          EQU             $01
APS_RECORD_CHUNK            EQU             $01
APS_RECORD_TOMBSTONE        EQU             $02
APS_RECORD_FLAG_FIRST       EQU             $01
APS_RECORD_FLAG_LAST        EQU             $02
APS_RECORD_COMMIT           EQU             $A5
APS_OBJECT_MAX_CHUNKS       EQU             $08

; Sector header offsets (16 bytes).
APS_SH_OFF_SIG              EQU             $00
APS_SH_OFF_LOCATION         EQU             $03
APS_SH_OFF_GENERATION       EQU             $04
APS_SH_OFF_FNV              EQU             $06
APS_SH_OFF_RESERVED         EQU             $0A
APS_SH_OFF_STATE            EQU             $0F

; Record header offsets (20 bytes), followed by payload and one commit byte.
APS_RH_OFF_SIG              EQU             $00
APS_RH_OFF_VERSION          EQU             $02
APS_RH_OFF_TYPE             EQU             $03
APS_RH_OFF_FLAGS            EQU             $04
APS_RH_OFF_RESERVED         EQU             $05
APS_RH_OFF_OBJECT           EQU             $06
APS_RH_OFF_GENERATION       EQU             $08
APS_RH_OFF_LOGICAL          EQU             $0A
APS_RH_OFF_LENGTH           EQU             $0C
APS_RH_OFF_FNV              EQU             $0E
APS_RH_OFF_CRC16            EQU             $12
