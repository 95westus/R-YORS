# RJOIN Hash Stats Board Test

Purpose: prove the current ASM slice with a real pasted program that uses only
resident executable names for external calls, while exercising local labels and
the current fixup/directive path.

Host preflight:

```text
make -C SRC asm-test
```

Board preflight:

```text
HIMON V 00.0610(1344) or newer
>D 7E00 7E01
expect nonzero ROM-space low/high bytes for THE_JOIN_EXEC_XY
```

Load the current ASM runtime paste image:

```text
>L G
L S19
L @2000
send SRC/BUILD/s19/asm-v1-runtime-paste-2000.s19
expect ASM RT PASTE
```

Paste the program:

```text
paste DOC/GUIDES/ASM/SAMPLES/rjoin-hash-stats-7200.asm
expect ASM RT PASTE OK
```

Assembly table sanity:

```text
MAIN should be $7200
DONE should be $722E
HASH should be $7236
NIB should be $725A
HEX should be $726A
SHOW should be $7278
final PC should be $7640
fixups should be only internal control-flow rows
```

Run it:

```text
>G 7200
expect RJOIN HASH STATS
expect TEXT>
```

Deterministic checks:

```text
HELLO
expect LEN=05 XOR=42 FNV=32543B0B
expect TEXT>

R-YORS
expect LEN=06 XOR=68 FNV=E48E4383
expect TEXT>
```

Optional observed checks from the 2026-06-10 board proof:

```text
MAIN
expect LEN=04 XOR=0B FNV=96272888

DONE
expect LEN=04 XOR=00 FNV=100E2FB1

HASH
expect LEN=04 XOR=12 FNV=CC18DB11

NIB
expect LEN=03 XOR=45 FNV=55DEB5BE

HEX
expect LEN=03 XOR=55 FNV=818F192A

SHOW
expect LEN=04 XOR=03 FNV=A699B27C
```

Exit:

```text
Q
expect BYE
expect HIMON prompt
```

What this proves:

```text
resident JSR via ASM/RJOIN:
  BIO_FTDI_PUT_CSTR
  SYS_READ_CSTRING_ECHO_UPPER
  FNV1A_INIT
  FNV1A_UPDATE_A_FAST
  BIO_FTDI_WRITE_BYTE_BLOCK

local labels:
  HASH/.LOOP and HASH/.DONE
  NIB/.DIG and NIB/.OUT
  MAIN/.LOOP and MAIN/.BLANK

language/features:
  ORG, EQU, DB, DS
  < and > fixups
  forward and backward global/local branches
  zero-page state
  absolute and absolute-indexed operands
  accumulator shifts
  stack PHA/PLA
```

Board-shaping note:

```text
The first 00.0610 board attempt assembled the code before the data labels and
used double-quoted DB strings. That filled all 24 fixup rows before MAIN and
then hit BAD OPER on DB "..." lines, because ASM v1 DB supports byte values and
single-character atoms, not string literals.

The second attempt moved data before code, but ASM v1 does not support a
backward ORG. ORG $7200 after emitting the $7500/$7600 data returned BAD RANGE,
so the code kept assembling at $7640 and G 7200 executed data.

The current accepted shape starts at ORG $7200, defines data addresses with
EQU constants, emits code first, then moves forward to $7500/$7600 for DB/DS.
That avoids both the fixup flood and the backward ORG.

The 2026-06-10 board proof accepted this shape, showed MAIN=$7200 and final
PC=$7640 in the tables, then produced the expected LEN/XOR/FNV values for
HELLO and R-YORS before returning to HIMON on Q.

A later 2026-06-10 cold-boot proof started from G F000, reloaded the $3EF4
ASM RT PASTE image with L S19/L @2000, accepted the same source, showed the
same table sanity, reached the live TEXT> prompt after G 7200, produced the
expected HELLO and R-YORS hashes, and returned to HIMON on Q.
```
