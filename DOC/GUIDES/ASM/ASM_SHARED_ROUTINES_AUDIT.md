# ASM Shared Routine Audit

Date: 2026-06-10

Purpose: identify ASM-private helper routines that overlap with HIMON/ROM
resident routines and decide which ones are good RJOIN/RREC candidates for the
`L F` / `$8000` ASM direction.

## Summary

ASM is already using the most important resident services through RJOIN:

```text
THE_JOIN_EXEC_XY              HIMON-published join seed at $7E00/$7E01
BIO_FTDI_WRITE_BYTE_BLOCK     blocking byte output
SYS_READ_CSTRING_ECHO_UPPER   paste/interactive line input
FNV1A_INIT                    shared FNV hash init
FNV1A_UPDATE_A_FAST           shared FNV byte update
```

The first small shared-helper conversion is now done:

```text
ASM_HEX_TO_NIBBLE -> UTL_HEX_ASCII_TO_NIBBLE
```

`ASM_HEX_TO_NIBBLE` used to be a private 41-byte mirror of the promoted utility.
ASM now resolves hash `$ADD714B1` during `ASM_RJOIN_INIT`, caches the resident
entry, and leaves `ASM_HEX_TO_NIBBLE` as a 3-byte indirect jump. HIMON does not
need a duplicate catalog row: `UTL_HEX_ASCII_TO_NIBBLE_FNV` is linked resident
by `HIM_FNV_FORCE_RESIDENT`, and its raw EXEC record points directly at the
callable entry.

## Already Shared

| ASM use | Resident routine | Status |
| --- | --- | --- |
| RJOIN seed | `THE_JOIN_EXEC_XY` | mandatory and hardware-proven via `$7E00/$7E01` |
| Byte output | `BIO_FTDI_WRITE_BYTE_BLOCK` | ASM resolves at startup |
| Line input | `SYS_READ_CSTRING_ECHO_UPPER` | ASM paste wrapper resolves when needed |
| Hash init | `FNV1A_INIT` | ASM resolves at startup |
| Hash update | `FNV1A_UPDATE_A_FAST` | ASM resolves at startup |
| Hex ASCII parser | `UTL_HEX_ASCII_TO_NIBBLE` | ASM resolves at startup |

## Completed Candidate

### `ASM_HEX_TO_NIBBLE`

Current ASM wrapper:

```text
ASM_HEX_TO_NIBBLE:
    JMP (ASM_RJ_HEX_NIB_LO)
```

Former private routine:

```text
$277A-$27A2 = 41 bytes in the older asm-v1-core.lst
```

Current resolved resident target:

```text
UTL_HEX_ASCII_TO_NIBBLE
hash32: $ADD714B1
contract: A=ASCII hex; valid C=1,A=0..15; invalid C=0,A unchanged
source: SRC/LIB/util/util-hex.asm
```

Why it is safe:

```text
same contract
no ZP use
no fixed RAM
no stack
not an ultra-hot output loop
```

What is needed before converting ASM:

```text
done: HIMON links UTL_HEX_ASCII_TO_NIBBLE_FNV resident as K05
done: ASM_RJ_HEX_NIB_LO/HI cache slot
done: ASM_HASH_UTL_HEX_ASCII_TO_NIBBLE = B1 14 D7 AD
done: ASM_HEX_TO_NIBBLE wrapper
done: board paste proof on HIMON V 00.0610(1937), ASM load OK=$3EED
```

Expected size result:

```text
Gross ASM private-code delete: 41-byte body -> 3-byte wrapper.
Net ASM win is small after adding the required startup lookup, cache bytes, and
hash constant, but it moves the parser onto the resident-routine contract needed
for the $8000/no-header direction.
```

## K05 Text Batch

The selected K01 records now carry short K05 EXEC+TEXT names:

```text
BIO_FTDI_READ_BYTE_BLOCK        READ BYTE
BIO_FTDI_WRITE_BYTE_BLOCK       WRITE BYTE
SYS_READ_CHAR                   READ CH
SYS_READ_CHAR_ECHO              READ ECHO
SYS_READ_CHAR_COOKED_ECHO       READ COOK
UTL_HEX_NIBBLE_TO_ASCII         NIB HEX
UTL_HEX_BYTE_TO_ASCII_YX        BYTE HEX
UTL_HEX_ASCII_TO_NIBBLE         HEX NIB
UTL_HEX_ASCII_YX_TO_BYTE        HEX BYTE
```

Current software build result:

```text
HIMON V 00.0610(2012)
HIMON total: $2F88
ASM runtime-paste total: $3F1F

BIO_FTDI_READ_BYTE_BLOCK_FNV      $E2DC entry=$E2E8 text=$E2EE
BIO_FTDI_WRITE_BYTE_BLOCK_FNV     $E2FB entry=$E307 text=$E30F
SYS_READ_CHAR_FNV                 $E4B5 entry=$E4C1 text=$E4C5
SYS_READ_CHAR_ECHO_FNV            $E4CC entry=$E4D8 text=$E4EC
SYS_READ_CHAR_COOKED_ECHO_FNV     $E4DC entry=$E4E8 text=$E4F5
UTL_HEX_ASCII_TO_NIBBLE_FNV       $E5B7 entry=$E5C3 text=$E5EC
UTL_HEX_BYTE_TO_ASCII_YX_FNV      $E7FC entry=$E808 text=$E81A
UTL_HEX_NIBBLE_TO_ASCII_FNV       $E822 entry=$E82E text=$E83A
```

`UTL_HEX_ASCII_YX_TO_BYTE_FNV` is K05 in source, but is not currently forced
resident in the active HIMON image.

Board proof: `# K=5` confirmed `READ BYTE`, `WRITE BYTE`, `READ CH`,
`READ ECHO`, `READ COOK`, `HEX NIB`, `BYTE HEX`, and `NIB HEX` as active K05
resident text rows.

## Output Helper Candidates

ASM currently carries these output helpers after resolving only the byte writer:

```text
ASM_RJ_WRITE_CSTRING    about 22 bytes
ASM_RJ_WRITE_HEX_BYTE   about 32 bytes including nibble helper
ASM_RJ_PRINT_CRLF       about 10 bytes
```

Resident-adjacent targets:

```text
BIO_FTDI_PUT_CSTR       already HIMON-published as EXEC+TEXT, points to SYS_WRITE_CSTRING
SYS_WRITE_HEX_BYTE      catalogued, but not currently HIMON-published for RJOIN
SYS_WRITE_CRLF          catalogued, but not currently HIMON-published for RJOIN
BIO_WRITE_HEX_BYTE      catalogued, but not currently HIMON-published for RJOIN
BIO_WRITE_CRLF          catalogued, but not currently HIMON-published for RJOIN
```

Recommendation:

```text
Do not convert these one at a time yet.
```

Reason:

```text
The private routines are small. Each new resident call needs a hash constant,
a cached vector, and RJOIN init code. The byte savings only become interesting
if we publish/acquire a small output group together or if ASM moves to flash and
we accept more mandatory resident services.
```

Most reasonable output-sharing experiment:

```text
Resolve BIO_FTDI_PUT_CSTR for ASM internal C-string printing.
Measure runtime paste size before/after.
Keep ASM_RJ_WRITE_BYTE for single-character output.
```

## Keep Private For Now

These overlap conceptually with utility routines but should stay private in the
current RAM/runtime slice:

```text
ASM_SKIP_SPACES
ASM_ADV_PARSE
ASM_IS_TOKEN_DELIM
ASM_IS_PUNCT
ASM_IS_WORD_HEAD
ASM_IS_WORD_BODY
ASM_IS_ALPHA
ASM_IS_DIGIT
ASM_FOLD_UPPER_A
ASM_VALUE_SHL4
ASM_BIN_SHIFT
ASM_VALUE_MUL10_ADD_TMP0
```

Reasons:

```text
lexer/parser hot path
ASM-specific punctuation and delimiter rules
ASM-specific parse pointer state
tiny routines where RJOIN overhead likely loses
some utility catalog entries are still NEEDS_PROOF
```

`ASM_FOLD_UPPER_A` maps conceptually to `UTL_CHAR_TO_UPPER`, and
`ASM_IS_DIGIT` / `ASM_IS_ALPHA` map to `UTL_CHAR_IS_DIGIT` /
`UTL_CHAR_IS_ALPHA`, but these are called repeatedly while tokenizing source.
Keeping them local is the safer choice until ASM is flash-resident and size is
more important than local lexer speed.

## Final ASM/HIMON Similarity Scan

Scope: `SRC/ASM/asm-v1-core.asm`, HIMON monitor sources, and resident HIMON
library routines. STR8 is deliberately out of scope.

Result:

```text
No more safe one-off shrink remains before the flash/RAM split.
The only attractive remaining shared family is output, and it should be moved
as a group rather than as separate tiny calls.
```

Already shared or resolved:

| ASM routine/use | HIMON/resident routine | Verdict |
| --- | --- | --- |
| `ASM_RJ_WRITE_BYTE` | `BIO_FTDI_WRITE_BYTE_BLOCK` / `WRITE BYTE` | done |
| `ASM_RJ_READ_CSTRING` | `SYS_READ_CSTRING_ECHO_UPPER` / `READ LINE` | done |
| `ASM_HEX_TO_NIBBLE` | `UTL_HEX_ASCII_TO_NIBBLE` / `HEX NIB` | done |
| `ASM_FNV1A_INIT` | `FNV1A_INIT` / `HASH OPEN` | done |
| `ASM_FNV1A_UPDATE_A_FAST` | `FNV1A_UPDATE_A_FAST` / `HASH MIX` | done |

Remaining output overlaps:

| ASM routine | Similar HIMON/resident routine | Recommendation |
| --- | --- | --- |
| `ASM_RJ_WRITE_CSTRING` | `BIO_FTDI_PUT_CSTR` / `SYS_WRITE_CSTRING` | candidate after flash split |
| `ASM_RJ_WRITE_HEX_BYTE` | `SYS_WRITE_HEX_BYTE`, `BIO_WRITE_HEX_BYTE`, `UTL_HEX_BYTE_TO_ASCII_YX` | group with output work only |
| `ASM_RJ_PRINT_CRLF` | `SYS_WRITE_CRLF`, `BIO_WRITE_CRLF` | group with output work only |

Why not now:

```text
ASM_RJ_WRITE_CSTRING is about 22 bytes.
ASM_RJ_WRITE_HEX_BYTE is about 32 bytes.
ASM_RJ_PRINT_CRLF is about 10 bytes.

Each extra resident call wants a hash constant, cache bytes, and init checks.
One at a time, the plumbing can eat the win. As a group, especially once ASM is
flash-resident, the policy is cleaner.
```

Similar but not good sharing targets:

| ASM family | HIMON/resident similarity | Why it stays private |
| --- | --- | --- |
| `ASM_SKIP_SPACES`, `ASM_ADV_PARSE` | `CMD_SKIP_SPACES`, `CMD_ADV_PTR` | same shape, different pointer state |
| `ASM_NEXT_TOKEN`, `ASM_LOOKUP_WORD` | `CMD_HASH_TOKEN`, command scanner | ASM token rules are richer and syntax-specific |
| `ASM_IS_*`, `ASM_FOLD_UPPER_A` | `UTL_CHAR_*` | hot path, punctuation rules differ, utility helpers may use shared ZP |
| `ASM_PARSE_*`, `ASM_VALUE_*` | `CMD_PARSE_HEX_*` | ASM expressions handle radix, width, symbols, locals, and fixups |
| symbol/fixup/local tables | HIMON hash/catalog scanner | ASM-specific session metadata |
| opcode/vocabulary lookup | HIMON disassembler/opcode helpers | inverse problem, different tables and contracts |

Final recommendation:

```text
Do the flash/RAM split next.
After that, consider one output-sharing experiment:
  resolve PUT CSTR, WRITE HEX BYTE, and CRLF together
  measure size and complexity as a group
Leave lexer/parser/number code private unless a new resident parser contract is
designed explicitly for ASM, not borrowed from HIMON command parsing.
```

## Completed Slice

```text
Goal: convert ASM_HEX_TO_NIBBLE to a resident RJOIN call.

HIMON:
  confirmed UTL_HEX_ASCII_TO_NIBBLE_FNV in the active resident scan
  current map: UTL_HEX_ASCII_TO_NIBBLE_FNV=$E5B7, entry=$E5C3, text=$E5EC
  current S19 record bytes include 46 4E D6 B1 14 D7 AD 05

ASM:
  added ASM_RJ_HEX_NIB_LO/HI cache
  resolves hash $ADD714B1 during ASM_RJOIN_INIT
  replaced ASM_HEX_TO_NIBBLE with JMP (ASM_RJ_HEX_NIB_LO)

Tests:
  passed: make -C SRC asm-test
  passed: make -C SRC himon
  passed board: paste a short sample using $ hex operands and DB $xx
  passed board: LDA #$1234 reports ERR=$06 BAD RANGE
```
