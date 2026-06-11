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

## REHASH: Flash ASM Enters The World

```text
2026
         06
                10
                   21:59Z WLP2 ASM is now a flash-resident HIMON command:
                               L F loads it at $8000, # can find its FNV
                               record, and `ASM` enters the assembler.
```

The current image is:

```text
SRC/BUILD/s19/asm-v1-flash-8000.s19
FNV command hash: $56AD7400 for ASM
entry:            $800C
S19 range:        $8000-$AD6A
expected load:    LF OK WR=2D6B GO=800C
```

The board proof loaded the fixed-address flash image with `L F`, entered it
with the HIMON command `ASM`, pasted:

```text
DOC/GUIDES/ASM/SAMPLES/biorhythm-2000.asm
```

and assembled it successfully:

```text
ASM>         END
OK PC=$2640
ASM TABLES
...
ASM FLASH OK
```

Running the emitted program at `$2000` produced the biorhythm-style chart and
returned to HIMON on `Q`:

```text
>G 2000

BIORHYTHM
DAY 0-255 OR Q> 172

DAY $AC
P 0 ...........*...........
E + ....*.........|.............
I + .......*........|................
...
DAY 0-255 OR Q> Q

BYE
```

What changed in the command surface:

```text
ASM      now names a flash-resident assembler image
L F      can deliver that fixed-address image into blank $8000+ flash
RJOIN    lets emitted code call resident routines by name
K05      executable+text records are now practical service names
```

Strengths right now:

```text
interactive paste assembly
bare RAM program output at $2000+
local labels and forward fixups
session symbol/fixup tables
resident JSR/JMP lookup through HIMON/THE
hardware-proven real-work samples, not only byte or opcode smoke tests
```

Current limitations:

```text
fixed-address flash image; no L F erase, auto-place, or relocation yet
ASM metadata still uses the current RAM arena, not the final $7DFF-down plan
fixed tables: 32 globals, 32 fixups, 64 refs, 8 locals per global scope
63 visible input chars per line
no macros/includes/general forward expression addends yet
source layout still matters; monotonic ORG is enforced
resident lookup is direct-name JSR/JMP only in the current policy
```

This is the public shape of the next loop:

```text
STR8 -> HIMON -> ASM -> emitted RAM program
```

ASM programs do not need FNV headers unless they are deliberately exported
or sealed later. The runtime has the hash identity; the ordinary output path
stays plain opcodes.

The important failure lesson from the same slice: `BAD FIX` does not always
mean "fixup table full." A helper-first biorhythm attempt had only 19/24
fixups but failed because the older image only tried resident lookup for
`JSR name`; `JMP BIO_FTDI_*` tail wrappers stayed pending. Current ASM raises
the fixup limit to 32 rows and resolves direct resident `JMP name` as well as
`JSR name`.

Full transcripts live in
[HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md). The flash migration plan is
[ASM/FLASH_8000_GAME_PLAN.md](ASM/FLASH_8000_GAME_PLAN.md), and the current
board script is
[ASM/SAMPLES/biorhythm-2000-test.md](ASM/SAMPLES/biorhythm-2000-test.md).

## REHASH: Pasteable ASM Runs Interactive Life

```text
2026
         06
                09
                   05:24Z WLP2 ASM RT PASTE now assembles and runs the
                               interactive 8x8 Life sample on hardware.
```

The public sample is:

```text
DOC/GUIDES/ASM/SAMPLES/life-rjoined-6800.asm
```

Load the current ASM runtime paste image at `$2000`, paste the source, then run
`G 6800`. The hardware-proven runtime size for the original slice was:

```text
L OK=3CB1 GO=2000
```

The sample uses RJOIN-resolved resident `BIO_FTDI_WRITE_BYTE_BLOCK` and
`PIN_FTDI_READ_BYTE_NONBLOCK`, emits code at `$6800`, keeps the visible Life
board at `$7800`, and uses precomputed neighbor tables at `$7000-$71FF`.

Controls:

```text
N or space   next generation
R            random board
Q            return to HIMON
```

The same proof also fixed the 16-row fixup-name table boundary: slot 8 now
stays distinct from slot 0, so the top `JMP MAIN` fixup no longer gets its
name overwritten by the later `R8S` branch fixup. Full board transcript is in
[HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md), and acceptance notes are in
[ASM/TEST_PLAN.md](ASM/TEST_PLAN.md).

## REHASH: ASM EQU/ORG Expressions Gain Resolved +/- Math

```text
2026
         06
                09
                   02:15Z WLP2 ASM_PARSE_EXPR now resolves known symbols and
                               concrete + / - expression chains for EQU/ORG.
```

Current ASM v1 expression math is intentionally narrow:

```text
X EQU $0001
Y EQU X+1
SIZE EQU END_ADDR-START_ADDR
ORG $7000+16
```

`ADDR + VALUE`, `VALUE + ADDR`, and `ADDR - VALUE` keep address width and range
check it. `ADDR - ADDR` returns a scalar `VALUE` delta. Unknown compound
expressions such as `FOO+1` are still rejected until fixup addends or forward
`EQU` dependency solving exist.

Raw instruction operands and DB/DS lists still use their existing atom parsers;
stage operand math through an `EQU` for now, then use the resolved symbol.

## REHASH: Current HIMON K Bits And Catalog-Linking Direction

```text
2026
         05
                20
                   03:49Z WLP2 Updated the current HIMON FNV K byte: bit 0 is
                               executable/callable, bit 1 is confirm before
                               execution, and K=$03 records carry ENTRY plus
                               display EXTRA.
```

Current HIMON FNV-era records use:

```text
K=$00  described/known, not directly executable by current dispatch
K=$01  executable/callable
K=$03  executable/callable and confirm before execution
```

Working description: HIMON/THE is a ROM-resident hash dictionary for 65C02
services, with Forth instincts and assembler bones.

The resident `#` command can list all records or filter by maximum K value:

```text
#         list every visible FNV record
# K=hh    list records whose K byte equals hex hh
# K<hh    list records whose K byte is less than hex hh
# K>hh    list records whose K byte is greater than hex hh
```

For K=$03, the current payload is:

```text
DW ENTRY
DW EXTRA
```

`ENTRY` is the callable address. `EXTRA` is side information: currently an
optional HBSTR for `#` display and confirm prompts. `EXTRA` is not an alias,
not a second command name, and not automatically passed to the called routine.

The text pointer is a display/prompt field, not a typed-name alias. If an alias
is ever wanted, it must be a deliberate second record with its own hash. The
current reset exports are only `BOOT_COLD_RESET` and `BOOT_WARM_RESET`.

Catalog linking follows imports recursively. A user choosing a low-level input
provider such as `PIN_READ_BYTE_NB` should flash only the PIN-level body. A user
choosing a higher-level service such as `BIO_READ_CHAR_NB` or
`SYS_READ_CHAR_NB` should pull that service plus its declared dependencies down
through BIO/COR/PIN records, then apply fixups.

Bits 2 and 3 of the current K byte are reserved. Do not use them yet as
selectors, permissions, lifecycle flags, or dependency-policy flags. Those may
become useful later, but they need a real record/control-byte design before they
earn scarce bit positions.

Future records that need callable input or output should use a documented
record shape, not reinterpret `EXTRA`:

```text
K=$11  DW ENTRY, DW PARMS
K=$12  DW ENTRY, DW PARMS, DW RESULTS
```

`PARMS` can point at a string, token stream, command list, import list, or typed
parameter block. `RESULTS` can point at a writable result buffer or result
descriptor. HIMON/THE must define the calling convention for each future kind.

## REHASH: HIMON Visible Version Uses Current Date

```text
2026
         05
                19
                   22:26  WLP2 Added a build-time HIMON version stamp so each
                               HIMON rebuild updates the visible
                               HIMON V 00.MMDD(HHMM) text before assembly.
                   19:42Z WLP2 Added THE_JOIN_FIND as HIMON's first internal
                               join hook; # token used it for lookup while
                               command dispatch was still K=$00-only.
                   19:30Z WLP2 Corrected the HBSTR terminator so the closing
                               parenthesis prints.
                   19:26Z WLP2 HIMON visible text became
                               HIMON V 00.0519(1925), and the then-current
                               K=$10 HIMON record pointed at the same text.
                   19:23Z WLP2 HIMON ROM then contained one resident K=$10
                               FNV record for HIMON, pointing at START and
                               EXTRA text HIMON V 00.0519.
                   19:00Z WLP2 HIMON cold boot now reports V 00.0519,
                               derived from the current update date.
```

Visible HIMON/STR8 version text is build-stamped from local time before HIMON
assembly. The source stores the final `)` as the HB-string high-bit terminator,
so the quoted bytes intentionally stop before that character.

The build format is:

```text
HIMON V 00.MMDD(HHMM)
```

## REHASH: Historical HIMON # K10 EXTRA Text

```text
2026
         05
                19
                   18:58Z WLP2 HIMON # then understood FNV K=$10
                               pointer records well enough to print a
                               nonzero DW EXTRA HBSTR at the end of the row.
```

This was the short-lived pointer-record step before the current K-bit contract
above. At that point, `#` kept old `K=$00` records quiet and, for a `K=$10`
record, read:

```text
DW ENTRY
DW EXTRA
```

The current replacement is K=$03 for confirmed executable pointer records:
`DW ENTRY`, `DW EXTRA`.

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

The hash-policy truth changed again after the CRC16 pivot. Existing HIMON
command records and the quoted helper carry FNV-era behavior, and FNV-1a32 is
now the settled public name hash for commands, exported routines, symbols, and
cross-bank imports. CRC16 remains useful for compact local/scoped tables and
checks. CRC32 is an integrity/check candidate, not normal lookup identity.

Do not write new public docs as though tableless CRC16 replaces every public
name. Say "FNV32 public identity" for exported/cross-boundary names and
"CRC16 compact local/check" for bounded record contexts.

See [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) for the three-image operator
path and [DECISIONS.md](./DECISIONS.md), [HASH.md](HASH/HASH.md), and
[HASH_MAP.md](HASH/HASH_MAP.md) for the settled hash split.

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
  hash_sig: 46 4E D6 85 5B 28 20 05
  record: K05 EXEC+TEXT
  entry: BIO_FTDI_READ_BYTE_BLOCK
  text: READ BYTE
  contract: unbounded blocking FTDI byte read; out C=1,A=byte
  import: PIN_FTDI_READ_BYTE_NONBLOCK
  proof: PROVEN, promoted 2026-05-15; K05 text promoted 2026-06-10

RREC BIO_FTDI_WRITE_BYTE_BLOCK
  kind: routine/export
  hash32: $379FE930
  hash_sig: 46 4E D6 30 E9 9F 37 05
  record: K05 EXEC+TEXT
  entry: BIO_FTDI_WRITE_BYTE_BLOCK
  text: WRITE BYTE
  contract: unbounded blocking FTDI byte write; in A=byte, out C=1,A preserved
  import: PIN_FTDI_WRITE_BYTE_NONBLOCK
  proof: PROVEN, promoted 2026-05-15; K05 text promoted 2026-06-10

RREC UTL_HEX_NIBBLE_TO_ASCII
  kind: routine/export
  hash32: $D4C88B87
  hash_sig: 46 4E D6 87 8B C8 D4 05
  record: K05 EXEC+TEXT
  entry: UTL_HEX_NIBBLE_TO_ASCII
  text: NIB HEX
  contract: encode low nibble in A as uppercase ASCII hex; out C=1
  import: none
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15; K05 text promoted 2026-06-10

RREC UTL_HEX_BYTE_TO_ASCII_YX
  kind: routine/export
  hash32: $7142DD21
  hash_sig: 46 4E D6 21 DD 42 71 05
  record: K05 EXEC+TEXT
  entry: UTL_HEX_BYTE_TO_ASCII_YX
  text: BYTE HEX
  contract: encode A as two uppercase ASCII hex chars; A preserved, Y/X output
  import: UTL_HEX_NIBBLE_TO_ASCII
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15; K05 text promoted 2026-06-10

RREC UTL_HEX_ASCII_TO_NIBBLE
  kind: routine/export
  hash32: $ADD714B1
  hash_sig: 46 4E D6 B1 14 D7 AD 05
  record: K05 EXEC+TEXT
  entry: UTL_HEX_ASCII_TO_NIBBLE
  text: HEX NIB
  contract: parse ASCII hex char; valid C=1,A=0..15; invalid C=0,A unchanged
  import: none
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15; K05 text promoted 2026-06-10

RREC UTL_HEX_ASCII_YX_TO_BYTE
  kind: routine/export
  hash32: $EA0B3E6D
  hash_sig: 46 4E D6 6D 3E 0B EA 05
  record: K05 EXEC+TEXT
  entry: UTL_HEX_ASCII_YX_TO_BYTE
  text: HEX BYTE
  contract: parse Y/X ASCII hex pair into A; valid C=1,A=byte; invalid C=0
  import: UTL_HEX_ASCII_TO_NIBBLE
  proof: PROVEN, reviewed and hash-sig promoted 2026-05-15; K05 text promoted 2026-06-10
```

The promoted records are now a mixed but explicit set. Older K01 EXEC-only
records still sit immediately before their routine entries. The selected BIO
block and UTL hex rows above use K05 EXEC+TEXT: the eight-byte FNV signature
ends in `$05`, followed by `DW entry` and `DW text` before the routine body.
The `_FNV` label is the record start, not the callable address:
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

FNV-1a solved immediate command and routine lookup, and FNV-1a32 is now the
settled public identity for names that cross boundaries. Its math is still
expensive for tiny W65C02 paths, so `RR`/`RC` internals should leave room for
CRC16, short IDs, or indexes where the enclosing record context handles
collisions.

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
