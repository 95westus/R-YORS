![R-YORS logo](DOC/branding/logo-r-yors.svg)

# RЯORS (R-YORS) #

`R-YORS` = **Roll Ya Own Runtime System**

Not eRRORS, but expect fewer.

Pronunciation: **"are-yors"** (`R + Я(ya) + ors`).

This is a play on "Roll Your Own Runtime System," where "Я" (Russian for "ya") represents "your," highlighting the DIY, customizable nature of the project.

## Safety Notice

R-YORS includes code that can write to and erase flash memory. Running loaders,
tests, monitor commands, ROM images, or flash utilities may overwrite firmware,
programs, user data, or configuration stored on the target machine.

Use this project only if you understand the target hardware and have a recovery
path, such as a known-good ROM image or external programmer. The software is
provided as-is, without warranty; you are responsible for any consequences of
building, flashing, modifying, or running it.

## Why

**R-YORS exists to make a WDC W65C02SXB/W65C02EDU single-board computer feel like a standalone machine: power on, recover safely, load or build code, inspect routines, and grow the system in flash without needing a full toolchain every time.**

## What

R-YORS is an in-progress W65C02 runtime project built from the ground up:
low-level board bring-up, reusable runtime routines, command/catalog lookup,
flash-safe update paths, loaders, debug tools, and small applications that
prove the pieces work on real hardware.

The near-term project is the runtime family itself. **STR8** and **HIMON** are
sister components inside R-YORS: they may share code, and they may or may not
be used together in a given build. Recovery/update safety, command dispatch,
catalog lookup, assembler/debug services, and flash growth are R-YORS-level
concerns first.

The long-term north star is still true RPG II, but not as a bolted-on compiler. The "OS" is being shaped around the needs of that future: stable callable routines, discoverable catalogs, flash-resident programs, fixed entry points, simple text encodings, and an onboard assembler/linker path that can grow without losing the machine.

## How

R-YORS enables this vision through a modular library of routines that can be easily linked into projects. This approach allows developers to quickly assemble custom runtime systems by selecting and combining pre-built, tested components—eliminating the need to rewrite low-level code and accelerating experimentation on the 6502 platform.

## Command And Hash Catalog

One of R-YORS' core ideas is that commands, routines, symbols, and future
flash-resident modules can be found through the same small catalog pattern:

```text
text token -> canonical text -> 32-bit FNV-1a hash -> catalog record -> entry/value
```

The current monitor already proves this with FNV-1a command dispatch: a typed
command token is hashed, the catalog is scanned for a matching record, and the
matching executable entry is called. The `#` command exposes that lookup path.

The current scan is intentionally simple. Scanning a ROM/flash catalog and
computing a multiplicative hash both cost cycles, but the W65C02SXB is fast
enough for this proving stage, and the catalog format can grow block headers or
indexes later without changing the basic command/hash relationship.

Hashes keep records compact enough for ROM and flash, but they are not meant to
be the whole identity forever. As the catalog grows, stored command/routine text
can prove collisions, support listings, and let onboard tools link against
names without carrying a large conventional symbol table. See
[DOC/GUIDES/HASH_MAP.md](DOC/GUIDES/HASH_MAP.md) and
[DOC/GUIDES/HASH.md](DOC/GUIDES/HASH.md) for the deeper record model.

## Example Routines

To illustrate the library's versatility, here are three example routines from different layers:

- **UTL_HEX_NIBBLE_TO_ASCII** (Utility): Converts a low nibble (0-15) in A to uppercase ASCII hex ('0'-'F'), useful for debugging output.
- **BIO_PIA_LED_WRITE** (Hardware Abstraction): Controls LED states on the PIA chip, abstracting direct hardware access for safer GPIO operations.
- **SYS_WRITE_CHAR** (System I/O): Provides device-neutral character output, routing through the selected backend (e.g., FTDI) for consistent I/O across platforms. 

## Architecture & Current Status

My predecessor project, BSO2, proved the concept but suffered from inflexible command processing, poor modularity, and too many rabbit holes. R-YORS adopts a more disciplined approach with layered, reusable building blocks:

- **PIN routines** – Direct hardware interface
- **BIO routines** – Hardware abstraction layer wrapping PIN routines
- **COR routines** – Core reusable services and board-facing helpers
- **SYS routines** – System-level services such as I/O, vectors, debug entry, and monitor-facing adapters

The current HIMON proof image is a compact FNV-1a-dispatched monitor built to
fit under 8K. It boots from ROM, initializes FTDI I/O, clears RAM on cold
reset, patches RAM dispatch cells for reset/NMI/IRQ/BRK handling, and prints a
terse reset report like:

```text
BOOT COLD
RAM ZERO OK
FTDI INIT
WAIT ............. OK
RST 7EF8=EB81
NMI 7EFA=DD72
IRQ 7EFE=DDF3
BRK 7EFC=DDA5

HIMONIA v1
```

Warm reset reports `BOOT WARM` instead of `BOOT COLD` and skips the
`RAM ZERO OK` line.

The current monitor includes hashed command dispatch, S-record loading,
GO/LOAD+GO execution, register display/editing, memory display/modify,
disassembly/assembly helpers, breakpoints, single-step support, NMI/BRK trap
capture, decoded CPU flags, and return-status reporting for executed user code.
BRK handling is now native to the monitor rather than delegated to BSO2. The
monitor also exposes discoverable FNV signatures for selected commands and
routines, making ROM services easier to identify and call by hash.

Small standalone programs are used to test the runtime surface. One example is a 16x16 Conway Life app loaded at `$2000`, with random/manual/auto/next/quit controls, age-aware cells, NMI count testing, and cleanup that restores the monitor's debug vector before returning.

## Build

```text
make release
```

`release` regenerates the source-derived docs under `DOC/GENERATED`, builds
the tracked-source release set, and stamps the HIMON ROM binary under
`SRC/ROM_IMAGES/`. The tracked-source release set is HIMON, the FNV-1a/HBSTR
tool, the flash test, and `rom-append-calc`.

```text
make release-local
```

`release-local` adds the ignored/private local composites, including
`basic-himon-rom.bin` and `basic-forth-himon-rom.bin`, when the `LOCAL/`
source homes are populated.

## Documentation & References

Start here:

- [DOC/INDEX.md](DOC/INDEX.md) - documentation spine.
- [DOC/GUIDES/STR8.md](DOC/GUIDES/STR8.md) - recovery/update monitor direction.
- [DOC/GUIDES/MEMORY_MAP.md](DOC/GUIDES/MEMORY_MAP.md) - current HIMON ROM/RAM map.
- [DOC/GUIDES/CATALOG.md](DOC/GUIDES/CATALOG.md) - programmer-facing callable routine catalog.
- [DOC/GUIDES/FUTURE.md](DOC/GUIDES/FUTURE.md) - longer-term direction, including RPG II.

Core historical references include IBM's SY31-0458-3 and GC21-7667-4.

## Trademarks And Attribution

R-YORS is independent and is not affiliated with or endorsed by The Western
Design Center, Inc. Product names are used only to identify compatible hardware.
