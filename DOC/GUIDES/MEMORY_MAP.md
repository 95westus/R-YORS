# R-YORS Memory Map

This is the easy-to-find memory map for the current Himonia-F ROM build and
the RAM workspace it uses.

The map below is definitive for the current generated `himon-rom` image.
It is not the final STR8/HIMON split. STR8 may later own the highest recovery
region and hand normal operation to HIMON.

## Current Himonia-F ROM Image

Ranges are listed as inclusive. Linker `_END_*` symbols are exclusive.

```text
$8000-$CFFF   user flash/load region for L F
$D000-$EDC4   Himonia-F CODE, START/RESET entry at $D000
$EDC5-$EF22   Himonia-F DATA
$EF23-$F00C   open gap in current image
$F00D-$F00F   ABI write-byte trampoline, "F00D"/FOOD
$F010-$F3D0   Himonia-F data tail/tables
$F3D1-$F4CC   Himonia-F boot telemetry routine and strings
$F4CD-$FACD   open gap in current image
$FACE-$FAD0   planned ABI identity trampoline, FACE, not emitted yet
$FAD1-$FADD   open gap in current image
$FADE-$FAE9   ABI exit-to-monitor trampoline, FADE
$FAEA-$FEEC   open gap in current image
$FEED-$FEEF   ABI read-byte trampoline, FEED
$FEF0-$FFF9   open gap in current image
$FFFA-$FFFF   hardware vectors
```

Fixed and planned entry points:

```text
$D000   START / RESET entry
$F00D   HIMONIA_ABI_WRITE_BYTE, pronounced "F00D/FOOD"
$FACE   planned HIMONIA_ABI_IDENTITY / board-version-info output
$FADE   HIMONIA_ABI_EXIT_APP
$FEED   HIMONIA_ABI_READ_BYTE
```

Current ROM vector tail:

```text
$FFFA-$FFFB   NMI   = $EB3A
$FFFC-$FFFD   RESET = $D000
$FFFE-$FFFF   IRQ   = $EB3D
```

## Current Flash Policy

Himonia-F treats flash as `$8000-$FFFF`, but the current `L F` writer only
allows blank-byte writes in the user flash area:

```text
$8000-$CFFF   allowed for current L F blank-write loads
$D000-$FFFF   protected Himonia-F, ABI, tables, gaps, and vectors
```

Current `L F` behavior:

```text
target below $8000   protected
target $8000-$CFFF   allowed only if old byte is $FF
target $D000+        protected
```

There is no sector erase/condense path in the current Himonia-F image. STR8 is
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
$0000-$00CC   zero page not claimed by current Himonia-F ROM map
$00CD-$00D9   flash helper workspace, active during flash operations
$00DA-$00DC   reserved expansion bytes inside flash/extended ZP window
$00DD-$00DF   bank/length sideband bytes, reserved shared ZP
$00E0-$00E5   shared 16-bit parameter lanes; $E0-$E1 also command hash pointer
$00E6-$00E7   shared utility temp/scratch bytes
$00E8-$00EF   shared pointer/length/flags/mode lane for FTDI/SYS/string helpers
$00F0-$00FF   monitor/parser hot zero-page window
$0100-$01FF   hardware stack; Himonia-F owns this on monitor entry
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

Current high-RAM vectors:

```text
$7EF8-$7EF9   reset vector target
$7EFA-$7EFB   NMI vector target
$7EFC-$7EFD   IRQ/BRK vector target
$7EFE-$7EFF   IRQ non-BRK vector target
```

Current zero-page detail:

```text
$00-$CC   free/unclaimed by Himonia-F; user code may use while running

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
$00-$CC   free from Himonia-F's point of view
$CD-$EF   shared low-level service scratch; volatile across monitor/SYS/BIO calls
$F0-$FF   Himonia-F command/parser scratch; volatile across monitor commands
```

User programs can use free zero page while running, but callable monitor/ABI
services may clobber the service and parser scratch windows unless their routine
contract says otherwise.

## RAM-Load Build Note

The non-ROM `himon` map is useful for development, but it is not the
authoritative flash image map. The current ROM memory map should be taken from:

```text
SRC/BUILD/map/himon-rom.map
SRC/TEST/apps/himon/himon.asm
SRC/TEST/apps/himon/himon-shared-eq.inc
```

## STR8 Direction

Current Himonia-F owns `$D000-$FFFF` in the ROM image. The future STR8 recovery
monitor is expected to live in bank 3's `$F000-$FFFF` top-ROM erase sector with
the hardware vectors, but the policy-protected STR8 window should be only as
large as the final code requires.

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

$FFF0-$FFF8  one-time flash board/version/config bytes, inside the window
$FFF9-$FFFF  vector tail; W65C02 hardware vectors are $FFFA-$FFFF
```

Bytes below the chosen STR8 start are usable, but changing any byte in
`$F000-$FFFF` still requires read/stage/erase/full-sector-write/verify.

That future split is a design direction, not the current Himonia-F ROM map.
