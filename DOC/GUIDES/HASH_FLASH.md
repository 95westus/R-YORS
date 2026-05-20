# HASH FLASH

HASH FLASH is the short alert stream for command-surface changes that are easy
to miss if you remember yesterday's monitor behavior.

The settled calls still belong in [DECISIONS.md](./DECISIONS.md). Operator
syntax belongs in [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md). This file is the
readable bridge between those two places.

Entries use CBI doc form, named for Computer Bank, Inc., the
project author's RPG II coding-days employer:

```text
YYYY
         MM
                DD
                   HH:MMZ programmer comment
                               continuation line
```

Use UTC ISO 8601 time without seconds. Sort newest first at every level:
year, month, day, and time all descend. Continuation lines align under the
comment body. Keep Markdown source lines under 78 columns.

CBI code form stays condensed for source comments:

```asm
; YYYY-MM-DDTHH:MMZ WLP2 summary
;                         continuation line
```

## REHASH: HIMON Visible Version Uses Current Date

```text
2026
         05
                19
                   19:30Z WLP2 Corrected the HBSTR terminator so the closing
                               parenthesis prints.
                   19:26Z WLP2 HIMON visible text is now
                               HIMON V 00.0519(1925), and the resident K=$10
                               HIMON record points at the same text.
                   19:23Z WLP2 HIMON ROM now contains one resident K=$10
                               FNV record for HIMON, pointing at START and
                               EXTRA text HIMON V 00.0519.
                   19:00Z WLP2 HIMON cold boot now reports V 00.0519,
                               derived from the current update date.
```

For visible HIMON/STR8 version updates, get the current date first, then derive
the banner version from that date. The May 19 update line is:

```text
HIMON V 00.0519
```

## REHASH: HIMON # K10 EXTRA Text

```text
2026
         05
                19
                   18:58Z WLP2 HIMON # now understands current FNV K=$10
                               pointer records well enough to print a
                               nonzero DW EXTRA HBSTR at the end of the row.
```

The current FNV-era `#` view keeps old `K=$00` records quiet and unchanged.
For a `K=$10` record, HIMON reads:

```text
DW ENTRY
DW EXTRA
```

`ENTRY` is printed as the row entry address. If `EXTRA` is `$0000`, no text is
added. If `EXTRA` is nonzero, `#` appends one space and writes the
high-bit-terminated string found there.

## REHASH: STR8 Three-Image Milestone And CRC16 Hash Pivot

```text
2026
         05
                18
                   15:10Z WLP2 STR8 now has hardware proof rotating HIMON,
                               OSI BASIC, and fig-FORTH, and FNV-1a is no
                               longer documented as the final catalog spine.
```

The operator-facing truth changed again: `U` / `UPDATE HIMON` is now proven
not only with HIMON U1->U2, but as the fixed `$C000-$EFFF` gate that can place
bootable OSI BASIC and fig-FORTH payloads where HIMON normally lives. STR8 can
then use its backup/restore path to return to known-good HIMON.

The hash-policy truth also changed. Existing HIMON command records and the
quoted helper still carry FNV-era behavior, but that is implementation history
and transition debt. The intended compact runtime/catalog lookup hash is now a
tableless CRC16 shape, chosen because W65C02 time and ROM pressure beat the
first FNV-1a design.

Do not write new public docs as though 32-bit FNV-1a is the settled universal
spine. Say "current FNV-era records" when describing the present ROM, and say
"tableless CRC16 compact hash" when describing the intended catalog direction.

See [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) for the three-image operator
path and [DECISIONS.md](./DECISIONS.md), [HASH.md](HASH/HASH.md), and
[HASH_MAP.md](HASH/HASH_MAP.md) for the catalog-hash pivot.

## REHASH: STR8 UPDATE HIMON Hardware Proof

```text
2026
         05
                18
                   02:35Z WLP2 STR8 U / UPDATE HIMON is hardware-proven
                               for the fixed C000-EFFF HIMON gate.
```

The operator-facing truth changed: `U` is no longer only proposed or waiting
for a first useful proof. On hardware, Bank 3 booted visible `HIMON U1`, `B`
copied that known-good image into Bank 2, `U` accepted the compact
`$C000-$EFFF` S19 stream, asked before programming, and rebuilt HIMON as
visible `HIMON U2`. STR8 stayed reachable after the update through `G F000`.
A high-flash restore from Bank 2 back to Bank 3 then brought visible
`HIMON U1` back.

Command-surface status:

```text
U / UPDATE HIMON
  implemented
  accepts only S1 records inside $C000-$EFFF
  stages blank C/D/E RAM images, overlays S19 bytes, then programs C/D/E
  asks before erase/write
  leaves $F000-$FFFF to STR8 unless a separate future STR8 path exists
```

Do not promote `U T`, `U H`, or `U S` as operator commands. `U` remains the
short fixed HIMON profile. The future broader surface is still named-target
and confirmed:

```text
UPDATE
UPDATE HIMON
UPDATE STR8
```

`UPDATE STR8` is not proven or implemented by this pass. It still needs a
stronger confirmation and a top-sector transaction.

Transcript and artifact details live in
[HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md). Remaining STR8 proof gaps are
Bank 0 enrollment, restore over non-erased ordinary sectors below `$C000`, and
deliberate high-flash failure behavior with a sacrificial image.

## REHASH: Hardware Test Log Available

```text
2026
         05
                16
                   03:05Z WLP2 Added a hardware test log entry for the
                               STR8/HIMON/HREC/search/debug smoke pass.
```

The board transcript validation now has a single home:
[HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md). The first entry records the
2026-05-15 STR8/HIMON/HREC/search/debug smoke pass, including STR8 map/restore,
burn-check dumps, HREC join, search mixed-case text, debug `N` stepping,
breakpoints, catalog lookup, and the resident HIMON `+count` range-parser
finding.

Use HASH FLASH for the command-surface alert; use the hardware test log for the
actual transcript slices and pass/finding details.

## REHASH: RAM-Only Debug Edict

```text
2026
         05
                13
                   21:30Z WLP2 N/B/X RAM debug path now matches the
                               RAM-only debug spec on hardware proof.
                   17:43Z WLP2 HIMON debug patching is RAM-only;
                               ROM/flash code may run opaquely, but is
                               not a patch target.
```

Full debugger functionality belongs in RAM. Any debugger operation that
plants, restores, or depends on a synthetic `BRK` must classify the target
address before writing. ROM/flash and I/O targets are rejected for debug
patching.

This applies to user breakpoints, temporary `N` breakpoints, and any future
true stepper that uses trap planting. A debugger trap is not a generic
memory-write probe. HIMON must not test `$8000-$FFFF` by storing `BRK` and
reading it back. Generic memory edit, ROM, flash, and banked flash routines
have their own policy.

The first compact HIMON policy is stricter than "any RAM": synthetic debugger
traps may be planted only in UPA `$2000-$77FF`. Zero page, hardware stack, low
RAM, HIUPA/scratch, monitor/page-buffer RAM, I/O, and ROM/flash are rejected.
This makes RAM-only `N` non-destructive in the command-safety sense: the user
program byte is restored, and system-owned memory is not a patch target.

Hardware proof status: the current HIMON debug proof has exercised `B`, `B C`,
`B L`, `N`, and `X` against RAM code at `$3000`. Verified behavior includes
one-shot breakpoints, compact debugger stops as `@hhhh`, `BP FULL`, `BP NF`,
`DBG RAM` outside the patchable range, no command-return `RET` trailer for
plain monitor commands, and empty `B L` after all one-shot breakpoints are
consumed. This confirms the RAM patch/restore policy; it does not make
ROM/flash a debug patch target.

ROM/flash can still execute while RAM code is being debugged. A RAM `JSR` into
ROM can be treated as opaque code if the debugger plants the next trap at a
known RAM return address. A `JMP` into ROM is not a returning call. Debug
resumes only when control reaches a known RAM continuation, the user traps
with NMI, or ROM executes an intentional `BRK xx`.

HIMON should distinguish synthetic debugger breakpoints from real `BRK xx`
program behavior. A synthetic RAM breakpoint restores the original opcode and
rewinds PC to the replaced instruction. Current transcript format reports
synthetic debugger stops as `@hhhh` followed by the register state. A real
`BRK xx`, including one in ROM/flash, reports the signature and the
architectural resume PC:

```text
BRK xx PC=hhhh
A=bb X=bb Y=bb P=bb S=bb flags
```

Address classification can become a shared primitive. `UTL_ADDR16_GET_BAND`
already answers where an address lives, but the first HIMON debug
implementation should prefer a tiny local debug fast path if that saves ROM
bytes. That helper is system-owned policy, not a user-callable routine
contract. Promote it into a shared routine only if multiple system components
need the same rule.

Debug is a HIMON subsystem, not a STR8 layer. A small build may omit the
debug include to save flash, but it must omit the related command records,
help text, BRK debug hook behavior, and any generated docs that claim debugger
support.
NMI trap capture may remain as the operator interrupt/context path even when
breakpoints and `N` stepping are omitted.

## REHASH: RREC Flash Work And Hash Transition

```text
2026
         05
                13
                   17:43Z WLP2 RREC should let RAM flash workers resolve
                               helper routines by hash/routine id across
                               ROM, RAM, and selected flash-bank paths.
```

Future RREC/hashed routine support should make flash/ROM work callable from
RAM without requiring every RAM worker to carry every helper inline.

The intended flow:

```text
build or load a flash/ROM worker into RAM
run the RAM-resident worker
resolve helper calls by routine record / routine id
use the current resolver path
try each configured source in order
fail explicitly if no matching routine is found
```

For a nominal first implementation, the resolver path can be a small fixed
list. The order is policy, not ABI. It may begin with the active ROM/catalog,
or it may prefer a staged RREC block or selected flash-bank page when the
operator or worker explicitly wants newer helper code.

Likely resolver sources:

```text
active ROM/catalog
staged RREC blocks
RAM routine regions
selected flash-bank pages
```

The first promoted helper record seeds are:

```text
RREC PIN_FTDI_INIT
  kind: routine/export
  hash32: $226EDE8F
  hash_sig: 46 4E D6 8F DE 6E 22 00
  entry: PIN_FTDI_INIT
  contract: initialize FTDI VIA pin interface; A preserved
  import: none
  proof: PROVEN, top-shelf 2026-04-18, hash-sig promoted 2026-05-15

RREC PIN_FTDI_READ_BYTE_NONBLOCK
  kind: routine/export
  hash32: $483BB2DD
  hash_sig: 46 4E D6 DD B2 3B 48 00
  entry: PIN_FTDI_READ_BYTE_NONBLOCK
  contract: one FTDI FIFO read check; ready C=1,A=byte; empty C=0,A=$00
  import: none
  proof: PROVEN, top-shelf 2026-04-18, hash-sig promoted 2026-05-15

RREC PIN_FTDI_POLL_RX_READY
  kind: routine/export
  hash32: $F2B69C5B
  hash_sig: 46 4E D6 5B 9C B6 F2 00
  entry: PIN_FTDI_POLL_RX_READY
  contract: one non-consuming RXF# readiness check; C=1 ready, C=0 empty
  import: none
  proof: PROVEN, top-shelf 2026-04-18, hash-sig promoted 2026-05-15

RREC PIN_FTDI_CHECK_ENUMERATED
  kind: routine/export
  hash32: $8A7D53EE
  hash_sig: 46 4E D6 EE 53 7D 8A 00
  entry: PIN_FTDI_CHECK_ENUMERATED
  contract: one PWE# enumeration check; C=1,A=1 enumerated; C=0,A=0 otherwise
  import: none
  proof: PROVEN, top-shelf 2026-04-18, hash-sig promoted 2026-05-15

RREC PIN_FTDI_WRITE_BYTE_NONBLOCK
  kind: routine/export
  hash32: $D55FC6FC
  hash_sig: 46 4E D6 FC C6 5F D5 00
  entry: PIN_FTDI_WRITE_BYTE_NONBLOCK
  contract: one bounded FTDI FIFO write attempt; A preserved, C=1 accepted
  import: none
  proof: PROVEN, top-shelf 2026-04-18, hash-sig promoted 2026-05-15

RREC BIO_FTDI_INIT
  kind: routine/export
  hash32: $30A462F2
  hash_sig: 46 4E D6 F2 62 A4 30 00
  entry: BIO_FTDI_INIT
  contract: initialize FTDI pin interface
  import: PIN_FTDI_INIT
  proof: PROVEN, wrapper promoted 2026-04-19, hash-sig promoted 2026-05-15

RREC BIO_FTDI_CHECK_ENUMERATED
  kind: routine/export
  hash32: $994776E3
  hash_sig: 46 4E D6 E3 76 47 99 00
  entry: BIO_FTDI_CHECK_ENUMERATED
  contract: enumeration state; C=1,A=1 enumerated; C=0,A=0 otherwise
  import: PIN_FTDI_CHECK_ENUMERATED
  proof: WRAPS_PROVEN, wrapper promoted 2026-04-19, hash-sig promoted 2026-05-15

RREC BIO_FTDI_FLUSH_RX
  kind: routine/export
  hash32: $2F6622B9
  hash_sig: 46 4E D6 B9 22 66 2F 00
  entry: BIO_FTDI_FLUSH_RX
  contract: bounded consuming RX drain; C=1 empty; C=0 guard expired
  import: PIN_FTDI_READ_BYTE_NONBLOCK
  proof: PROVEN, bounded drain 2026-05-07, hash-sig promoted 2026-05-15

RREC BIO_FTDI_GET_CTRL_C
  kind: routine/export
  hash32: $426150D2
  hash_sig: 46 4E D6 D2 50 61 42 00
  entry: BIO_FTDI_GET_CTRL_C
  contract: consuming nonblocking Ctrl-C detector; C=1,A=$03 when consumed
  import: PIN_FTDI_READ_BYTE_NONBLOCK
  proof: USED, long-scan abort poll, hash-sig promoted 2026-05-15

RREC BIO_FTDI_READ_BYTE_BLOCK
  kind: routine/export
  hash32: $20285B85
  hash_sig: 46 4E D6 85 5B 28 20 00
  entry: BIO_FTDI_READ_BYTE_BLOCK
  contract: unbounded blocking FTDI byte read; out C=1,A=byte
  import: PIN_FTDI_READ_BYTE_NONBLOCK
  proof: PROVEN, promoted 2026-05-15

RREC BIO_FTDI_WRITE_BYTE_BLOCK
  kind: routine/export
  hash32: $379FE930
  hash_sig: 46 4E D6 30 E9 9F 37 00
  entry: BIO_FTDI_WRITE_BYTE_BLOCK
  contract: unbounded blocking FTDI byte write; in A=byte, out C=1,A preserved
  import: PIN_FTDI_WRITE_BYTE_NONBLOCK
  proof: PROVEN, promoted 2026-05-15

RREC UTL_HEX_NIBBLE_TO_ASCII
  kind: routine/export
  hash32: $D4C88B87
  hash_sig: 46 4E D6 87 8B C8 D4 00
  entry: UTL_HEX_NIBBLE_TO_ASCII
  contract: encode low nibble in A as uppercase ASCII hex; out C=1
  import: none
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15

RREC UTL_HEX_BYTE_TO_ASCII_YX
  kind: routine/export
  hash32: $7142DD21
  hash_sig: 46 4E D6 21 DD 42 71 00
  entry: UTL_HEX_BYTE_TO_ASCII_YX
  contract: encode A as two uppercase ASCII hex chars; A preserved, Y/X output
  import: UTL_HEX_NIBBLE_TO_ASCII
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15

RREC UTL_HEX_ASCII_TO_NIBBLE
  kind: routine/export
  hash32: $ADD714B1
  hash_sig: 46 4E D6 B1 14 D7 AD 00
  entry: UTL_HEX_ASCII_TO_NIBBLE
  contract: parse ASCII hex char; valid C=1,A=0..15; invalid C=0,A unchanged
  import: none
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15

RREC UTL_HEX_ASCII_YX_TO_BYTE
  kind: routine/export
  hash32: $EA0B3E6D
  hash_sig: 46 4E D6 6D 3E 0B EA 00
  entry: UTL_HEX_ASCII_YX_TO_BYTE
  contract: parse Y/X ASCII hex pair into A; valid C=1,A=byte; invalid C=0
  import: UTL_HEX_ASCII_TO_NIBBLE
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15
```

The hash sigs are now emitted immediately before their routine entries:
`PIN_FTDI_INIT_FNV`, `PIN_FTDI_POLL_RX_READY_FNV`,
`PIN_FTDI_READ_BYTE_NONBLOCK_FNV`, `PIN_FTDI_WRITE_BYTE_NONBLOCK_FNV`,
`PIN_FTDI_CHECK_ENUMERATED_FNV`, `BIO_FTDI_INIT_FNV`,
`BIO_FTDI_CHECK_ENUMERATED_FNV`, `BIO_FTDI_FLUSH_RX_FNV`,
`BIO_FTDI_GET_CTRL_C_FNV`, `BIO_FTDI_READ_BYTE_BLOCK_FNV`,
`BIO_FTDI_WRITE_BYTE_BLOCK_FNV`,
`UTL_HEX_NIBBLE_TO_ASCII_FNV`, `UTL_HEX_BYTE_TO_ASCII_YX_FNV`,
`UTL_HEX_ASCII_TO_NIBBLE_FNV`, and `UTL_HEX_ASCII_YX_TO_BYTE_FNV`. The fuller
RREC records are still conceptual until RCAT/RREC bytes and lookup policy exist.
Their job now is to keep the promoted routines from being just loose labels in
ROM. Future RAM workers should be able to ask for these contracts by record
identity instead of carrying private copies of the same receive/transmit loops.

Longer term, the search order should be selectable at runtime or carried as
part of the worker/session policy. The important V0 rule is simple: resolve
predictably, search only named sources, and fail explicitly when no helper is
found.

Resolving a helper in ROM means "call it as opaque ROM code." It does not make
that ROM address debug-patchable. The RAM-only debug edict still applies.

FNV-1a solved immediate command and routine lookup, but it is now transition
debt rather than a permanent promise. Its math is expensive for small W65C02
code. RREC should leave room for a cheaper resolver hash or routine-id scheme.

Candidates under investigation:

```text
eorrot
8-8-16 hash partitioning
other compact routine-id layouts if they prove smaller and easier to verify
```

## REHASH: Command Safety

```text
2026
         05
                12
                   02:33Z WLP2 Destructive commands require 4+ chars;
                               current short destructive/proof commands
                               are transition debt.
```

Examples of future destructive command spellings:

```text
COPY start end|+count dest
FILL start end|+count byte
MOVE start end|+count dest
FLASH ...
BANK ...
ERASE ...
```

## REHASH: HIMON Range Syntax

```text
2026
         05
                12
                   02:33Z WLP2 HIMON range syntax targets inclusive
                               `start end` plus explicit `start +count`.
```

The target range grammar is:

```text
start end       end is inclusive
start +count    count is the number of bytes
```

Short end tokens inherit the high byte from `start` when that is safe. Common
page-local display stays terse while true counts remain explicit. Use `+count`
only when the operator means a byte count. If a short inherited end would land
before `start`, use a full end address or `+count`.

```text
D 100 3      dump $0100-$0103
D 3000 FF    dump $3000-$30FF
D 3000 +100  dump $3000-$30FF
```

Bare `D` should repeat the previous dump length from the byte after the
previous dump:

```text
D 3000 FF
D            dump $3100-$31FF
```

## REHASH: Search And Step

```text
2026
         05
                15
                   03:48Z WLP2 Resident HIMON no longer accepts `S` as
                               step. `N` is the step command; `S` is reserved
                               for search through the FNV command path.
                12
                   02:33Z WLP2 `S` moves from single-step to memory
                               search; step/next moves to `N` only.
```

`NEXT` is not a command alias in the resident surface. RAM-only `N` is
non-destructive because it plants only a temporary debugger trap in RAM and
restores the original opcode.

Target search syntax is:

```text
S addr end|+count b0 [b1 ...]
S addr end|+count b0 [b1 ...] 'TEXT
S addr end|+count 'TEXT
```

Hex byte tokens are the default pattern. Apostrophe text is a final V0 tail:
it consumes the rest of the command line. There is no closing-quote parser and
no return to hex parsing after text.

```text
S 0 FFFF 4D 4D 'M
```

That searches for three `M` bytes.

## FLASHBACK: Search Display

```text
2026
         05
                12
                   02:33Z WLP2 Search hits print like D-style context
                               rows: exact hit first, aligned display
                               row second.
```

A hit is immediately inspectable without running a separate `D` command. This
keeps the useful BSO2 monitor search-display convention while making it part
of HIMON's command language. `*` marks a match that continues into the next
16-byte display row.

```text
B88F B880: ...
022B*0220: ...
```

The first word is the exact hit address. The second word is the aligned dump
row.

## FLASHBACK: HBSTR Search

```text
2026
         05
                12
                   02:33Z WLP2 Ctrl-letter high-bit-string search remains
                               a design note; V0 search input stays
                               printable.
```

For V0, an operator can use hex for the high-bit terminator or search a useful
partial. A future printable HBSTR form remains possible:

```text
S 0 FFFF `HIMON
```

That would mean `H I M O (N|$80)`.
