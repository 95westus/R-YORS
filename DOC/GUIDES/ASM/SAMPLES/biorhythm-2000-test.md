# Biorhythm 2000 Board Test

Purpose: prove a small interactive ASM program on the flash-resident ASM path.
The program uses only resident RJOIN-callable services for console I/O:

```text
BIO_FTDI_PUT_CSTR
SYS_READ_CSTRING_ECHO_UPPER
BIO_FTDI_WRITE_BYTE_BLOCK
```

The chart is biorhythm-style rather than a calendar/date calculator. It accepts
a day number `0-255`, then draws three phase lines:

```text
P physical      period 23
E emotional     period 28
I intellectual  period 33
```

`*` marks `day mod period`; `|` marks the midpoint; the sign is `+`, `-`, or
`0` at the midpoint.

Host preflight:

```text
make -C SRC asm-test
make -C SRC asm-v1-flash
```

Board preflight:

```text
HIMON V 00.0610(2014) or newer
flash ASM image already loaded at $8000, or load SRC/BUILD/s19/asm-v1-flash-8000.s19 with L F
ASM image must include direct resident JSR/JMP lookup and enough fixup rows for
this sample; current flash ASM uses ASM_FIX_MAX=$60
```

Enter flash ASM:

```text
>ASM
expect ASM FLASH
expect ASM>
```

Paste the program:

```text
paste DOC/GUIDES/ASM/SAMPLES/biorhythm-2000.asm
expect ASM FLASH OK
```

Assembly-shape note:

```text
The helper routines are deliberately defined before the main input loop. A
first board attempt with MAIN/PARSE/RUN before OUTA/GRAPH/CRLF/NIB filled all
24 fixup rows and failed with BAD FIX at PC=$2126. The current order keeps most
JSR/JMP targets already defined and reserves fixups for the few real forward
branches.

A later helper-first attempt on an older JSR-only resident resolver failed at
END with `BAD FIX` and 19/24 fixups: `JMP BIO_FTDI_WRITE_BYTE_BLOCK` and
`JMP BIO_FTDI_PUT_CSTR` were still ordinary unresolved fixups. The current ASM
image resolves direct resident `JMP name` as well as `JSR name`, so these
tail-call wrappers are legal.
```

Run it:

```text
>G 2000
expect BIORHYTHM
expect DAY 0-255 OR Q>
```

Deterministic checks:

```text
0
expect DAY $00
expect P + *..........|...........
expect E + *.............|.............
expect I + *...............|................

11
expect DAY $0B
expect P 0 ...........*...........

23
expect DAY $17
expect P + *..........|...........

256
expect ?

Q
expect BYE
expect HIMON prompt
```

Accepted hardware proof on 2026-06-10:

```text
>L F
expect LF OK WR=2D6B GO=800C

>ASM
paste DOC/GUIDES/ASM/SAMPLES/biorhythm-2000.asm
expect ASM FLASH OK
expect SYMBOL rows 00-16
expect FIXUP rows 00-10, all ST=02 resolved

>G 2000
enter 172
expect DAY $AC
expect P 0 ...........*...........
expect E + ....*.........|.............
expect I + .......*........|................

enter 173
expect DAY $AD
expect P - ...........|*..........

enter 174
expect DAY $AE
expect P - ...........|.*.........

enter 175
expect DAY $AF
expect P - ...........|..*........

enter Q
expect BYE
```

What this proves:

```text
resident JSR/JMP via ASM/RJOIN:
  BIO_FTDI_PUT_CSTR
  SYS_READ_CSTRING_ECHO_UPPER
  BIO_FTDI_WRITE_BYTE_BLOCK

language/features:
  flash ASM command entry
  ORG, DB, DS
  local labels
  zero-page state
  decimal digit parsing
  modulo by repeated subtraction
  immediate character atoms
  absolute indexed input buffer
  relative branches
```
