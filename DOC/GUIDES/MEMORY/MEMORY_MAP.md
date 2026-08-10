# R-YORS Memory Map

This is the easy-to-find memory map for the current HIMON ROM build and
the RAM workspace it uses.

For the bench-facing names and layered diagrams of the active control areas,
see [Control Deck Map](../../GENERATED/CONTROL_DECK_MAP.md). The formal ranges
in this file remain authoritative.

The standalone HIMON map and the primary split-V1.02 combined-image map are
listed separately below. The combined image is the normal board baseline;
standalone `himon-rom` remains useful for component builds and proofs.

## Current HIMON ROM Image

Ranges are listed as inclusive. Linker `_END_*` symbols are exclusive.

```text
$8000-$BFFF   current image gap
$C000-$E97D   HIMON CODE, START/standalone RESET entry at $C000
$E97E-$EEFF   HIMON DATA
$EF00-$FFF9   current image gap and STR8/high-ROM space
$FFFA-$FFFF   hardware vectors
```

The HIMON entry face has a fixed warm-entry identity contract independent of
the rest of the generated map:

```text
$C000-$C002   JMP to the current HIMON start body
$C003-$C006   HIMON warm ABI marker: A5 5A C3 3C
```

STR8 `H` matches all four marker bytes before it writes the same four-byte
warm signature at `$7EE6-$7EE9` and enters `$C000`. An absent or damaged
marker is not a generic `$C000` launch: STR8 prints `NO HIMON` and stays active.

The legacy HIMONIA fixed entries at `$F00D`, `$FADE`, and `$FEED` have been
removed. They were useful as a proof, but not a practical permanent ABI. Local
language bridges should patch against the current HIMON map or use a future
explicit handoff contract; STR8 must not reserve those addresses.

Current ROM hardware vectors:

```text
$FFFA-$FFFB   NMI   = $E680
$FFFC-$FFFD   RESET = $C000
$FFFE-$FFFF   IRQ   = $E683
```

Generated burnable ROM `.bin` files are exactly one 32K `$8000-$FFFF` bank
image for the programmer workflow. The file does not encode a bank number;
bank 0-3 placement is managed through the T48 programmer or through
R-YORS/STR8.

## Target Live-Bank Budget

This is a target boundary, not a panic rule:

```text
$8000-$BFFF   16K low-flash code/data, currently ASM-F2 plus headroom
$C000-$EFFF   12K HIMON monitor/tools budget
$F000-$FFFF    4K STR8 recovery-owned erase sector
```

STR8 may use less than 4K, but the whole `$F000-$FFFF` erase sector is
recovery-owned because erase granularity and the hardware vectors make it the
dangerous top sector. HIMON should fit below `$F000`; if it outgrows 12K, that
should be an intentional design decision because it eats the lower 16K user
space.

The primary combined image is `BUILD/bin/himon-str8-rom.bin`: ASM-F2 starts at
CPU `$8000` / file offset `$0000`, HIMON starts at CPU `$C000` / file offset
`$4000`, STR8 starts at CPU `$F000` / file offset `$7000`, the STR8 RAM worker
source is the jump-only image at CPU `$FF1F` / file offset `$7F1F`, copied into
the `$0200-$0290` portion of the RAM worker-code tray, and all live hardware
vectors enter the STR8-owned top sector. RESET points to STR8 at `$F000`; NMI
and IRQ/BRK point to STR8 IVI stubs at `$F09C`/`$F0B0`, which dispatch through
the RAM vector cells. Destructive `I` transactions upload their exact mutation
worker to `$0200-$042A`; it is not resident in the top sector.

Combined image layout:

```text
$8000-$BC6C   ASM-F2 low-flash image, entry $800C
$BC6D-$BFFF   current low-flash growth/AP-store hole; no reporter AP in Bank 3
$C000-$EEFF   HIMON body, including resident AP import linker
$EF00-$EFFF   current image gap inside the E sector
$F000-$FE5C   STR8 V1.02 resident shell, IVI stubs, record service, and installer
$FE5D-$FF1E   free/reserve gap, $00C2 bytes: $0040 reserve + $0082 growth
$FF1F-$FFAF   jump-only STR8 RAM-worker source, copied to $0200-$0290
$FFB0-$FFEF   fixed V1 directory, erased in a new primary image
$FFF0-$FFF9   STR8 config pocket
$FFFA-$FFFF   hardware vectors
```

## Current Opaque-Bank J Layout

The accepted `J0`-`J3` path treats Banks 0-2 as unrelated 32K systems:

```text
$8000-$FFFF   opaque bank-owned system image, including its own vectors
```

Bank selection and selected-bank reset-vector entry must run from RAM because
the whole `$8000-$FFFF` flash window changes banks. Guest code cannot call
Bank-3-only HIMON/RJOIN addresses while another bank is selected.

Bank 3 remains different: physical reset and timeout enter its STR8 supervisor,
whose current layout is listed above. Banks 0-2 reserve no STR8 top sector,
Boot Passport Block, shared service entries, or other fixed bytes. Their
`$F000-$FFFF` content may be STR8, WOZMON, another monitor, or unrelated
system code. See
[STR8_J012_OPAQUE_BANK_PLAN.md](../PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md).

Physical-reset visibility does not imply a readable `$EE` PCR pattern. The
board pull-ups may expose Bank 3 while `$7FEC & $EE` remains `$00` in VIA
reset/input mode. Only a successful software selection establishes the
canonical `$CC/$CE/$EC/$EE` patterns. Treat raw PCR `$00` as undecoded, not as
evidence that Bank 3 is absent.

## OIL Address Boundary

OIL keeps an AP Capsule (APC) in storage separate from its executable BODY:

```text
AP Capsule in RAM, visible flash, or banked flash
  -> stage and parse (banked flash uses the SSD at $0A00-$19FF)
  -> load BODY into the AIR at $2000-$4FFF
  -> apply relocation and resident imports
  -> run the entry from RAM
```

A banked AP is staged one 4K sector at a time; it is not executed directly
from the banked flash window.

Local language images are built to sit below the protected HIMON/STR8 region:

```text
$8000-$9FFF   OSI MS BASIC 8K slot, FNV header at $8000
$A000-$BFFF   fig-Forth slot, FNV header at $A000
$C000-$FFFF   protected live HIMON/STR8 region
```

These are still proof/load artifacts. They are not yet packaged as a safe
erase/rewrite `L F` update flow.

STR8 bench tests may temporarily place fig-Forth at `$C000-$EFFF` with
`BUILD/s19/fig-forth-str8-update.s19`. That is not the normal memory map; it is
a deliberate replacement of the HIMON payload through STR8 `U`, with STR8 still
resident at `$F000-$FFFF`.

The same temporary replacement exists for OSI MS BASIC at `$C000-$EFFF` with
`BUILD/s19/msbasic-osi-str8-update.s19`. It is also a STR8 `U` payload, not the
normal combined monitor map.

## Flash Window Mapping

The VIA-controlled bank pins change only the upper 32K flash view:

```text
$0000-$7FFF  unchanged RAM/IO space
$8000-$FFFF  selected flash window
```

Physical flash banks map into that same CPU window:

```text
bank 0  physical $00000-$07FFF -> CPU $8000-$FFFF
bank 1  physical $08000-$0FFFF -> CPU $8000-$FFFF
bank 2  physical $10000-$17FFF -> CPU $8000-$FFFF
bank 3  physical $18000-$1FFFF -> CPU $8000-$FFFF, pull-up/reset default
```

Use `FLSH_*` for window selection/query and `FLASH_*` for operations on the
currently selected `$8000-$FFFF` window. A ROM-resident HIMON command must not
park itself in bank 0-2 while continuing to execute from `$C000`; it should use a
RAM worker that selects the requested bank, copies or checks bytes, then restores
bank 3 before HIMON prints or returns to normal command flow.

## Current Flash Policy

HIMON treats flash as `$8000-$FFFF`, but the current `L F` writer remains a
conservative blank-write path, not a sector updater. Its guard protects the
current HIMON/STR8 live region at `$C000+`:

```text
$8000-$BFFF   currently allowed by L F only if old byte is $FF
$C000-$FFFF   protected HIMON/STR8 region
$F000-$FFFF   STR8 top sector, config, and vectors
```

Current `L F` behavior:

```text
target below $8000   protected
target $8000-$BFFF   currently allowed only if old byte is $FF
target $C000+        currently protected
```

There is no sector erase/condense path in HIMON. STR8 V1.02 owns selected-bank
erase, program, verify, and journal flows through its `I` transaction and the
exact mutation worker carried by the input stream.

## Current RAM Map

The current source header states:

```text
$0000-$7EFF   monitor-managed RAM region
$7F00-$7FFF   I/O
$8000-$FFFF   flash
```

Current RAM ownership:

```text
$0000-$00AF   zero page user/free while running; STR8 I transiently owns $0090-$00A0
$00B0-$00CA   reserved R-YORS/HIMON/THE/ASM ZP expansion
$00CB-$00CC   CRC16 no-table state, low/high; allocated from high end downward
$00CD-$00D9   flash helper workspace, active during flash operations
$00DA-$00DC   reserved expansion bytes inside flash/extended ZP window
$00DD-$00DF   bank/length sideband bytes, reserved shared ZP
$00E0-$00E5   shared 16-bit parameter lanes; $E0-$E1 also command hash pointer
$00E6-$00E7   shared utility temp/scratch bytes
$00E8-$00EF   shared pointer/length/flags/mode lane for FTDI/SYS/string helpers
$00F0-$00FF   monitor/parser hot zero-page window
$0100-$01FF   hardware stack; HIMON owns this on monitor entry
$0200-$09FF   LRS: SNL during ASM, WCT during STR8 flash work
$0A00-$19FF   LRS: FNL during ASM, SSD during STR8 flash work
$1A00-$1FE8   RJOIN/link debug trace and reserved low-RAM scratch
$1B00-$1B0F   FTC used by interactive flash APs
$1C00-$1CFE   CID used by interactive flash APs
$1FE9-$1FFF   RSC: STR8 worker/update state
$2000-$4FFF   AIR: Build Bay, Envelope Bay, and Run/Tray Bay
$5000-$61A9   AWH: flash ASM UDATA
$61AA-$79FF   SOD: safe upper output/scratch
$7A00-$7AFF   VOD: command buffer and volatile monitor scratch
$7B00-$7BFB   RPT: validated-record decoded payload tray (252 bytes)
$7BFC-$7DFF   VOD: remaining volatile monitor scratch
$7E00-$7E01   HIMON-published RJOIN addr16 (`THE_JOIN_EXEC_XY`)
$7E02-$7E1C   HIMON resident service vector block + checksum
$7E1D-$7E1E   HIMON RX lookahead
$7E1F-$7E22   optional PACK40 service vectors
$7E23-$7E24   AP import record pointer after package parse
$7E25-$7E2C   optional flash-install service vector/request cells
$7E2D-$7E40   optional AP package service vector/request/result cells
$7E41-$7E45   AP package service scratch
$7E46-$7E65   debugger / assembler workspace
$7E66-$7E75   FNV hash and command-exec metadata
$7E76-$7E94   command/parser/keytest workspace
$7E95-$7EA8   RTC: STR8 validated-record request/result card
$7EA9-$7EDD   HSD loader workspace and range table
$7EDE-$7EDF   delay helper fixed RAM
$7EE0-$7EE5   PIA state / lock
$7EE6-$7EE9   reset signature
$7EEA-$7EEC   trap cause / BRK signature / NMI debounce
$7EED-$7EEF   IVI vector-table signature bytes, ASCII "IVY"
$7EF0-$7EF7   NMI context capture
$7EF8-$7EFF   RAM vectors
$7F00-$7FFF   IOB: side-effectful I/O window
```

The LRS is a switchyard, not two permanent data stores. The `$0A00-$19FF` SSD
is retained staging, not an execution region. It can hold a complete
flash-sector mirror/update image or a banked AP Capsule copied from banks 0-2.
AP BODY bytes execute only after the AP loader relocates/links them into the
requested AIR load address, currently inside `$2000-$4FFF`.

The RPT and RTC are a second, smaller handoff pair: STR8's Record Frontdoor
(`$F009-$F00F`) parses an S19 record into the RPT and publishes its descriptor
in the RTC. They are volatile service areas, not ordinary application buffers;
follow the Transit Rule in the [glossary](../GLOSSARY.md) before calling the
record `APPLY_LF` operation.

The UPA is also the natural first tray for future RREC-loaded commands. A
CP/M-like convention such as `LOAD @6000 <hash>` can copy a banked RREC payload
into RAM, apply relocation/fixups there, restore the normal flash bank, then run
from `$6000 + entry_offset`. This keeps banked flash as storage first and avoids
duplicating HIMON/STR8 helper code across banks. The fixed `@6000` tray is a
convention proposal, not a current HIMON allocator.

The `$7F00-$7FFF` I/O window is decoded as eight `$20`-byte slots on the
current board. HIMON `D` and flash-resident `S` treat the whole page as
side-effectful I/O: they print slot labels and skip the addresses instead of
reading device registers.

```text
$7F00-$7F1F   CS0 / expansion or unused
$7F20-$7F3F   CS1 / expansion or unused
$7F40-$7F5F   CS2 / expansion or unused
$7F60-$7F7F   CS3 / expansion or unused
$7F80-$7F9F   ACIA
$7FA0-$7FBF   PIA
$7FC0-$7FDF   VIA
$7FE0-$7FFF   FTDI VIA
```

During destructive STR8 `B`, `0`, `1`, and `2` operations, STR8 owns the WCT
at `$0200-$09FF` and the current AIR Run/Tray Bay `$4000-$4FFF` sector buffer
used by those implemented paths. The current worker copy is exact-length inside
the WCT, but normal HIMON/user code should treat the whole tray as volatile
while STR8 is performing flash work. During `U`, STR8 also uses
`$5000-$6FFF` so it can stage all three HIMON sectors before the first erase.
The SSD is `$0A00-$19FF`; consolidating older high-RAM staging into that deck
is future implementation work.

STR8 also uses the RSC at `$1FE9-$1FFF` for bank/sector copy state, failure
address reporting, startup flags, and update state. `J0`-`J3` use
`$1FF2-$1FF5` for target bank, reset-vector low/high, and handoff status.

During a foreground STR8 `I` recovery transaction, `$0090-$00A0` is a
17-byte persistent installer frame. It survives RAM-worker calls because the
worker owns only `$00CD-$00D6`. Outside `I`, the frame returns to the normal
`$0000-$00AF` user/free policy.

The published Bank Jump Record occupies the RSC tail:

| Address | Symbol | Published value |
| ---: | --- | --- |
| `$1FFD` | `STR8_BANK_JUMP_SIG0` | `$42` (`B`) |
| `$1FFE` | `STR8_BANK_JUMP_SIG1` | `$4A` (`J`) |
| `$1FFF` | `STR8_BANK_LAST_JUMP` | last validated target bank `0`-`3`, or `$FF` |

The RAM worker commits the signed record after selecting the target and
validating its reset vector, immediately before the final jump. HIMON cold
start preserves a valid record through RAM clearing and republishes `42 4A FF`
when no valid target is available. Thus `D 1FFD 1FFF` reports the bank selected
for the preceding successful STR8 handoff rather than the Bank 3 selection
that is live after returning to HIMON.

The `$1A00-$1FE8` reserved range is the preferred future home for a compact
hash/RJOIN debug stack. That stack should be a breadcrumb trace for dynamic
join/load/fixup failures, not the CPU stack and not required for normal success
paths.

Current high-RAM vectors:

```text
$7EF8-$7EF9   reset vector target
$7EFA-$7EFB   NMI vector target
$7EFC-$7EFD   IRQ/BRK vector target
$7EFE-$7EFF   IRQ non-BRK vector target
```

Current zero-page detail:

```text
$00-$8F   user/free while running
$90-$A0   user/free normally; transient STR8 I installer state during recovery
$A1-$AF   user/free while running
$B0-$CA   reserved for future R-YORS/HIMON/THE/ASM zero-page expansion;
          possible active pointer lanes and addressing-mode workspace
$CB        CRC16_LO
$CC        CRC16_HI

$CD        FLASH_ADDR_LO
$CE        FLASH_ADDR_HI
$CF        FLASH_DATA
$D0        FLASH_OP
$D1        FLASH_TMO0
$D2        FLASH_TMO1
$D3        FLASH_TMO2
$D4        FLASH_COPY_SRC_LO
$D5        FLASH_COPY_SRC_HI
$D6        FLASH_COPY_DST_LO
$D7        FLASH_COPY_DST_HI
$D8        FLASH_COPY_LEN_LO
$D9        FLASH_COPY_LEN_HI
$DA-$DC   reserved in the extended flash/ZP window

$DD        LEN_ADDR_BANK, reserved sideband
$DE        END_ADDR_BANK, reserved sideband
$DF        START_ADDR_BANK, reserved sideband

$E0        START_ADDR16_LO / CMD_HASH_TAB_LO
$E1        START_ADDR16_HI / CMD_HASH_TAB_HI
$E2        END_ADDR16_LO
$E3        END_ADDR16_HI
$E4        LEN_ADDR16_LO
$E5        LEN_ADDR16_HI
$E6        ZP_TMP_A / utility conversion temp
$E7        ZP_SCRATCH0 / string helper needle/current byte
$E8        ZP_SHARED_PTR_LO / FTDI/SYS/string pointer low
$E9        ZP_SHARED_PTR_HI / FTDI/SYS/string pointer high
$EA        ZP_SHARED_LEN
$EB        ZP_SHARED_B0
$EC        ZP_SHARED_B1
$ED        ZP_SHARED_FLAG0
$EE        ZP_SHARED_TMP0
$EF        ZP_SHARED_MODE

$F0        CMD_PATTERN_INDEX
$F1        CMD_PATTERN_COUNT
$F2        CMD_IO_TMP
$F3        CMD_FLAGS
$F4        CMDP_LINE_REMAIN
$F5        CMDP_REMAIN
$F6        CMDP_NIB_HI
$F7        CMDP_BYTE_TMP
$F8        CMDP_ENTRY_LEN
$F9        CMDP_TOKEN_LEN
$FA        CMDP_START_LO
$FB        CMDP_START_HI
$FC        CMDP_ADDR_LO
$FD        CMDP_ADDR_HI
$FE        CMDP_PTR_LO
$FF        CMDP_PTR_HI
```

Zero-page rule of thumb:

```text
$00-$AF   user/free from HIMON's point of view, 176 bytes
$B0-$CA   reserved future R-YORS workspace, 27 bytes; user code should not rely on it
$CB-$CC   CRC16 no-table state, low/high; grows down from the high end
$CD-$EF   shared low-level service scratch, 35 bytes; volatile across monitor/SYS/BIO calls
$F0-$FF   HIMON command/parser scratch, 16 bytes; volatile across monitor commands
```

User programs can use `$00-$AF` while running. Entering STR8 recovery permits
STR8 to consume that user state; specifically, `I` owns `$90-$A0` until the
transaction returns. `$B0-$FF` is reserved or volatile across
monitor/fixed-entry services unless the called routine contract says
otherwise. That leaves 80 bytes reserved-or-volatile above the user ZP line.
The current live HIMON service/parser scratch is `$CD-$FF`; `$CB-$CC` is held
for CRC16 state, and `$B0-$CA` is being held back for future pointer lanes and
addressing-mode helpers.

There is no runtime zero-page allocator in HIMON. For native monitor code,
allocation is static: add named `EQU` entries, keep them in this map, and treat
the reserved bytes as volatile according to the routine contract. If future
runtime-loaded records need workspace, describe that workspace in the record or
resolve it during load/link. Do not add a heap-style allocator just to hand out
scratch bytes for one foreground command.

## RAM-Load Build Note

The non-ROM `himon` map is useful for development, but it is not the
authoritative flash image map. The current ROM memory map should be taken from:

```text
SRC/BUILD/map/himon-rom-c000.map
HIMON/himon.asm
HIMON/himon-shared-eq.inc
```

## STR8 Direction

The combined `himon-str8-rom.bin` image places STR8 in bank 3's `$F000-$FFFF`
top-ROM sector with the hardware vectors. HIMON starts at `$C000`, and the
STR8 jump-worker source is stored at `$FF1F-$FFAF`. The fixed V1 directory is
`$FFB0-$FFEF`; destructive `I` transactions upload their exact mutation worker
instead of storing it in the top sector.

The physical erase unit remains 4K. The protected STR8 window starts at the
highest boundary that fits:

```text
$FC00-$FFFF  1K protected STR8 window
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, current combined image

$FFF0-$FFF9  one-time flash board/version/config bytes, inside the window
$FFFA-$FFFF  W65C02 hardware vector block
```

Changing any byte in `$F000-$FFFF` still requires
read/stage/erase/full-sector-write/verify.
The `$FFF0-$FFF9` pocket is patchable only in the flash sense: after erase,
programming may clear bits from `1` to `0`, but changing cleared bits back to
`1` requires another top-sector erase/rewrite.

This split is the current combined STR8/HIMON ROM layout.

## Future Partitioned Bank Planning

The current V1.02 installer writes explicit 4K-sector ranges and does not expose
resident backup/restore commands. A separate planning direction would treat
banks 0 and 1 together as a 64K managed backup arena:

```text
bank 0 $8000-$8FFF   metadata/catalog sector
bank 0 $9000-$FFFF   payload slots 0-6
bank 1 $8000-$EFFF   payload slots 7-13
bank 1 $F000-$FFFF   reserved STR8_TOP_SAFE payload slot
bank 2               SYS/USR and rcat/hrec/rrec bank
bank 3               default boot bank
```

The bank 0/1 arena is 64K total. With the metadata sector and the reserved
STR8 top-sector rescue slot held out, 56K remains for ordinary managed backup
payloads. If STR8 self-update is not in play yet, the reserved slot may still
be erased, but the allocator should treat it as held back once top-sector
update work begins.

The live bank 3 budget stays:

```text
$8000-$BFFF   16K user-available space
$C000-$EFFF   12K default payload gate, currently HIMON-shaped
$F000-$FFFF    4K STR8 recovery/top-sector region
```

This planning map is not yet a writer contract. The first code version needs
exact 4K-sector slot boundaries and metadata commit rules before it can erase,
write, or restore from those sections.

Payload slots should remain raw sector bytes. Metadata such as labels, source
range, signatures, checks, and commit state belongs in the catalog sector. The
fixed external recovery address pair for the first `STR8_TOP_SAFE` plan is:

```text
source backup  bank 1 CPU $F000-$FFFF = PHY $0F000-$0FFFF
active target  bank 3 CPU $F000-$FFFF = PHY $1F000-$1FFFF
```
