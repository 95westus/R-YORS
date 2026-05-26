# R-YORS Catalog

This is the programmer-facing catalog for callable routines. It answers:

```text
I need to read something. What routine do I call?
I need to write a C string. What are the registers and flags?
I need a BIO-level helper for STR8. What is small enough to trust?
```

For the full generated dump, see `DOC/GENERATED/ROUTINE_CONTRACTS.md`. This guide keeps
the high-value callable surface grouped by need, with an S/36-ish bias toward
"what does the system have, and how do I call it?"

## How To Choose

```text
SYS_*    normal monitor/app API; device-neutral policy/routing surface
BIO_*    reusable low-level I/O contract; public providers should be unique
COR_*    shared implementation logic; use when building BIO/SYS or tests
PIN_*    direct hardware/pin/MMIO layer; use for bring-up or BIO implementation
UTL_*    pure utility/helper routines
FLASH_*  flash guard, erase, and byte-program routines
FNV1A_*  public name-hash helpers; not STR8 V0 policy
CRC16_*  compact local/check helpers, once implemented
STR8_CON_* private STR8 V0 console helpers; no public catalog records
MON_*    monitor command/support internals
```

Rule of thumb: application and monitor code should start at `SYS_*`. STR8 and
early recovery code should start at `BIO_*`. Only drop to `COR_*` or `PIN_*`
when the higher layer does not exist or would pull too much code.

These prefixes are available boundaries, not a mandatory staircase. A routine
does not need `PIN_`, `BIO_`, `COR_`, and `SYS_` versions just because one layer
exists. Add a layer when it expresses a real boundary: hardware access, reusable
device-neutral behavior, recovery-safe byte I/O, public monitor policy, memory
ownership, catalog joining, or another contract that callers can depend on.

Device naming rule:

```text
PIN_<DEVICE>_*    concrete device edge, such as FTDI, ACIA, PIA, VIA
BIO_<DEVICE>_*    concrete recovery-safe provider while the device is part of
                  the contract
BIO_CON_* / BIO_* device-neutral console or byte-I/O contract for code that
                  should survive a backend swap
COR_*             reusable logic without board/device ownership
SYS_*             public policy, routing, and monitor/application API
```

Example: a future RS232/ACIA path should start with `PIN_ACIA_*` routines. It
only needs `BIO_ACIA_*` if callers must name that concrete provider. Search,
copy, fill, and other flash/RAM members should prefer a resident
`BIO_CON_*`/`BIO_*` contract once one exists, so they do not import a specific
FTDI or ACIA routine by accident.

STR8 V0 must not depend on `FNV1A_*`, future `CRC16_*`, or future `CRC32_*`
helpers for recovery decisions. Current FNV helpers belong to HIMON/catalog/
assembler work after recovery handoff. Future STR8-N/STRAIGHTEN can participate
in catalog paths without requiring catalog ownership.

## Field Shape

```text
routine   callable name
hash      existing 32-bit FNV-1a routine comment/signature value
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
PIN_FTDI_*     PROVEN/TOP-SHELF from documented test-ftdi-drv-2000.asm pass notes.
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
BIO WRITE BYTE     -> recovery-safe byte writer, current concrete FTDI form or
                      future console alias
UTL HEX PARSE BYTE -> pure conversion helper, no I/O side effect
FLASH BYTE PROGRAM -> guarded flash byte writer
```

## FTDI Control And Status

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `BIO_FTDI_INIT` | `$30A462F2` | BIO init | none | FTDI pin interface initialized | PROVEN | promoted direct wrapper over top-shelf PIN init | `BIO FTDI INIT PROMOTED` |
| `PIN_FTDI_INIT` | `$226EDE8F` | PIN init | `A` preserved | FTDI control/data direction registers configured | PROVEN | promoted top-shelf FTDI pin initialization | `PIN FTDI INIT PROMOTED` |
| `BIO_FTDI_CHECK_ENUMERATED` | `$994776E3` | BIO status | none | `C=1,A=1` enumerated; `C=0,A=0` otherwise | WRAPS_PROVEN | promoted direct wrapper over PIN enumeration check | `BIO FTDI ENUM PROMOTED` |
| `PIN_FTDI_CHECK_ENUMERATED` | `$8A7D53EE` | PIN status | none | `C=1,A=1` enumerated; `C=0,A=0` otherwise | PROVEN | promoted top-shelf PWE# enumeration check | `PIN FTDI ENUM PROMOTED` |
| `BIO_FTDI_FLUSH_RX` | `$2F6622B9` | BIO flush | none | `C=1` empty; `C=0` guard expired; `A/X/Y` preserved | PROVEN | promoted bounded RX drain used by reset/startup and search proof | `BIO FTDI FLUSH RX PROMOTED` |
| `PIN_FTDI_POLL_RX_READY` | `$F2B69C5B` | PIN readiness | none | `C=1` byte ready; `C=0` empty; `A/X/Y` preserved | PROVEN | promoted top-shelf non-consuming RXF# readiness probe | `PIN FTDI POLL RX PROMOTED` |

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
| `BIO_FTDI_READ_BYTE_BLOCK` | `$20285B85` | BIO read byte | none | `C=1`, `A=byte` | PROVEN | promoted stable unbounded FTDI byte read; use timeout callers for bounded waits | `BIO FTDI READ BYTE BLOCKING PROMOTED` |
| `BIO_FTDI_READ_BYTE_NONBLOCK` | `$6A5E3370` | BIO read byte | none | `C=1,A=byte` ready; `C=0,A=0` none | WRAPS_PROVEN | smallest FTDI receive probe | `BIO FTDI READ BYTE NONBLOCKING` |
| `PIN_FTDI_READ_BYTE_NONBLOCK` | `$483BB2DD` | PIN read byte | none | `C=1,A=byte` ready; `C=0,A=0` none | PROVEN | promoted top-shelf FTDI FIFO read; consumes FIFO byte on success | `PIN FTDI READ BYTE NONBLOCKING PROMOTED` |
| `BIO_FTDI_READ_BYTE_TMO` | `$83426F30` | BIO timed read | none | bounded receive result | PARTIAL | retrying nonblocking read; no-data path has test harness evidence | `BIO FTDI READ TIMEOUT` |
| `BIO_FTDI_POLL_RX_READY` | `$3BD83670` | BIO readiness | none | `C=1` ready, `C=0` not ready | WRAPS_PROVEN | readiness alias over proven PIN poll | `BIO FTDI POLL RX` |
| `PIN_FTDI_POLL_RX_READY` | `$F2B69C5B` | PIN readiness | none | `C=1` byte ready; `C=0` empty; `A/X/Y` preserved | PROVEN | promoted top-shelf non-consuming RXF# readiness probe | `PIN FTDI POLL RX PROMOTED` |
| `BIO_FTDI_GET_CTRL_C` | `$426150D2` | BIO control | none | `C=1,A=$03` if Ctrl-C consumed | USED | long-scan abort poll; not a peek | `BIO FTDI CTRL_C NONBLOCKING` |

## Line And String Input

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SYS_READ_CSTRING` | `$EFF54394` | SYS CSTR read | `X/Y=dest` | backend line-reader `A/C` | NEEDS_PROOF | cooked line input into NUL-terminated buffer | `SYS READ CSTRING COOKED` |
| `SYS_READ_CSTRING_MODE` | `$584E5FAE` | SYS CSTR read | `A=mode`, `X/Y=dest` | backend line-reader `A/C` | NEEDS_PROOF | mode bits: echo, uppercase, lowercase | `SYS READ CSTRING MODE` |
| `SYS_READ_CSTRING_EDIT_MODE` | `$A49D7915` | SYS editable CSTR | `A=mode`, `X/Y=dest` | edit-line `A/C` | NEEDS_PROOF | insert/delete/cursor capable path | `SYS READ CSTRING EDIT` |
| `SYS_READ_CSTRING_EDIT_ECHO_UPPER` | `$B3A76D2C` | SYS editable CSTR | `X/Y=dest` | edit-line `A/C` | NEEDS_PROOF | convenience wrapper: echo and uppercase | `SYS READ CSTRING EDIT ECHO UPPER` |
| `SYS_READ_CSTRING_SILENT` | `$98B68980` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | cooked no-echo input | `SYS READ CSTRING SILENT` |
| `SYS_READ_CSTRING_ECHO_UPPER` | `$E2DD10AF` | SYS CSTR read | `X/Y=dest` | line-reader `A/C` | NEEDS_PROOF | resident HIMON compact line reader row; echo, uppercase, backspace, Ctrl-C, CR/LF; text `READ LINE` | `SYS READ CSTRING ECHO UPPER` |
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
| `BIO_FTDI_WRITE_BYTE_BLOCK` | `$379FE930` | BIO write byte | `A=byte` | `C=1`, `A` preserved | PROVEN | promoted stable unbounded FTDI byte write; use timeout callers for bounded waits | `BIO FTDI WRITE BYTE BLOCKING PROMOTED` |
| `BIO_FTDI_WRITE_BYTE_NONBLOCK` | `$8FAE8ABB` | BIO write byte | `A=byte` | `C=1` accepted, `C=0` timeout, `A` preserved | PARTIAL | success path has test harness evidence; timeout path still needs forced blocked-FIFO proof | `BIO FTDI WRITE BYTE NONBLOCKING` |
| `PIN_FTDI_WRITE_BYTE_NONBLOCK` | `$D55FC6FC` | PIN write byte | `A=byte` | `C=1` accepted; `C=0` timeout; `A` preserved | PROVEN | promoted top-shelf FTDI FIFO write; timeout path has documented hardware limitation | `PIN FTDI WRITE BYTE NONBLOCKING PROMOTED` |
| `BIO_FTDI_WRITE_BYTE_TMO` | `$DC28D281` | BIO timed write | `A=byte` | bounded transmit result, `A` preserved | NEEDS_PROOF | retrying nonblocking write | `BIO FTDI WRITE TIMEOUT` |
| `BIO_WRITE_HEX_BYTE` | `$CDBB01D2` | BIO write hex | `A=byte` | `C=1`, `A` preserved | NEEDS_PROOF | STR8-friendly hex output | `BIO WRITE HEX BYTE` |
| `BIO_WRITE_CRLF` | `$8C36CC4D` | BIO newline | none | `C=1`, `A` preserved | NEEDS_PROOF | STR8-friendly newline | `BIO WRITE CRLF` |

## Hex And Character Utilities

| routine | hash | class | in | out / flags | proof | notes | tags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `UTL_HEX_NIBBLE_TO_ASCII` | `$D4C88B87` | UTL hex encode | `A=byte` | low nibble as `'0'..'F'`, `C=1` | PROVEN | promoted small uppercase nibble encoder | `UTL HEX ENCODE NIBBLE PROMOTED` |
| `UTL_HEX_BYTE_TO_ASCII_YX` | `$7142DD21` | UTL hex encode | `A=byte` | `A` preserved, `Y=hi ASCII`, `X=lo ASCII`, `C=1` | PROVEN | promoted byte-to-two-ASCII helper | `UTL HEX ENCODE BYTE PROMOTED` |
| `UTL_HEX_ASCII_TO_NIBBLE` | `$ADD714B1` | UTL hex parse | `A=ASCII hex` | `C=1,A=nibble` success; `C=0,A` unchanged invalid | PROVEN | promoted parser for `0..9`, `A..F`, `a..f` | `UTL HEX PARSE NIBBLE PROMOTED` |
| `UTL_HEX_ASCII_YX_TO_BYTE` | `$EA0B3E6D` | UTL hex parse | `Y=hi ASCII`, `X=lo ASCII` | `C=1,A=byte` success; `C=0` invalid | PROVEN | promoted two-char parser; uses `UTL_CONV_TMP_A=$E6` | `UTL HEX PARSE BYTE PROMOTED` |
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
| `FNV1A_INIT` | `$4B9AEE1E` | hash init | none | `FNV_HASH=$811C9DC5` little-endian | BUILDS | start a new 32-bit FNV-1a hash; resident text `HASH OPEN` | `FNV HASH INIT` |
| `FNV1A_UPDATE_A` | `$6E684C95` | hash update | `A=next byte` | `FNV_HASH` updated | BUILDS | hash one byte | `FNV HASH UPDATE BYTE` |
| `FNV1A_UPDATE_A_FAST` | `$A8802314` | hash update | `A=next byte` | `FNV_HASH` updated | BUILDS | faster drop-in update; ROM-for-cycles tradeoff to lessen software multiply cost; resident text `HASH MIX` | `FNV HASH UPDATE BYTE FAST` |
| `FNV1A_MUL_PRIME` | `$40C68FD2` | hash math | current `FNV_HASH` | `FNV_HASH *= $01000193 mod 2^32` | BUILDS | internal multiply step | `FNV HASH MATH` |
| `FNV1A_MUL_PRIME_FAST` | `$303E5DC1` | hash math | current `FNV_HASH` | `FNV_HASH *= $01000193 mod 2^32` | BUILDS | same math with only the fixed shift loop unrolled; trades a few bytes for fewer cycles | `FNV HASH MATH FAST` |
| `FNV1A_BUF_XY_LEN` | `$67A1CA5D` | hash buffer | `X/Y=buffer`, `FNV_INPUT_LEN=count` | `FNV_HASH0..3` little-endian | BUILDS | hash counted bytes | `FNV HASH BUFFER` |
| `FNV1A_HBSTR_XY` | `$4E69C4B9` | hash HBSTR | `X/Y=HBSTR` | `FNV_HASH0..3` little-endian | BUILDS | hash high-bit-terminated text | `FNV HASH HBSTRING` |
| `FNV1A_FOLD8_XY_A` | `$632A38DD` | hash fold | `X/Y=hash0..3 ptr` | `A=hash8`, `C=1`; `X/Y` preserved | PARTIAL | standalone fold helper after any canonical 32-bit FNV result | `FNV HASH FOLD8 COMPACT` |
| `FNV1A_FOLD16_XY_A8` | `$E52B90E6` | hash fold | `X/Y=hash0..3 ptr` | `X=hash16_lo`, `Y=hash16_hi`, `A=hash8`, `C=1` | PARTIAL | standalone fold helper that also returns the 8-bit fold | `FNV HASH FOLD16 FOLD8 COMPACT` |
| `FNV1A_FOLD32_XY` | `$9F48B1D8` | hash fold | `X/Y=hash0..3 ptr` | `X/Y` unchanged, `C=1` | PARTIAL | full-width identity helper for width-dispatch code | `FNV HASH FOLD32 FULL` |
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
| `MON_NMI_TRAP` | `$7D351CE4` | monitor trap | CPU NMI context | re-enters monitor shell | NEEDS_PROOF | Baseline Himon monitor NMI path; active vector may point at a debounce POC wrapper. | `MON NMI TRAP DEBUG` |

## Hardware And Recovery BIO Notes

BIO is the reusable low-level I/O layer. The current BIO surface is device-bound
to FTDI/PIA names and is owned by the HIMON/current ROM body in the combined
image. STR8 V0 uses private `STR8_CON_*` console helpers so it remains
self-contained without publishing duplicate BIO/PIN catalog records.

A future STR8 import file can publish fixed aliases such as:

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

## Promoted PIN Routine Hash Sigs / RREC Seeds

The promoted PIN FTDI primitives are the hardware-facing roots under the BIO
contracts. They now carry current HIMON-style hash signatures immediately before
their callable entries.

```text
RREC PIN_FTDI_INIT
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      PIN_FTDI_INIT
  hash32:    $226EDE8F
  stored:    hash0=$8F hash1=$DE hash2=$6E hash3=$22
  hash_sig:  46 4E D6 8F DE 6E 22 00
             emitted as PIN_FTDI_INIT_FNV immediately before entry
  provider:  active FTDI PIN driver
  body:      current ROM image or linked PIN body
  entry:     PIN_FTDI_INIT
  call:      JSR entry; returns by RTS after VIA pin setup
  in:        A preserved
  out:       FTDI control/data direction registers configured
  imports:   none
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO $7FE0/$7FE2/$7FE3
             stack return frame plus A save
  flags:     PIN, FTDI, INIT, PRESERVE_A, PRESERVE_XY, PROMOTED, TOP_SHELF
  proof:     PROVEN; top-shelf 2026-04-18, hash-sig promoted 2026-05-15
```

```text
RREC PIN_FTDI_POLL_RX_READY
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      PIN_FTDI_POLL_RX_READY
  hash32:    $F2B69C5B
  stored:    hash0=$5B hash1=$9C hash2=$B6 hash3=$F2
  hash_sig:  46 4E D6 5B 9C B6 F2 00
             emitted as PIN_FTDI_POLL_RX_READY_FNV immediately before entry
  provider:  active FTDI PIN driver
  body:      current ROM image or linked PIN body
  entry:     PIN_FTDI_POLL_RX_READY
  call:      JSR entry; returns by RTS after one RXF# sample
  in:        none
  out:       ready: C=1; empty: C=0; A/X/Y preserved
  imports:   none
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO $7FE0
             stack return frame plus A save
  flags:     PIN, FTDI, POLL, RX, READY, NONCONSUMING, CARRY_STATUS,
             PRESERVE_A, PRESERVE_XY, PROMOTED, TOP_SHELF
  proof:     PROVEN; top-shelf 2026-04-18, hash-sig promoted 2026-05-15
  caveat:    readiness only; callers that need the byte must use a read routine
```

```text
RREC PIN_FTDI_CHECK_ENUMERATED
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      PIN_FTDI_CHECK_ENUMERATED
  hash32:    $8A7D53EE
  stored:    hash0=$EE hash1=$53 hash2=$7D hash3=$8A
  hash_sig:  46 4E D6 EE 53 7D 8A 00
             emitted as PIN_FTDI_CHECK_ENUMERATED_FNV immediately before entry
  provider:  active FTDI PIN driver
  body:      current ROM image or linked PIN body
  entry:     PIN_FTDI_CHECK_ENUMERATED
  call:      JSR entry; returns by RTS after one PWE# sample
  in:        none
  out:       enumerated: C=1,A=1; otherwise: C=0,A=0; X/Y preserved
  imports:   none
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO $7FE0
             stack return frame only
  flags:     PIN, FTDI, ENUM, STATUS, CARRY_STATUS, PRESERVE_XY, PROMOTED,
             TOP_SHELF
  proof:     PROVEN; top-shelf 2026-04-18, hash-sig promoted 2026-05-15
  caveat:    returned A value is still the current placeholder status encoding
```

```text
RREC PIN_FTDI_READ_BYTE_NONBLOCK
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      PIN_FTDI_READ_BYTE_NONBLOCK
  hash32:    $483BB2DD
  stored:    hash0=$DD hash1=$B2 hash2=$3B hash3=$48
  hash_sig:  46 4E D6 DD B2 3B 48 00
             emitted as PIN_FTDI_READ_BYTE_NONBLOCK_FNV immediately before entry
  provider:  active FTDI PIN driver
  body:      current ROM image or linked PIN body
  entry:     PIN_FTDI_READ_BYTE_NONBLOCK
  call:      JSR entry; returns by RTS after a single readiness check
  in:        none
  out:       ready: C=1, A=byte; empty: C=0, A=$00
  imports:   none
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO $7FE0/$7FE1/$7FE3
             stack return frame plus scratch push while RD# is asserted
  flags:     PIN, FTDI, READ, BYTE, NONBLOCKING, CARRY_STATUS, PROMOTED,
             TOP_SHELF
  proof:     PROVEN; top-shelf 2026-04-18, hash-sig promoted 2026-05-15
  caveat:    consumes the FIFO byte when ready; not a non-destructive peek
```

```text
RREC PIN_FTDI_WRITE_BYTE_NONBLOCK
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      PIN_FTDI_WRITE_BYTE_NONBLOCK
  hash32:    $D55FC6FC
  stored:    hash0=$FC hash1=$C6 hash2=$5F hash3=$D5
  hash_sig:  46 4E D6 FC C6 5F D5 00
             emitted as PIN_FTDI_WRITE_BYTE_NONBLOCK_FNV immediately before entry
  provider:  active FTDI PIN driver
  body:      current ROM image or linked PIN body
  entry:     PIN_FTDI_WRITE_BYTE_NONBLOCK
  call:      JSR entry; returns by RTS after accept or spin-limit timeout
  in:        A=byte to transmit
  out:       accepted: C=1, A preserved; timeout: C=0, A preserved
  imports:   none
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO $7FE0/$7FE1/$7FE3
             stack return frame plus A save
  flags:     PIN, FTDI, WRITE, BYTE, NONBLOCKING, TIMEOUT, CARRY_STATUS,
             PRESERVE_A, PROMOTED, TOP_SHELF
  proof:     PROVEN; top-shelf 2026-04-18, hash-sig promoted 2026-05-15
  caveat:    forced blocked-FIFO hardware proof is still difficult, but the
             existing top-shelf driver pass verified return codes and behavior
```

## Promoted BIO Routine Hash Sigs / RREC Seeds

The promoted BIO FTDI primitives have current HIMON-style hash signatures now
and RREC seeds for the later catalog linker/resolver. The hash signatures are
real emitted bytes; the fuller RREC cards are not emitted/scanned catalog bytes
yet.

```text
RREC BIO_FTDI_INIT
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      BIO_FTDI_INIT
  hash32:    $30A462F2
  stored:    hash0=$F2 hash1=$62 hash2=$A4 hash3=$30
  hash_sig:  46 4E D6 F2 62 A4 30 00
             emitted as BIO_FTDI_INIT_FNV immediately before entry
  provider:  active HIMON/BIO image
  body:      current ROM image or linked BIO body
  entry:     BIO_FTDI_INIT
  call:      JSR entry; returns by RTS after PIN init
  in:        none
  out:       FTDI pin interface initialized
  imports:   PIN_FTDI_INIT
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO through PIN_FTDI_INIT
             stack return frame plus transitive PIN init A save
  flags:     BIO, FTDI, INIT, PUFF_PASS, PROMOTED
  proof:     PROVEN; wrapper promoted 2026-04-19, hash-sig promoted 2026-05-15
```

```text
RREC BIO_FTDI_CHECK_ENUMERATED
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      BIO_FTDI_CHECK_ENUMERATED
  hash32:    $994776E3
  stored:    hash0=$E3 hash1=$76 hash2=$47 hash3=$99
  hash_sig:  46 4E D6 E3 76 47 99 00
             emitted as BIO_FTDI_CHECK_ENUMERATED_FNV immediately before entry
  provider:  active HIMON/BIO image
  body:      current ROM image or linked BIO body
  entry:     BIO_FTDI_CHECK_ENUMERATED
  call:      JSR entry; returns by RTS after PIN status check
  in:        none
  out:       enumerated: C=1,A=1; otherwise: C=0,A=0
  imports:   PIN_FTDI_CHECK_ENUMERATED
  resources: ZP none; fixed RAM none
             transitive PIN enumeration resources
             stack return frame
  flags:     BIO, FTDI, ENUM, STATUS, CARRY_STATUS, PUFF_PASS, PROMOTED
  proof:     WRAPS_PROVEN; wrapper promoted 2026-04-19, hash-sig promoted 2026-05-15
```

```text
RREC BIO_FTDI_FLUSH_RX
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      BIO_FTDI_FLUSH_RX
  hash32:    $2F6622B9
  stored:    hash0=$B9 hash1=$22 hash2=$66 hash3=$2F
  hash_sig:  46 4E D6 B9 22 66 2F 00
             emitted as BIO_FTDI_FLUSH_RX_FNV immediately before entry
  provider:  active HIMON/BIO image
  body:      current ROM image or linked BIO body
  entry:     BIO_FTDI_FLUSH_RX
  call:      JSR entry; returns by RTS after RX empty or guard expiry
  in:        none
  out:       empty: C=1; guard expired: C=0; A/X/Y preserved
  imports:   PIN_FTDI_READ_BYTE_NONBLOCK
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO through PIN_FTDI_READ_BYTE_NONBLOCK
             stack return frame plus A/X saves and transitive PIN read scratch
  flags:     BIO, FTDI, FLUSH, RX, BOUNDED, CARRY_STATUS, PRESERVE_A,
             PRESERVE_XY, PROMOTED
  proof:     PROVEN; bounded drain 2026-05-07, hash-sig promoted 2026-05-15
  caveat:    consumes pending RX bytes by design
```

```text
RREC BIO_FTDI_GET_CTRL_C
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      BIO_FTDI_GET_CTRL_C
  hash32:    $426150D2
  stored:    hash0=$D2 hash1=$50 hash2=$61 hash3=$42
  hash_sig:  46 4E D6 D2 50 61 42 00
             emitted as BIO_FTDI_GET_CTRL_C_FNV immediately before entry
  provider:  active HIMON/BIO image
  body:      current ROM image or linked BIO body
  entry:     BIO_FTDI_GET_CTRL_C
  call:      JSR entry; returns by RTS after one nonblocking RX poll
  in:        none
  out:       Ctrl-C: C=1,A=$03; otherwise C=0,A=$00
  imports:   PIN_FTDI_READ_BYTE_NONBLOCK
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO through PIN_FTDI_READ_BYTE_NONBLOCK
             stack return frame plus transitive PIN read scratch push
  flags:     BIO, FTDI, CTRL_C, NONBLOCKING, CARRY_STATUS, CONSUMES_RX,
             PROMOTED
  proof:     USED; long-scan abort poll, hash-sig promoted 2026-05-15
  caveat:    consumes one pending RX byte when any byte is available; do not
             use as a general non-destructive peek
```

```text
RREC BIO_FTDI_READ_BYTE_BLOCK
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      BIO_FTDI_READ_BYTE_BLOCK
  hash32:    $20285B85
  stored:    hash0=$85 hash1=$5B hash2=$28 hash3=$20
  hash_sig:  46 4E D6 85 5B 28 20 00
             emitted as BIO_FTDI_READ_BYTE_BLOCK_FNV immediately before entry
  provider:  active HIMON/BIO image
  body:      current ROM image or linked BIO body
  entry:     BIO_FTDI_READ_BYTE_BLOCK
  call:      JSR entry; returns by RTS after a byte is received
  in:        none
  out:       C=1, A=received byte
  imports:   PIN_FTDI_READ_BYTE_NONBLOCK
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO through PIN_FTDI_READ_BYTE_NONBLOCK
             stack return frame plus transitive PIN read scratch push
  flags:     BIO, FTDI, READ, BYTE, BLOCKING, CARRY_STATUS, PROMOTED,
             UNBOUNDED
  proof:     PROVEN; promoted 2026-05-15 as stable unbounded BIO receive
  caveat:    not a peek and not timeout-shaped; bounded callers use
             BIO_FTDI_READ_BYTE_TMO or an explicit timeout wrapper
```

```text
RREC BIO_FTDI_WRITE_BYTE_BLOCK
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      BIO_FTDI_WRITE_BYTE_BLOCK
  hash32:    $379FE930
  stored:    hash0=$30 hash1=$E9 hash2=$9F hash3=$37
  hash_sig:  46 4E D6 30 E9 9F 37 00
             emitted as BIO_FTDI_WRITE_BYTE_BLOCK_FNV immediately before entry
  provider:  active HIMON/BIO image
  body:      current ROM image or linked BIO body
  entry:     BIO_FTDI_WRITE_BYTE_BLOCK
  call:      JSR entry; returns by RTS after byte is accepted
  in:        A=byte to transmit
  out:       C=1, A preserved
  imports:   PIN_FTDI_WRITE_BYTE_NONBLOCK
  resources: ZP none; fixed RAM none
             FTDI/VIA MMIO through PIN_FTDI_WRITE_BYTE_NONBLOCK
             stack return frame plus X save and transitive PIN write scratch
  flags:     BIO, FTDI, WRITE, BYTE, BLOCKING, CARRY_STATUS, PRESERVE_A,
             PRESERVE_X, PROMOTED, UNBOUNDED
  proof:     PROVEN; promoted 2026-05-15 as stable unbounded BIO transmit
  caveat:    not timeout-shaped; bounded callers use BIO_FTDI_WRITE_BYTE_TMO
             or an explicit timeout wrapper
```

The emitted hash sigs use the current HIMON 8-byte record shape. The final byte
is `$00`, so current code interprets each entry as `hash_sig+8`. A future compact
RREC can assign a cleaner routine/export kind without changing either routine
contract.

## Promoted UTL Hex Routine Hash Sigs / RREC Seeds

The promoted hex helpers are pure conversion contracts except for
`UTL_HEX_ASCII_YX_TO_BYTE`, which uses the shared one-byte utility scratch
`$E6` while combining nibbles. These helpers are small, heavily reused, and good
early catalog-linking candidates because they remove duplicated hex code from
RAM workers.

The same promotion pattern applies to parser helpers. If HIMON, search, copy,
fill, and later STR8-N tools all need `start end|+count`, first static-link a
documented range-parser contract and keep caller-specific workspace adapters
thin. Later the same contract can become an `RREC` export with `RF`/`RLNK`
users. That is the "routines made from routines" rule in catalog form: promote
the useful behavior, not just a pasted source block.

```text
RREC UTL_HEX_NIBBLE_TO_ASCII
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      UTL_HEX_NIBBLE_TO_ASCII
  hash32:    $D4C88B87
  stored:    hash0=$87 hash1=$8B hash2=$C8 hash3=$D4
  hash_sig:  46 4E D6 87 8B C8 D4 00
             emitted as UTL_HEX_NIBBLE_TO_ASCII_FNV immediately before entry
  provider:  active utility library or resident ROM image
  body:      current linked UTL body
  entry:     UTL_HEX_NIBBLE_TO_ASCII
  call:      JSR entry; returns by RTS after conversion
  in:        A=source byte; low nibble is used
  out:       A=ASCII `0..9` or `A..F`, C=1
  imports:   none
  resources: ZP none; fixed RAM none; stack return frame only
  flags:     UTL, HEX, ENCODE, NIBBLE, CARRY_STATUS, NO_ZP, PROMOTED
  proof:     PROVEN; reviewed and hash-sig promoted 2026-05-15
```

```text
RREC UTL_HEX_BYTE_TO_ASCII_YX
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      UTL_HEX_BYTE_TO_ASCII_YX
  hash32:    $7142DD21
  stored:    hash0=$21 hash1=$DD hash2=$42 hash3=$71
  hash_sig:  46 4E D6 21 DD 42 71 00
             emitted as UTL_HEX_BYTE_TO_ASCII_YX_FNV immediately before entry
  provider:  active utility library or resident ROM image
  body:      current linked UTL body
  entry:     UTL_HEX_BYTE_TO_ASCII_YX
  call:      JSR entry; returns by RTS after both nibbles are encoded
  in:        A=source byte
  out:       A preserved, Y=high ASCII, X=low ASCII, C=1
  imports:   UTL_HEX_NIBBLE_TO_ASCII
  resources: ZP none; fixed RAM none; stack return frame plus A save
  flags:     UTL, HEX, ENCODE, BYTE, CARRY_STATUS, PRESERVE_A, PROMOTED
  proof:     PROVEN; reviewed and hash-sig promoted 2026-05-15
```

```text
RREC UTL_HEX_ASCII_TO_NIBBLE
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      UTL_HEX_ASCII_TO_NIBBLE
  hash32:    $ADD714B1
  stored:    hash0=$B1 hash1=$14 hash2=$D7 hash3=$AD
  hash_sig:  46 4E D6 B1 14 D7 AD 00
             emitted as UTL_HEX_ASCII_TO_NIBBLE_FNV immediately before entry
  provider:  active utility library or resident ROM image
  body:      current linked UTL body
  entry:     UTL_HEX_ASCII_TO_NIBBLE
  call:      JSR entry; returns by RTS after validation/conversion
  in:        A=ASCII `0..9`, `A..F`, or `a..f`
  out:       valid: C=1,A=0..15; invalid: C=0,A unchanged
  imports:   none
  resources: ZP none; fixed RAM none; stack return frame only
  flags:     UTL, HEX, PARSE, NIBBLE, CARRY_STATUS, NO_ZP, PROMOTED
  proof:     PROVEN; reviewed and hash-sig promoted 2026-05-15
```

```text
RREC UTL_HEX_ASCII_YX_TO_BYTE
  lifecycle: formed, sealed, not buried
  kind:      routine/export
  name:      UTL_HEX_ASCII_YX_TO_BYTE
  hash32:    $EA0B3E6D
  stored:    hash0=$6D hash1=$3E hash2=$0B hash3=$EA
  hash_sig:  46 4E D6 6D 3E 0B EA 00
             emitted as UTL_HEX_ASCII_YX_TO_BYTE_FNV immediately before entry
  provider:  active utility library or resident ROM image
  body:      current linked UTL body
  entry:     UTL_HEX_ASCII_YX_TO_BYTE
  call:      JSR entry; returns by RTS after validation/conversion
  in:        Y=high ASCII hex, X=low ASCII hex
  out:       valid: C=1,A=combined byte; invalid: C=0
  imports:   UTL_HEX_ASCII_TO_NIBBLE
  resources: ZP `UTL_CONV_TMP_A=$E6`; fixed RAM none; stack return frame
  flags:     UTL, HEX, PARSE, BYTE, CARRY_STATUS, USES_ZP, PROMOTED
  proof:     PROVEN; reviewed and hash-sig promoted 2026-05-15
  caveat:    not reentrant while sharing `$E6`
```

If a programmer needs GPIO/LED routines, start with the `BIO_PIA_*` family in
`DOC/GENERATED/ROUTINE_CONTRACTS.md`; they are numerous enough that this catalog only
names the category here.
