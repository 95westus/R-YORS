![R-YORS logo](DOC/branding/logo-r-yors.svg)

# RЯORS (R-YORS) #

`R-YORS` = **Roll Ya Own Runtime System**

Not eRRORS, but expect fewer.

Pronunciation: **"are-yors"** (`R + Я(ya) + ors`).

This is a play on "Roll Your Own Runtime System," where "Я" (Russian for "ya") represents "your," highlighting the DIY, customizable nature of the project.

## Why

**R-YORS exists to make a WDC W65C02SXB/W65C02EDU single-board computer feel like a standalone machine: power on, recover safely, load or build code, inspect routines, and grow the system in flash without needing a full toolchain every time.**

## What

R-YORS is an in-progress W65C02 runtime project built from the ground up: low-level board bring-up, reusable runtime routines, a compact monitor, flash-safe recovery/update paths, loaders, debug tools, and small applications that prove the pieces work on real hardware.

The near-term project is the runtime itself: **STR8** for recovery/update safety and **HIMON** for the monitor, command dispatch, catalog lookup, assembler, and debug surface.

The long-term north star is still true RPG II, but not as a bolted-on compiler. The "OS" is being shaped around the needs of that future: stable callable routines, discoverable catalogs, flash-resident programs, fixed entry points, simple text encodings, and an onboard assembler/linker path that can grow without losing the machine.

## How

R-YORS enables this vision through a modular library of routines that can be easily linked into projects. This approach allows developers to quickly assemble custom runtime systems by selecting and combining pre-built, tested components—eliminating the need to rewrite low-level code and accelerating experimentation on the 6502 platform.

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

The current supervisory monitor is **HIMONIA-F**, a compact FNV-1a-dispatched monitor built to fit under 8K. It boots from ROM, initializes FTDI I/O, clears RAM on cold reset, patches RAM dispatch cells for reset/NMI/IRQ/BRK handling, and prints a terse reset report like:

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

HIMONIA-F currently includes hashed command dispatch, S-record loading, GO/LOAD+GO execution, register display/editing, memory display/modify, disassembly/assembly helpers, breakpoints, single-step support, NMI/BRK trap capture, decoded CPU flags, and return-status reporting for executed user code. BRK handling is now native to the monitor rather than delegated to BSO2. The monitor also exposes discoverable FNV signatures for selected commands and routines, making ROM services easier to identify and call by hash.

Small standalone programs are used to test the runtime surface. One example is a 16x16 Conway Life app loaded at `$2000`, with random/manual/auto/next/quit controls, age-aware cells, NMI count testing, and cleanup that restores the monitor's debug vector before returning.

## Build

```text
make release
```

`release` regenerates the source markdown summaries, builds the tracked-source
release set, and stamps the Himonia-F ROM binary under `SRC/ROM_IMAGES/`. The
tracked-source release set is Himonia-F, the FNV-1a/HBSTR tool, the flash test,
and `calc-flash`.

```text
make release-local
```

`release-local` adds the ignored/private local composites, such as BASIC/Forth
ROM images, when the `LOCAL/` source homes are populated.

## Documentation & References

Start here:

- [DOC/INDEX.md](DOC/INDEX.md) - documentation spine.
- [DOC/GUIDES/STR8.md](DOC/GUIDES/STR8.md) - recovery/update monitor direction.
- [DOC/GUIDES/MEMORY_MAP.md](DOC/GUIDES/MEMORY_MAP.md) - current Himonia-F ROM/RAM map.
- [DOC/GUIDES/CATALOG.md](DOC/GUIDES/CATALOG.md) - programmer-facing callable routine catalog.
- [DOC/GUIDES/FUTURE.md](DOC/GUIDES/FUTURE.md) - longer-term direction, including RPG II.

Core historical references include IBM's SY31-0458-3 and GC21-7667-4.

## Trademarks And Attribution

R-YORS is independent and is not affiliated with or endorsed by The Western
Design Center, Inc. Product names are used only to identify compatible hardware.
