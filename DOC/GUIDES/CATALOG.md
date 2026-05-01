# R-YORS Catalog

This is the programmer-facing catalog for callable routines. It answers:

```text
I need to read something. What routine do I call?
I need to write a C string. What are the registers and flags?
I need a BIO-level helper for STR8. What is small enough to trust?
```

For the full generated dump, see `SRC/ROUTINE_CONTRACTS.md`. This guide keeps
the high-value callable surface grouped by need, with an S/36-ish bias toward
"what does the system have, and how do I call it?"

## How To Choose

```text
SYS_*    normal monitor/app API; device-neutral; easiest to call
BIO_*    recovery-safe low-level API; STR8 should prefer this
COR_*    backend implementation layer; use when building SYS or tests
PIN_*    direct hardware/pin layer; use for bring-up or BIO implementation
UTL_*    pure utility/helper routines
FLASH_*  flash guard, erase, and byte-program routines
FNV1A_*  hash helpers for command/catalog/symbol lookup
MON_*    monitor command/support internals
```

Rule of thumb: application and monitor code should start at `SYS_*`. STR8 and
early recovery code should start at `BIO_*`. Only drop to `COR_*` or `PIN_*`
when the higher layer does not exist or would pull too much code.

## Field Shape

```text
routine   callable name
hash      32-bit FNV-1a over canonical routine text
class     layer and broad type
in        entry registers/state
out       exit registers/state and carry contract
proof     current confidence/proof state
notes     practical use, caveat, or future alias direction
tags      compact semantic search tokens
```

## Proof Status

Proof status is intentionally conservative. A release build proves that the
routine assembles and links; it does not prove behavior on hardware.

```text
PROVEN        documented pass/frozen evidence exists for the callable behavior
WRAPS_PROVEN  thin wrapper over a proven lower routine; wrapper still wants
              its own final recovery test before being treated as STR8-frozen
PARTIAL       some path or harness evidence exists, but important cases remain
BUILDS        current release/build includes it; behavior proof not captured
NEEDS_PROOF   callable shape is documented, but proof evidence is still needed
DESIGN        planned/future catalog surface, not a concrete current proof item
```

Current captured proof evidence:

```text
PIN_FTDI_*     PROVEN/TOP-SHELF from documented test-ftdi-drv.asm pass notes.
BIO_FTDI_*     mixed: direct pass-through wrappers can WRAP proven PIN paths;
               timeout/drain/flush paths have partial harness evidence.
FLASH_*        partial harness exists; STR8-grade flash proof still needs a
               board/protection/bank matrix.
SYS_*/COR_*/UTL_* behavior proof is not assumed just because release builds.
```

## Type, Class, Form, Function

Read each row this way:

```text
type      prefix/layer: SYS, BIO, COR, PIN, UTL, FLASH, FNV1A, MON
class     broad job: READ, WRITE, STRING, HEX, HASH, FLASH, VECTOR
form      shape of use: CHAR, BYTE, CSTR, HBSTR, BLOCKING, TIMEOUT, RAW
function  concrete reason to call it
```

Examples:

```text
SYS WRITE CSTR     -> normal app/monitor NUL-string writer
BIO WRITE BYTE     -> recovery-safe byte writer, current concrete FTDI form
UTL HEX PARSE BYTE -> pure conversion helper, no I/O side effect
FLASH BYTE PROGRAM -> guarded flash byte writer
```

## Read And Input

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SYS_READ_CHAR` | `$43621C9C` | SYS read char | none | `A=byte`, `C=1` | NEEDS_PROOF | normal blocking byte/char read | `SYS READ CHAR CARRY_STATUS` |
| `SYS_POLL_CHAR` | `$D346E667` | SYS readiness | none | `C=1` byte available, `C=0` none | NEEDS_PROOF | non-consuming readiness check | `SYS POLL READ NONBLOCKING` |
| `SYS_GET_CTRL_C` | `$BEB18931` | SYS control | none | `C=1`, `A=$03` if Ctrl-C consumed | NEEDS_PROOF | nonblocking abort/key check | `SYS CTRL_C NONBLOCKING` |
| `SYS_READ_CHAR_SPINCOUNT` | `$13947FC4` | SYS read timed info | none | `C=1`, `A=byte`, `X/Y=elapsed slices` | NEEDS_PROOF | read with timing feedback | `SYS READ SPINCOUNT` |
| `SYS_READ_CHAR_TIMEOUT_SPINDOWN` | `$03FBED1D` | SYS timed read | `A=timeout slices` | success: `C=1`, `A=byte`, `X=slices left` | NEEDS_PROOF | visible bounded wait | `SYS READ TIMEOUT SPINDOWN` |
| `SYS_READ_CHAR_ECHO` | `$F91947F8` | SYS cooked char | none | backend cooked-char `A/C` | NEEDS_PROOF | short alias for cooked echoed char input | `SYS READ ECHO COOKED` |
| `SYS_READ_CHAR_COOKED_ECHO` | `$B85E3F10` | SYS cooked char | none | backend cooked-char `A/C` | NEEDS_PROOF | echo/normalize single character | `SYS READ ECHO COOKED` |
| `BIO_FTDI_READ_BYTE_BLOCK` | `$20285B85` | BIO read byte | none | `C=1`, `A=byte` | PARTIAL | STR8-friendly blocking FTDI byte read | `BIO FTDI READ BYTE BLOCKING` |
| `BIO_FTDI_READ_BYTE_NONBLOCK` | `$6A5E3370` | BIO read byte | none | `C=1,A=byte` ready; `C=0,A=0` none | WRAPS_PROVEN | smallest FTDI receive probe | `BIO FTDI READ BYTE NONBLOCKING` |
| `BIO_FTDI_READ_BYTE_TMO` | `$83426F30` | BIO timed read | none | bounded receive result | PARTIAL | retrying nonblocking read; no-data path has test harness evidence | `BIO FTDI READ TIMEOUT` |
| `BIO_FTDI_POLL_RX_READY` | `$3BD83670` | BIO readiness | none | `C=1` ready, `C=0` not ready | WRAPS_PROVEN | readiness alias over proven PIN poll | `BIO FTDI POLL RX` |
| `BIO_FTDI_GET_CTRL_C` | `$426150D2` | BIO control | none | `C=1,A=$03` if Ctrl-C consumed | NEEDS_PROOF | recovery-level abort check | `BIO FTDI CTRL_C NONBLOCKING` |

## Line And String Input

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SYS_READ_CSTRING` | `$EFF54394` | SYS CSTR read | `X/Y=dest` | backend line-reader `A/C` | NEEDS_PROOF | cooked line input into NUL-terminated buffer | `SYS READ CSTRING COOKED` |
| `SYS_READ_CSTRING_MODE` | `$584E5FAE` | SYS CSTR read | `A=mode`, `X/Y=dest` | backend line-reader `A/C` | NEEDS_PROOF | mode bits: echo, uppercase, lowercase | `SYS READ CSTRING MODE` |
| `SYS_READ_CSTRING_EDIT_MODE` | `$A49D7915` | SYS editable CSTR | `A=mode`, `X/Y=dest` | edit-line `A/C` | NEEDS_PROOF | insert/delete/cursor capable path | `SYS READ CSTRING EDIT` |
| `SYS_READ_CSTRING_EDIT_ECHO_UPPER` | `$B3A76D2C` | SYS editable CSTR | `X/Y=dest` | edit-line `A/C` | NEEDS_PROOF | convenience wrapper: echo and uppercase | `SYS READ CSTRING EDIT ECHO UPPER` |
| `SYS_READ_CSTRING_SILENT` | `$98B68980` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | cooked no-echo input | `SYS READ CSTRING SILENT` |
| `SYS_READ_CSTRING_ECHO_UPPER` | `$E2DD10AF` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | echo and uppercase | `SYS READ CSTRING ECHO UPPER` |
| `SYS_READ_CSTRING_ECHO_LOWER` | `$A05843C2` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | echo and lowercase | `SYS READ CSTRING ECHO LOWER` |
| `SYS_READ_CSTRING_SILENT_UPPER` | `$C9364C7F` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | silent uppercase | `SYS READ CSTRING SILENT UPPER` |
| `SYS_READ_CSTRING_SILENT_LOWER` | `$43D98ED2` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | silent lowercase | `SYS READ CSTRING SILENT LOWER` |
| `SYS_RD_CSTR_CCE / SYS_RD_HBSTR_CCE` | `$C16F1AEC` | SYS CSTR/HBSTR read | `X/Y=dest` | `C=1,A=len` on CR/LF; `C=0,A=$03` on Ctrl-C | NEEDS_PROOF | current compact Ctrl-C echo line input; split headers later if aliases need separate hashes | `SYS READ CSTRING HBSTRING ECHO CTRL_C` |

## Write And Output

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SYS_WRITE_CHAR` | `$49023C1B` | SYS write char | `A=byte` | `C=1` success | NEEDS_PROOF | normal device-neutral byte/char write | `SYS WRITE CHAR CARRY_STATUS` |
| `SYS_WRITE_CHAR_REPEAT` | `$CCB058E3` | SYS write repeat | `A=byte`, `X=count` | `C=1`, `A` preserved | NEEDS_PROOF | repeated fill/output character | `SYS WRITE REPEAT PRESERVE_A` |
| `SYS_WRITE_CHAR_PLUS_CRLF` | `$A06A074A` | SYS write char+line | `A=byte` | `C=1` full success, `C=0` failure | NEEDS_PROOF | write payload byte then CRLF | `SYS WRITE CHAR CRLF` |
| `SYS_WRITE_BYTES_AXY` | `$4FDF2021` | SYS write bytes | `A=byte0`, `X=byte1`, `Y=byte2` | `C=1` full success, `C=0` failure | NEEDS_PROOF | explicit three-byte write | `SYS WRITE BYTES AXY` |
| `SYS_WRITE_CSTRING` | `$56C76299` | SYS write CSTR | `X/Y=source` | `A=count`, `C=1` full string, `C=0` truncation | NEEDS_PROOF | NUL-terminated string writer | `SYS WRITE CSTRING NUL_TERM` |
| `SYS_WRITE_HBSTRING` | `$A6D68C34` | SYS write HBSTR | `X/Y=source` | `A=count`, `C=1` full string, `C=0` truncation | NEEDS_PROOF | high-bit-terminated string writer | `SYS WRITE HBSTRING HIBIT_TERM` |
| `SYS_WRITE_HBLINE` | `$3A150F83` | SYS write HB line | `X/Y=source` | `C` follows trailing CRLF | NEEDS_PROOF | HBSTR plus newline | `SYS WRITE HBSTRING CRLF` |
| `SYS_WRITE_LINE_XY` | `$59A0E7C5` | SYS write C line | `X/Y=source` | `C` follows trailing CRLF | NEEDS_PROOF | CSTR plus newline | `SYS WRITE CSTRING CRLF` |
| `SYS_WRITE_HEX_BYTE` | `$A1722743` | SYS write hex | `A=byte` | `C=1`, `A` preserved | NEEDS_PROOF | print `A` as two uppercase hex chars | `SYS WRITE HEX BYTE PRESERVE_A` |
| `SYS_WRITE_CRLF` | `$3F362368` | SYS newline | none | `C=1` success | NEEDS_PROOF | device-neutral CRLF | `SYS WRITE CRLF` |
| `BIO_FTDI_WRITE_BYTE_BLOCK` | `$379FE930` | BIO write byte | `A=byte` | `C=1`, `A` preserved | PARTIAL | STR8-friendly blocking FTDI byte write | `BIO FTDI WRITE BYTE BLOCKING` |
| `BIO_FTDI_WRITE_BYTE_NONBLOCK` | `$8FAE8ABB` | BIO write byte | `A=byte` | `C=1` accepted, `C=0` timeout, `A` preserved | PARTIAL | success path has test harness evidence; timeout path still needs forced blocked-FIFO proof | `BIO FTDI WRITE BYTE NONBLOCKING` |
| `BIO_FTDI_WRITE_BYTE_TMO` | `$DC28D281` | BIO timed write | `A=byte` | bounded transmit result, `A` preserved | NEEDS_PROOF | retrying nonblocking write | `BIO FTDI WRITE TIMEOUT` |
| `BIO_WRITE_HEX_BYTE` | `$CDBB01D2` | BIO write hex | `A=byte` | `C=1`, `A` preserved | NEEDS_PROOF | STR8-friendly hex output | `BIO WRITE HEX BYTE` |
| `BIO_WRITE_CRLF` | `$8C36CC4D` | BIO newline | none | `C=1`, `A` preserved | NEEDS_PROOF | STR8-friendly newline | `BIO WRITE CRLF` |

## Hex And Character Utilities

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `UTL_HEX_NIBBLE_TO_ASCII` | `$D4C88B87` | UTL hex encode | `A=0..15` | `A='0'..'F'`, `C=1` | NEEDS_PROOF | low nibble to ASCII hex | `UTL HEX ENCODE NIBBLE` |
| `UTL_HEX_BYTE_TO_ASCII_YX` | `$7142DD21` | UTL hex encode | `A=byte` | `A` preserved, `Y=hi ASCII`, `X=lo ASCII`, `C=1` | NEEDS_PROOF | byte to two hex chars | `UTL HEX ENCODE BYTE` |
| `UTL_HEX_ASCII_TO_NIBBLE` | `$ADD714B1` | UTL hex parse | `A=ASCII hex` | `C=1,A=nibble` success | NEEDS_PROOF | accepts `0..9`, `A..F`, `a..f` | `UTL HEX PARSE NIBBLE` |
| `UTL_HEX_ASCII_YX_TO_BYTE` | `$EA0B3E6D` | UTL hex parse | `Y=hi ASCII`, `X=lo ASCII` | `C=1,A=byte` success | NEEDS_PROOF | two hex chars to byte | `UTL HEX PARSE BYTE` |
| `UTL_CHAR_IS_PRINTABLE` | `$0566EC22` | UTL char test | `A=char` | `C=1` printable | NEEDS_PROOF | space through `~` | `UTL CHAR CLASSIFY PRINTABLE` |
| `UTL_CHAR_IS_CONTROL` | `$7B454918` | UTL char test | `A=char` | `C=1` control | NEEDS_PROOF | `00..1F` or `7F` | `UTL CHAR CLASSIFY CONTROL` |
| `UTL_CHAR_IS_DIGIT` | `$06BA7C90` | UTL char test | `A=char` | `C=1` digit | NEEDS_PROOF | decimal digit test | `UTL CHAR CLASSIFY DIGIT` |
| `UTL_CHAR_IS_ALPHA` | `$020E7369` | UTL char test | `A=char` | `C=1` alpha | NEEDS_PROOF | ASCII letter test | `UTL CHAR CLASSIFY ALPHA` |
| `UTL_CHAR_TO_UPPER` | `$54633FE8` | UTL char convert | `A=char` | `A=uppercase or unchanged`, `C=1` | NEEDS_PROOF | lowercase to uppercase | `UTL CHAR UPPERCASE` |
| `UTL_CHAR_TO_LOWER` | `$89F65341` | UTL char convert | `A=char` | `A=lowercase or unchanged`, `C=1` | NEEDS_PROOF | uppercase to lowercase | `UTL CHAR LOWERCASE` |
| `UTL_FIND_CHAR_CSTR` | `$B6A44824` | UTL CSTR scan | `A=needle`, `X/Y=CSTR` | found: `C=1` | NEEDS_PROOF | NUL-terminated string search | `UTL FIND CSTRING` |
| `UTL_FIND_CHAR_HBSTR` | `$A687FBC1` | UTL HBSTR scan | `A=needle`, `X/Y=HBSTR` | found: `C=1` | NEEDS_PROOF | high-bit string search, low 7 bits | `UTL FIND HBSTRING` |

## Hash And Catalog Helpers

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `FNV1A_INIT` | `$4B9AEE1E` | hash init | none | `FNV_HASH=$811C9DC5` little-endian | BUILDS | start a new 32-bit FNV-1a hash | `FNV HASH INIT` |
| `FNV1A_UPDATE_A` | `$6E684C95` | hash update | `A=next byte` | `FNV_HASH` updated | BUILDS | hash one byte | `FNV HASH UPDATE BYTE` |
| `FNV1A_MUL_PRIME` | `$40C68FD2` | hash math | current `FNV_HASH` | `FNV_HASH *= $01000193 mod 2^32` | BUILDS | internal multiply step | `FNV HASH MATH` |
| `FNV1A_BUF_XY_LEN` | `$67A1CA5D` | hash buffer | `X/Y=buffer`, `FNV_INPUT_LEN=count` | `FNV_HASH0..3` little-endian | BUILDS | hash counted bytes | `FNV HASH BUFFER` |
| `FNV1A_HBSTR_XY` | `$4E69C4B9` | hash HBSTR | `X/Y=HBSTR` | `FNV_HASH0..3` little-endian | BUILDS | hash high-bit-terminated text | `FNV HASH HBSTRING` |
| `FNV1A_TRIM_TRAILING_CRLF` | `$1F9D1E8D` | hash input cleanup | `FNV_INPUT_LEN=count` | length trimmed | BUILDS | defensive CR/LF trim before hashing | `FNV INPUT TRIM` |

## Flash And Recovery Writes

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `FLASH_ADDR_ALLOWED_XY` | `$772EAC50` | flash guard | `X/Y=target` | `C=1` if `$8000-$CFFF`, else `C=0` | PARTIAL | range check before program/erase; test harness exists | `FLASH ADDRESS GUARD` |
| `FLASH_SECTOR_ERASE_XY` | `$C3099165` | flash erase | `X/Y=sector address` | `C=1` erased and verified, `C=0` guard/timeout | PARTIAL | guarded 4K sector erase; needs board/protection matrix proof before STR8 freeze | `FLASH ERASE RAM_STAGED` |
| `FLASH_SECTOR_ERASE_RAW_XY` | `$F23F864E` | flash erase raw | `X/Y=sector address` | `C=1` erased and verified, `C=0` timeout | NEEDS_PROOF | no range guard; recovery only | `FLASH ERASE RAW` |
| `FLASH_WRITE_BYTE_AXY` | `$103B070B` | flash program | `A=byte`, `X/Y=target` | `C=1` verifies, `C=0` guard/timeout/illegal `0->1` | PARTIAL | guarded byte program; needs full illegal-write and bank matrix proof | `FLASH BYTE_PROGRAM AXY` |
| `FLASH_WRITE_BYTE_RAW_AXY` | `$510FD332` | flash program raw | `A=byte`, `X/Y=target` | `C=1` verifies, `C=0` timeout/illegal `0->1` | NEEDS_PROOF | no range guard; recovery only | `FLASH BYTE_PROGRAM RAW AXY` |

## Vector And Trap Helpers

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SYS_VEC_INIT` | `$C5FE6C62` | SYS vector init | none | vector cells initialized | NEEDS_PROOF | seeds safe patchable targets | `SYS VECTOR RESET IRQ NMI BRK` |
| `SYS_VEC_ENTRY_RESET` | `$4EA53CFC` | vector entry | CPU reset | jumps through reset target | NEEDS_PROOF | reset vector stub | `SYS VECTOR RESET ENTRY` |
| `SYS_VEC_ENTRY_NMI` | `$F8F789CB` | vector entry | CPU NMI | jumps through NMI target | NEEDS_PROOF | NMI vector stub | `SYS VECTOR NMI ENTRY` |
| `SYS_VEC_ENTRY_IRQ_MASTER` | `$72D99F9C` | vector entry | CPU IRQ/BRK stack frame | dispatches BRK vs IRQ target | NEEDS_PROOF | IRQ master stub | `SYS VECTOR IRQ BRK ENTRY` |
| `SYS_VEC_SET_RESET_XY` | `$90CB06AA` | vector patch | `X/Y=target` | reset cell updated | NEEDS_PROOF | patch reset target | `SYS VECTOR SET RESET` |
| `SYS_VEC_SET_NMI_XY` | `$2EEF6FC3` | vector patch | `X/Y=target` | NMI cell updated | NEEDS_PROOF | patch NMI target | `SYS VECTOR SET NMI` |
| `SYS_VEC_SET_IRQ_BRK_XY` | `$0DFCEEC3` | vector patch | `X/Y=target` | BRK cell updated | NEEDS_PROOF | patch BRK target | `SYS VECTOR SET BRK` |
| `SYS_VEC_SET_IRQ_NONBRK_XY` | `$14E4B2B4` | vector patch | `X/Y=target` | IRQ cell updated | NEEDS_PROOF | patch non-BRK IRQ target | `SYS VECTOR SET IRQ` |
| `MON_NMI_TRAP` | `$7D351CE4` | monitor trap | CPU NMI context | re-enters monitor shell | NEEDS_PROOF | Himon monitor NMI path | `MON NMI TRAP DEBUG` |

## Hardware And Recovery BIO Notes

BIO is the planned STR8-friendly layer. The current BIO surface is device-bound
to FTDI/PIA names. A future STR8 import file can publish fixed aliases such as:

```text
BIO_READ_BYTE
BIO_WRITE_BYTE
BIO_WRITE_HEX_BYTE
BIO_WRITE_CRLF
```

Until those aliases exist, use the concrete current names:

```text
BIO_FTDI_READ_BYTE_BLOCK
BIO_FTDI_WRITE_BYTE_BLOCK
BIO_WRITE_HEX_BYTE
BIO_WRITE_CRLF
```

If a programmer needs GPIO/LED routines, start with the `BIO_PIA_*` family in
`SRC/ROUTINE_CONTRACTS.md`; they are numerous enough that this catalog only
names the category here.
