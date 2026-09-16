# R-YORS Memory Map

This is the easy-to-find memory map for the current HIMON ROM build and
the RAM workspace it uses.

For the bench-facing names and layered diagrams of the active control areas,
see [Control Deck Map](../../GENERATED/CONTROL_DECK_MAP.md). The formal ranges
in this file remain authoritative.

The HIMON component map and the split STR8-N v1.34 integration map are listed
separately below. R-YORS builds `$8000-$EFFF`; the adjacent STR8-N repository
owns `$F000-$FFFF` and composes the optional full-bank payload.

## Current HIMON ROM Image

Ranges are listed as inclusive. Linker `_END_*` symbols are exclusive.

The [2026-09-16 functional correction](../AP/HIMON_AP_CONTRACT_CHANGE_2026-09-16.md)
updates the original baseline. The [generated ownership ledger](../../GENERATED/HIMON_AP_BASELINE.md)
separates resident AP, shared support, other HIMON bytes, and external APMAN.
The functional change reserves one durable session byte at `$7E6A`; the later
source extraction adds no ROM or RAM. The subsequent
[range-check reduction](../AP/HIMON_AP_RANGE_SIZE_REDUCTION_2026-09-16.md)
saves 20 resident bytes without changing RAM or the accepted address windows.

```text
$8000-$BFFF   outside the HIMON component; ASM-F2 in the combined image
$C000-$E9B1   HIMON CODE, START entry at $C000
$E9B2-$EE47   HIMON DATA
$EE48-$EFFF   440-byte HIMON component growth margin, padded FF
$F000-$FFFF   outside the HIMON component; STR8-N owns the top and vectors
```

The HIMON entry face has a fixed warm-entry identity contract independent of
the rest of the generated map:

```text
$C000-$C002   JMP to the current HIMON start body
$C003-$C006   HIMON warm ABI marker: A5 5A C3 3C
```

STR8-N `W` and its warm timeout match all four marker bytes before writing the same four-byte
warm signature at `$7EE6-$7EE9` and enters `$C000`. An absent or damaged
marker is not a generic `$C000` launch: STR8 prints `NO HIMON` and stays active.

The legacy HIMONIA fixed entries at `$F00D`, `$FADE`, and `$FEED` have been
removed. They were useful as a proof, but not a practical permanent ABI. Local
language bridges should patch against the current HIMON map or use a future
explicit handoff contract; STR8 must not reserve those addresses.

The release HIMON BIN is exactly 12 KiB (`$C000-$EFFF`); the ASM-F2 BIN is
exactly 16 KiB (`$8000-$BFFF`). Neither component includes hardware vectors
or forms a complete bootable bank. The canonical STR8-N BIN is 4 KiB
(`$F000-$FFFF`), including vectors and initial metadata. A complete 32 KiB
bank is a separate STR8-N composition product, not any of these component
BINs. On the integrated board RESET is `$F000`; NMI and IRQ/BRK entry stubs
are owned and checked by STR8-N.

The current workbench HIMON/ASM pair is installed on COM4 with STR8-N v1.34.
The frozen comparison stamp remains `00.0915(2324)`; use the dated contract
and range-size records' hashes to identify these changed bytes. Previously published
[release packages](../../../RELEASE/README.md) remain separate and unchanged.

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

R-YORS publishes `RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19`, a dense 28K
`$8000-$EFFF` payload. STR8-N validates that input and its optional composer
writes `BUILD/v1.34/s19/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19` in the
standalone checkout. RESET points
to STR8-N at `$F000`; the exact NMI and IRQ/BRK vector
targets are owned and checked by the standalone STR8-N build.

Combined image layout:

```text
$8000-$BB82   ASM-F2 low-flash image, entry $800C
$BB83-$BFFF   1,149-byte low-flash growth margin; no carrier storage in Bank 3
$C000-$EE47   HIMON body, including resident AP-v2 linker/APMAN bootstrap
$EE48-$EFFF   440-byte image gap inside the E sector
$F000-$FCF1   STR8-N v1.34 resident supervisor, installer, loader, and services
$FCF2-$FD77   currently available resident growth, 134 bytes
$FD78-$FFAF   stored unified STR8-N RAM worker, copied to $0200-$0437
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

## Accepted Physical-Sector Inventory

The read-only BANKDUMP `M` run captured this board inventory on 2026-08-26:

```text
B# 8 9 A B C D E F

B0 U U U U U U U U
B1 U A A U U A W B
B2 A A E E E E E E
B3 U U U U U U U P
```

`E` is a completely erased 4K sector, `U` is occupied/unmanaged content, and
`A` is a fully validated AP-v2 carrier including body FNV. `W`, `B`, and `P`
are configured roles: B1:E WORK, B1:F B3:F backup, and live B3:F protected.

The carriers accepted in that capture were APMAN at B2:8 (`L=$0B40`, body
`$7000-$7B11`) and BANKDUMP at B2:9 (`L=$09AD`, body `$2000-$292B`). B1:C
reported `U`; the map classifies live bytes and does not trust a
former package name or directory description.

This dated inventory is not the current board's sector map. The 2026-09-15
firmware proof covered Bank 3 and did not requalify these carrier placements.

## OIL Address Boundary

OIL keeps an AP Capsule (APC) in storage separate from its executable BODY:

```text
AP Capsule in RAM, visible flash, or banked flash
  -> stage and parse (banked flash uses the SSD at $0A00-$19FF)
  -> load BODY into ordinary application RAM at $2000-$6FFF
  -> apply relocation and resident imports
  -> run the entry from RAM
```

A banked AP is staged one 4K sector at a time; it is not executed directly
from the banked flash window. The resident direct `AP pkg dst` recovery form
uses TAKEOVER `$05`, allowing `$2000-$6FFF`. Ordinary service LOAD `$01`
keeps `$2000-$4FFF` and the separate tool tray. APMAN occupies `$7000-$7BD6`,
so managed children must have an exclusive end no greater than `$7000`.

Historical owner-local language images were built to sit below the protected
HIMON/STR8 region:

```text
$8000-$9FFF   OSI MS BASIC 8K slot, FNV header at $8000
$A000-$BFFF   fig-Forth slot, FNV header at $A000
$C000-$FFFF   protected live HIMON/STR8 region
```

These are historical proof/load artifacts and are excluded from the current
release ZIPs. The released `$8000-$BFFF` component is ASM-F2. HIMON `L`
cannot write flash.

Historical STR8 bench tests temporarily placed fig-Forth at `$C000-$EFFF` with
`BUILD/s19/fig-forth-str8-update.s19`. That was a deliberate V0 `U`
replacement of HIMON, not a current v1.34 installation procedure.

The matching OSI MS BASIC artifact is likewise historical. Current v1.34 flash
installation uses standalone STR8-N dense range payloads.

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

HIMON's user-facing `L` command is now RAM-only and load-only. `L G` and `L F`
are rejected by the bare-`L` grammar. Its guard accepts S1 destinations below
`$7A00` and rejects flash:

```text
$0000-$79FF   allowed RAM range, subject to record/span checks
$7A00-$7FFF   protected monitor/I/O range
$8000-$FFFF   flash rejected by HIMON L
```

Current loader behavior:

```text
bare L       load accepted S1 bytes, report S9, do not execute
L G          usage error
L F          usage error
```

HIMON calls STR8-N `$F009` `SR/02` for record syntax, type, checksum, and
decoded descriptor data. It carries no private S19 parser. The first fatal
syntax, checksum, or protected-span error poisons the receive
session. HIMON retains the first failure, suppresses all later S1 writes, and
continues consuming non-echoed input until a valid S9 or Ctrl-C. Accepted S1
records from before the error remain in RAM.

There is no user-facing sector erase/condense path in HIMON. STR8-N v1.34 owns
selected-bank erase, program, verify, and journal flows through its `I`
transaction and standalone RAM maintenance tools.

## Current RAM Map

The current source header states:

```text
$0000-$7EFF   monitor-managed RAM region
$7F00-$7FFF   I/O
$8000-$FFFF   flash
```

Current RAM ownership:

```text
$0000-$00AF   zero page user/free while running; STR8 I/L transient fields lie in $0090-$00A2
$00B0-$00B3   shared FNV32 hash state
$00B4-$00C6   reserved shared service expansion/scratch
$00C7-$00CA   shared FNV32 multiply term
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
$1A00-$1AFF   APMAN command shadow while AP/APS/INSTALL is active
$1B00-$1FFF   user/free outside another phase owner
$2000-$4FFF   AIR: Build Bay, Envelope Bay, and normal Run/Tray Bay
$5000-$6D6D   AWH: flash ASM UDATA
$6D6E-$6FFF   SOD/application headroom
$7000-$7BD6   APMAN transient body when resident AP/APS/INSTALL delegates
$7BD7-$7BFF   41 bytes of remaining manager overlay headroom
$7A00-$7AFF   VOD: command buffer and volatile monitor scratch
$7B00-$7BFB   RPT: validated-record decoded payload tray (252 bytes)
$7BFC-$7BFF   VOD: remaining volatile monitor scratch
$7C00-$7DBF   HTO: foreground High Tool Overlay, single owner
$7DC0-$7DC7   HIMON AP-link scratch
$7DC8-$7DE6   reserved
$7DE7-$7DE8   STR8-N one-shot software-reset record (`RS`)
$7DE9-$7DFF   RSC: STR8 worker/update state
$7E00-$7E01   HIMON-published RJOIN addr16 (`THE_JOIN_EXEC_XY`)
$7E02-$7E1C   HIMON resident service vector block + checksum
$7E1D-$7E1E   HIMON RX lookahead
$7E1F-$7E22   optional PACK40 service vectors
$7E23-$7E24   AP import record pointer after package parse
$7E25-$7E2C   optional flash-install service vector/request cells
$7E2D-$7E40   optional AP package service vector/request/result cells
$7E41-$7E45   AP package service scratch
$7E46-$7E65   debugger / assembler workspace
$7E66-$7E69   FNV hash metadata
$7E6A         durable ASM SEAL-resume flag
$7E6B-$7E6D   unused in the current image
$7E6E-$7E75   command-exec metadata
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
requested load address, within `$2000-$6FFF` for explicit takeover.

APMAN changes the foreground phase map while it is active. HIMON copies the
command page to `$1A00`, loads APMAN at `$7000`, stages one bank sector at
`$0A00-$19FF`, and loads a selected child within `$2000-$6FFF` through TAKEOVER. These areas are not
independent persistent buffers; a caller that wants to survive a child AP must
keep its own code/data and stack outside every child destination and manager
scratch range.

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

The [current contract](../AP/HIMON_AP_CONTRACT_CHANGE_2026-09-16.md) records these
phase aliases. Bootstrap clears the durable resume flag before overwriting ASM
names; ASM INSTALL returns to a fresh session. Unsafe INSTALL source spans
are rejected before staging. `$5000-$6D6D` becomes application RAM only after
explicit takeover; its previous ASM contents cannot then be resumed.

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

During current STR8-N `I` operations, the resident owns the copied worker at
`$0200-$0437`, the sector tray at `$0A00-$19FF`, and its recovery state.
HIMON/user code must treat those phase-owned areas as volatile. RAM Bank
Maintenance and top-update tools have their own documented staging ranges;
consult the STR8-N manual before loading another tool. The former resident
`B`/`U`/numbered copy commands and `$4000-$6FFF` staging descriptions belong
to historical STR8 images.

STR8 uses the RSC at `$7DE9-$7DFF` for bank/sector copy state, failure address
reporting, startup flags, and update state. `J0`-`J3` use `$7DF2-$7DF5` for
target bank, reset-vector low/high, and handoff status.

During a foreground STR8-N `I` transaction, the persistent installer fields
occupy `$0090-$009C`, `$009E-$009F`, and `$00A1-$00A2` (17 bytes total).
`$009D` is unused and `$00A0` is the separate `L` nonempty-data flag. The
installer fields survive RAM-worker calls because the worker owns only
`$00CD-$00D6`. Outside recovery, those cells return to the normal
`$0000-$00AF` user/free policy.

The published Bank Jump Record occupies the RSC tail:

| Address | Symbol | Published value |
| ---: | --- | --- |
| `$7DFD` | `STR8_BANK_JUMP_SIG0` | `$42` (`B`) |
| `$7DFE` | `STR8_BANK_JUMP_SIG1` | `$4A` (`J`) |
| `$7DFF` | `STR8_BANK_LAST_JUMP` | last validated target bank `0`-`3`, or `$FF` |

The RAM worker commits the signed record after selecting the target and
validating its reset vector, immediately before the final jump. HIMON cold
start preserves a valid record through RAM clearing and republishes `42 4A FF`
when no valid target is available. Thus `D 7DFD 7DFF` reports the bank selected
for the preceding successful STR8 handoff rather than the Bank 3 selection
that is live after returning to HIMON.

STR8-N v1.34 itself reserves no byte in `$1A00-$1FFF`, but HIMON's APMAN
delegation owns `$1A00-$1AFF` as a command shadow while AP/APS/INSTALL is
active. `$1B00-$1FFF` is free outside another phase owner. HIMON cold start
clears both as part of general RAM clearing. The `$7C00-$7DBF` High Tool
Overlay replaces the former low-RAM tool
cards. It is volatile and single-owner. ASM may emit through `$7CFF`; every
write at or crossing `$7D00` is rejected.

Current high-RAM vectors:

```text
$7EF8-$7EF9   reset vector target
$7EFA-$7EFB   NMI vector target
$7EFC-$7EFD   IRQ/BRK vector target
$7EFE-$7EFF   IRQ non-BRK vector target
```

Current zero-page detail. The ASM ranges are reserved only while ASM-F2 is
active; ordinary user code may reuse `$00-$AF` after ASM exits:

```text
$00-$7F   user/free while running
$80-$81   ASM current PC while ASM-F2 is active
$82-$83   flash ASM wrapper command pointer while ASM-F2 is active
$84-$AF   ASM core parser/emitter frame while ASM-F2 is active;
          $90-$A2 also contains transient STR8 I/L state during recovery
$B0-$B3   shared FNV32 hash state; volatile across hash/catalog services
$B4-$C6   reserved shared service expansion/scratch
$C7-$CA   shared FNV32 multiply term; volatile across hash/catalog services
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
$B0-$CA   shared FNV state/term and reserved expansion, 27 bytes
$CB-$CC   CRC16 no-table state, low/high; grows down from the high end
$CD-$EF   shared low-level service scratch, 35 bytes; volatile across monitor/SYS/BIO calls
$F0-$FF   HIMON command/parser scratch, 16 bytes; volatile across monitor commands
```

User programs can use `$00-$AF` while running. Entering STR8 recovery permits
STR8 to consume that user state; specifically, `I` uses the 17 fields listed
above within `$90-$A2` until the transaction returns. `$B0-$FF` is reserved or volatile across
monitor/fixed-entry services unless the called routine contract says
otherwise. That leaves 80 bytes reserved-or-volatile above the user ZP line.
The live HIMON service/parser scratch includes `$CD-$FF`, FNV state at
`$B0-$B3`, and the multiply term at `$C7-$CA`; `$CB-$CC` is held for CRC16
state, with `$B4-$C6` reserved for shared expansion.

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
SRC/BUILD/s19/himon-rom-c000.map
HIMON/himon.asm
HIMON/himon-shared-eq.inc
```

## STR8-N Boundary

The standalone STR8-N image owns Bank 3's `$F000-$FFFF` top sector and hardware
vectors. HIMON starts at `$C000`. The fixed directory remains `$FFB0-$FFEF`,
and the unified worker is stored at `$FD78-$FFAF` and runs at `$0200-$0437`.

The physical erase unit and protected STR8-N allocation are both 4K:

```text
$F000-$FFFF  4K protected STR8-N sector

$FFF0-$FFF9  one-time flash board/version/config bytes, inside the window
$FFFA-$FFFF  W65C02 hardware vector block
```

Changing any byte in `$F000-$FFFF` still requires
read/stage/erase/full-sector-write/verify.
The `$FFF0-$FFF9` pocket is patchable only in the flash sense: after erase,
programming may clear bits from `1` to `0`, but changing cleared bits back to
`1` requires another top-sector erase/rewrite.

This split is enforced by the external manifest and R-YORS content lock.

## Future Partitioned Bank Planning

The current v1.34 installer writes explicit 4K-sector ranges and does not expose
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
