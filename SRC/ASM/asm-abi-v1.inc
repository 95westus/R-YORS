; ----------------------------------------------------------------------------
; ASM ABI v1
;
; Public binary constants shared by ASM-F2 and HIMON.  Changing any value in
; this file requires a new ASM ABI version and a compatibility decision.
; Private routine addresses, ASM zero page, and ASM UDATA are not ABI.
; ----------------------------------------------------------------------------

ASM_ABI_VERSION             EQU             $01

; HIMON resident service-vector block.
ASM_ABI_SVC_SIG0            EQU             $7E02
ASM_ABI_SVC_SIG1            EQU             $7E03
ASM_ABI_SVC_VERSION         EQU             $7E04
ASM_ABI_SVC_COUNT           EQU             $7E05
ASM_ABI_SVC_FIRST_VECTOR    EQU             $7E06
ASM_ABI_SVC_CHECKSUM        EQU             $7E1C
ASM_ABI_SVC_SIG0_VALUE      EQU             'R'
ASM_ABI_SVC_SIG1_VALUE      EQU             'Y'
ASM_ABI_SVC_VERSION_VALUE   EQU             $01
ASM_ABI_SVC_VECTOR_COUNT    EQU             $0B

; Optional published service extensions used by ASM.
ASM_ABI_PACK40_ASCII        EQU             $7E1F
ASM_ABI_PACK40_PACK3        EQU             $7E21
ASM_ABI_AP_IMPORT_PTR       EQU             $7E23
ASM_ABI_FLASH_INSTALL       EQU             $7E25
ASM_ABI_AP_SERVICE          EQU             $7E2D

; HIMON AP request/result card, $7E2F-$7E40 inclusive.
ASM_ABI_AP_OP               EQU             $7E2F
ASM_ABI_AP_STATUS           EQU             $7E30
ASM_ABI_AP_SRC              EQU             $7E31
ASM_ABI_AP_DST              EQU             $7E33
ASM_ABI_AP_PACKAGE_LEN      EQU             $7E35
ASM_ABI_AP_BODY             EQU             $7E37
ASM_ABI_AP_BODY_LEN         EQU             $7E39
ASM_ABI_AP_RELOC_COUNT      EQU             $7E3B
ASM_ABI_AP_IMPORT_COUNT     EQU             $7E3C
ASM_ABI_AP_INSTALL          EQU             $7E3D
ASM_ABI_AP_RELOC_PTR        EQU             $7E3F
ASM_ABI_AP_OP_PARSE         EQU             $00
ASM_ABI_AP_OP_LOAD          EQU             $01
ASM_ABI_AP_OP_SUGGEST       EQU             $02
ASM_ABI_AP_OP_LINK          EQU             $03

; Shared status values returned in A and stored in ASM_ABI_AP_STATUS.
ASM_ABI_STATUS_OK           EQU             $00
ASM_ABI_STATUS_BAD_RANGE    EQU             $06
ASM_ABI_STATUS_BAD_LINE     EQU             $07
ASM_ABI_STATUS_BAD_FIX      EQU             $09

; AP v2 serialized package envelope.
ASM_ABI_AP_SIG0_VALUE       EQU             'A'
ASM_ABI_AP_SIG1_VALUE       EQU             'P'
ASM_ABI_AP_VERSION          EQU             $02
ASM_ABI_AP_HEADER_BYTES     EQU             $05
ASM_ABI_AP_FIXED_BYTES      EQU             $1F
ASM_ABI_AP_MAX_BYTES        EQU             $1000
ASM_ABI_AP_TAG_SEAL         EQU             'S'
ASM_ABI_AP_TAG_RELOC        EQU             'R'
ASM_ABI_AP_TAG_EXPORT       EQU             'E'
ASM_ABI_AP_TAG_IMPORT       EQU             'I'
ASM_ABI_AP_TAG_BODY         EQU             'B'
ASM_ABI_AP_SEAL_BYTES       EQU             $0B
ASM_ABI_AP_ROW_MAX          EQU             $40
ASM_ABI_AP_KIND_EXEC        EQU             $01
ASM_ABI_AP_KIND_DATA        EQU             $02
ASM_ABI_AP_FLAG_ENTRY       EQU             $80
ASM_ABI_AP_RELOC_ABS16      EQU             $01
ASM_ABI_AP_RELOC_LO8        EQU             $02
ASM_ABI_AP_RELOC_HI8        EQU             $03
ASM_ABI_AP_RELOC_ABS16_IMP  EQU             $04
ASM_ABI_AP_RELOC_LO8_IMP    EQU             $05
ASM_ABI_AP_RELOC_HI8_IMP    EQU             $06
