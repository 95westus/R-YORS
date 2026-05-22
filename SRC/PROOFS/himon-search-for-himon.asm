; ----------------------------------------------------------------------------
; himon-search-for-himon.asm
; Native HIMON search port scaffold.
;
; This is not a loadable S19 app.  It is the code-side checklist for moving the
; proven low-flash search command into HIMON/himon.asm without
; changing the already-tested search core.
;
; The four search artifacts now have separate jobs:
; - himon-search-static     RAM standalone search, statically linked helpers.
; - himon-search-proof      RAM search using runtime-discovered helpers.
; - himon-search-flash      Low-flash K=$05 FNV command delivered by L F.
; - himon-search-for-himon  This native port scaffold for HIMON proper.
; ----------------------------------------------------------------------------

                        MODULE          HIMON_SEARCH_FOR_HIMON_APP

; ----------------------------------------------------------------------------
; Record to add near the resident HIMON command FNV records.
; ----------------------------------------------------------------------------
; CMD_SEARCH_FNV:
;                         DB              'F','N',CMD_FNV_SIG2,$22,$13,$0C,$D6,CMD_HASH_KIND_EXEC_TEXT
;                         DW              CMD_SEARCH
;                         DW              MSG_SEARCH_EXTRA
;
; Hash/token:
;   S             -> $D60C1322
;   kind $05      -> executable + display text, no confirm-before-run
;   extra text    -> MSG_SEARCH_EXTRA, high-bit-terminated "S(earch)"
;
; Important: HIMON scans FNV records from $8000 upward.  A low-flash S record at
; $BBA2 will win before a native S record inside HIMON at $C000+.  Native board
; tests must erase/avoid the flash-shadow record or use a bank without it.

; ----------------------------------------------------------------------------
; Entry shape to fold into himon.asm.
; ----------------------------------------------------------------------------
; CMD_SEARCH:
;                         LDA             CMDP_START_LO
;                         STA             SEARCH_LINE_LO
;                         LDA             CMDP_START_HI
;                         STA             SEARCH_LINE_HI
;                         JSR             SEARCH_SKIP_SPACES
;                         JSR             SEARCH_PEEK
;                         BEQ             CMD_SEARCH_USAGE
;                         JSR             SEARCH_ADV_LINE       ; skip S token
;                         JSR             SEARCH_PARSE_RANGE
;                         BCC             CMD_SEARCH_USAGE
;                         JSR             SEARCH_PARSE_PATTERN
;                         BCC             CMD_SEARCH_USAGE
;                         JMP             SEARCH_SCAN_RANGE
;
; Do not depend on $FE/$FF on entry.  Display/confirm/hash work may already have
; used that pointer.  Start from CMDP_START ($FA/$FB), just like the flash proof
; now does.

; ----------------------------------------------------------------------------
; Keep these routines from himon-search-flash.asm.
; ----------------------------------------------------------------------------
; SEARCH_PARSE_RANGE       range parser, including +count
; SEARCH_PARSE_PATTERN     hex-byte and apostrophe-text pattern atoms
; SEARCH_APPEND_A          fixed pattern-buffer append
; SEARCH_PARSE_HEX_WORD    four-hex-digit parser
; SEARCH_SKIP_SPACES
; SEARCH_PEEK
; SEARCH_ADV_LINE
; SEARCH_SCAN_RANGE        main scan loop
; SEARCH_SCAN_GT_END
; SEARCH_MATCH_GT_END
; SEARCH_MATCH_AT
; SEARCH_PRINT_HIT
; SEARCH_PRINT_ROW_ADDR
; SEARCH_PRINT_ROW_BYTES
;
; Keep the routines split.  The current proof works because each leaf has one
; small job; do not hide the scan loop behind a larger framework during the
; first native port.

; ----------------------------------------------------------------------------
; Delete these flash-only pieces when search becomes native.
; ----------------------------------------------------------------------------
; SEARCH_FNV
; START / START_HAVE_WRITE / START_IMPORTS_OK names, after renaming to CMD_SEARCH
; SEARCH_RESOLVE_WRITE
; SEARCH_RESOLVE_IMPORTS
; SEARCH_RESOLVE_CTRL_C
; SEARCH_RESOLVE_HEX_IN
; SEARCH_FIND_HASH_XY
; SEARCH_FIND_* scanner helpers
; SEARCH_BIO_WRITE_BYTE_BLOCK trampoline
; SEARCH_BIO_GET_CTRL_C trampoline
; SEARCH_UTL_HEX_ASCII_TO_NIBBLE trampoline
; SEARCH_SYS_PRINT_IO_SLOT_SKIP trampoline
; HASH_BIO_WRITE_BYTE_BLOCK
; HASH_BIO_GET_CTRL_C
; HASH_UTL_HEX_ASCII_TO_NIBBLE
; HASH_SYS_PRINT_IO_SLOT_SKIP
; SEARCH_EXTRA, after replacing it with MSG_SEARCH_EXTRA

; ----------------------------------------------------------------------------
; Direct native calls.
; ----------------------------------------------------------------------------
; flash helper name                  native HIMON call
; -----------------                  -----------------
; SEARCH_BIO_WRITE_BYTE_BLOCK        BIO_FTDI_WRITE_BYTE_BLOCK
; SEARCH_BIO_GET_CTRL_C              HIM_CHECK_CTRL_C
; SEARCH_UTL_HEX_ASCII_TO_NIBBLE     CMD_HEX_ASCII_TO_NIBBLE
; SEARCH_SYS_PRINT_IO_SLOT_SKIP      SYS_PRINT_IO_SLOT_SKIP
; SEARCH_WRITE_HEX_BYTE              SYS_WRITE_HEX_BYTE
; SEARCH_WRITE_CRLF                  SYS_WRITE_CRLF
; SEARCH_PRINT_LINE                  HIM_WRITE_HBSTRING + SYS_WRITE_CRLF

; ----------------------------------------------------------------------------
; Native scratch proposal.
; ----------------------------------------------------------------------------
; $B4 SEARCH_LINE_LO
; $B5 SEARCH_LINE_HI
; $B6 SEARCH_WORD_LO
; $B7 SEARCH_WORD_HI
; $B8 SEARCH_START_LO
; $B9 SEARCH_START_HI
; $BA SEARCH_END_LO
; $BB SEARCH_END_HI
; $BC SEARCH_SCAN_LO
; $BD SEARCH_SCAN_HI
; $BE SEARCH_MATCH_LO
; $BF SEARCH_MATCH_HI
; $C0 SEARCH_ROW_LO
; $C1 SEARCH_ROW_HI
; $C2 SEARCH_TMP
; $C3 SEARCH_DIGITS
; $C4 SEARCH_PAT_LEN
; $C5 SEARCH_COUNT
; $C6 SEARCH_HIT_FLAG
; $C7-$CA spare/reserved
;
; Leave $B0-$B3 alone for current hash display/filter scratch.  Keep the pattern
; buffer at $7900 for the first native pass so the search core does not change.
;
; This is a static workspace reservation, not a runtime allocator.  Native
; HIMON search should claim fixed named bytes, document that they are volatile
; during CMD_SEARCH, and let the source/map be the allocation record.  If later
; runtime-loaded routines need scratch, make that a header/linker contract
; rather than adding a zero-page heap for this command.

; ----------------------------------------------------------------------------
; Messages to convert from zero-terminated flash strings to HIMON high-bit
; strings.
; ----------------------------------------------------------------------------
; MSG_SEARCH_USAGE:      DB "S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUI",('T'+$80)
; MSG_SEARCH_NF:         DB "S N",('F'+$80)
; MSG_SEARCH_ABORT:      DB "S ABOR",('T'+$80)
; MSG_SEARCH_EXTRA:      DB "S(earch",(')'+$80)
;
; Delete the flash import message in native HIMON; there are no runtime imports.

; ----------------------------------------------------------------------------
; Native test pass.
; ----------------------------------------------------------------------------
; make -C SRC himon
; install/run the new HIMON image
; ensure the low-flash S record is absent or erased
;
; ># S
;     expect: D60C1322 ENTRY=<native> K=05  S(earch)
; >S 7F06 +27 00
;     expect: named IO SKIP rows, then S NF
; >S 0 FFFF 'HIMON'
;     expect: RAM/current-line hits, named IO SKIP rows, ROM hits
; >S 3000 +100 'NOTTHERE'
;     expect: S NF
; >D 7EF0 800F
;     expect: D still prints the same named IO SKIP rows

                        ENDMOD
                        END
