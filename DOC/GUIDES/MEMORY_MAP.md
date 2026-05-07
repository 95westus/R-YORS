# R-YORS Memory Map

This is the easy-to-find memory map for the current HIMON ROM build and
the RAM workspace it uses.

The map below is definitive for the current generated `himon-rom` image.
It is not the final STR8/HIMON split. STR8 is intended to own the highest
recovery region and hand normal operation to HIMON.

## Current HIMON ROM Image

Ranges are listed as inclusive. Linker `_END_*` symbols are exclusive.

```text
$8000-$D5FF   current image gap
$D600-$F46E   HIMON CODE, START/standalone RESET entry at $D600
$F46F-$F9DA   HIMON DATA
$F9DB-$FFF9   current image gap and future STR8/high-ROM space
$FFFA-$FFFF   hardware vectors
```

The legacy HIMONIA fixed entries at `$F00D`, `$FADE`, and `$FEED` have been
removed. They were useful as a proof, but not a practical permanent ABI. Local
language bridges should patch against the current HIMON map or use a future
explicit handoff contract; STR8 must not reserve those addresses.

Current ROM hardware vectors:

```text
$FFFA-$FFFB   NMI   = $F1E4
$FFFC-$FFFD   RESET = $D600
$FFFE-$FFFF   IRQ   = $F1E7
```

Generated burnable ROM `.bin` files are exactly one 32K `$8000-$FFFF` bank
image for the programmer workflow. The file does not encode a bank number;
bank 0-3 placement is managed through the T48 programmer or through
R-YORS/STR8.

The primary combined image is `BUILD/bin/himon-str8-rom.bin`: the STR8 RAM
worker source is stored at CPU `$C000` / file offset `$4000`, HIMON starts at
CPU `$D600` / file offset `$5600`, STR8 starts at CPU `$FA00` / file offset
`$7A00`, and the RESET vector points to STR8 at `$FA00`. The NMI and IRQ
vectors point to HIMON's `$F1E4`/`$F1E7` vector entries until STR8 grows its own
interrupt policy.

Combined image layout:

```text
$8000-$BFFF   current image gap
$C000-$CFFF   STR8 RAM-worker source, copied to $3000 for B/E/0/1/2
$D000-$D5FF   current image gap
$D600-$F9DA   HIMON body
$F9DB-$F9FF   current image gap
$FA00-$FFF9   STR8 protected window and config bytes
$FFFA-$FFFF   hardware vectors
```

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
park itself in bank 0-2 while continuing to execute from `$D600`; it should use a
RAM worker that selects the requested bank, copies or checks bytes, then restores
bank 3 before HIMON prints or returns to normal command flow.

## Current Flash Policy

HIMON treats flash as `$8000-$FFFF`, but the current `L F` writer still has the
older `$D000+` guard. That guard protects the current HIMON-at-`$D600` layout
conservatively, but it must be revised before the combined STR8/HIMON image is
treated as the normal live layout:

```text
$8000-$CFFF   currently allowed by old L F blank-write guard
$D000-$FFFF   currently protected by old L F guard
$FA00-$FFFF   protected STR8 window, config, and vectors
```

Current `L F` behavior:

```text
target below $8000   protected
target $8000-$CFFF   currently allowed only if old byte is $FF
target $D000+        currently protected
```

There is no sector erase/condense path in the current HIMON image. STR8 is
the planned recovery/update owner for safer erase, rewrite, verify, and commit
flows.

## Current RAM Map

The current source header states:

```text
$0000-$7EFF   monitor-managed RAM region
$7F00-$7FFF   I/O
$8000-$FFFF   flash
```

Current RAM ownership:

```text
$0000-$00AF   zero page user/free while running
$00B0-$00CC   reserved R-YORS/HIMON/THE/ASM ZP expansion
$00CD-$00D9   flash helper workspace, active during flash operations
$00DA-$00DC   reserved expansion bytes inside flash/extended ZP window
$00DD-$00DF   bank/length sideband bytes, reserved shared ZP
$00E0-$00E5   shared 16-bit parameter lanes; $E0-$E1 also command hash pointer
$00E6-$00E7   shared utility temp/scratch bytes
$00E8-$00EF   shared pointer/length/flags/mode lane for FTDI/SYS/string helpers
$00F0-$00FF   monitor/parser hot zero-page window
$0100-$01FF   hardware stack; HIMON owns this on monitor entry
$0300-$12FF   reserved low 4K area, no live allocations
$1300-$13FF   flash transient / RAM worker page
$1400-$1FFF   system scratch and transient metadata
$2000-$77FF   UPA, user program area
$7800-$79FF   HIUPA, high user/scratch area
$7A00-$7AFF   scratch buffer
$7B00-$7BFF   command buffer
$7C00-$7CFF   loader line buffer
$7D00-$7DFF   loader data buffer
$7E00-$7E45   free buffer spill / scratch
$7E46-$7E65   debugger / assembler workspace
$7E66-$7E75   FNV hash and command-exec metadata
$7E76-$7E94   command/parser/keytest workspace
$7E95-$7EDD   loader workspace and range table
$7EDE-$7EDF   delay helper fixed RAM
$7EE0-$7EE5   PIA state / lock
$7EE6-$7EE9   reset signature
$7EEA-$7EEF   trap cause / BRK signature / reserve
$7EF0-$7EF7   NMI context capture
$7EF8-$7EFF   RAM vectors
$7F00-$7FFF   I/O window
```

During destructive STR8 `B`, `0`, `1`, and `2` operations, STR8 temporarily
clobbers `$3000-$3FFF` with the copied RAM worker and `$4000-$4FFF` with the 4K
sector staging buffer. Normal HIMON/user code should treat those ranges as
volatile while STR8 is performing flash work.

Current high-RAM vectors:

```text
$7EF8-$7EF9   reset vector target
$7EFA-$7EFB   NMI vector target
$7EFC-$7EFD   IRQ/BRK vector target
$7EFE-$7EFF   IRQ non-BRK vector target
```

Current zero-page detail:

```text
$00-$AF   user/free while running
$B0-$CC   reserved for future R-YORS/HIMON/THE/ASM zero-page expansion;
          possible active pointer lanes and addressing-mode workspace

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
$B0-$CC   reserved future R-YORS workspace, 29 bytes; user code should not rely on it
$CD-$EF   shared low-level service scratch, 35 bytes; volatile across monitor/SYS/BIO calls
$F0-$FF   HIMON command/parser scratch, 16 bytes; volatile across monitor commands
```

User programs can use `$00-$AF` while running. `$B0-$FF` is reserved or
volatile across monitor/fixed-entry services unless the called routine contract
says otherwise. That leaves 80 bytes reserved-or-volatile above the user ZP
line. The current live HIMON service/parser scratch is `$CD-$FF`; `$B0-$CC` is
being held back for future pointer lanes and addressing-mode helpers.

## RAM-Load Build Note

The non-ROM `himon` map is useful for development, but it is not the
authoritative flash image map. The current ROM memory map should be taken from:

```text
SRC/BUILD/map/himon-rom.map
HIMON/himon.asm
HIMON/himon-shared-eq.inc
```

## STR8 Direction

Current standalone HIMON no longer parks code or data above `$A3DA`, leaving the
high ROM area available for STR8. The combined `himon-str8-rom.bin` image places
STR8 in bank 3's `$FA00-$FFFF` top-ROM window with the hardware vectors. The
policy-protected STR8 window should be only as large as the final code requires.

The physical erase unit remains 4K. The protected STR8 window starts at the
highest boundary that fits:

```text
$FC00-$FFFF  1K protected STR8 window
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, only if needed

$FFF0-$FFF9  one-time flash board/version/config bytes, inside the window
$FFFA-$FFFF  W65C02 hardware vector block
```

Bytes below the chosen STR8 start are usable, but changing any byte in
`$F000-$FFFF` still requires read/stage/erase/full-sector-write/verify.
The `$FFF0-$FFF9` pocket is patchable only in the flash sense: after erase,
programming may clear bits from `1` to `0`, but changing cleared bits back to
`1` requires another top-sector erase/rewrite.

That future split is a design direction, not the current HIMON ROM map.
