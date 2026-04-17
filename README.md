# RЯORS (R-YORS) #

`R-YORS` = **Roll Ya Own Runtime System**

Not eRRORS, but expect fewer.

Pronunciation: **"are-yors"** (`R + Я(ya) + ors`).

This is a play on "Roll Your Own Runtime System," where "Я" (Russian for "ya") represents "your," highlighting the DIY, customizable nature of the project.

## Why

**The goal is to create an inexpensive, turnkey 6502 runtime system that boots directly from hardware without requiring toolchain setup. This will make retro computing accessible to anyone seeking standalone operation and customizable runtime experimentation on a single board.**

## What

R-YORS is an in-progress 65C02 runtime project based on the Western Design Center W65C02SXB/W65C02EDU hardware. I'm vibe-coding from the ground up—building low-level routines and exploring multiple paths to realize my ultimate goal: an RPG II compiler. This iterative process generates reusable code blocks along the way, even if not all prove essential to the final vision. 

### Why RPG

I want to build the language I actually learned, not a modern approximation. I spent nearly 30 years writing RPG, and there still is not one project here focused on true RPG II. Yes, I could get access to an AS/400 or S/3x0, but that misses the point. This project targets the original RPG II model. As I kept building routines on top of routines, I realized this approach can produce a close approximation/simulation of the original environment. The plan is to build it from the ground up, guided by IBM manuals such as SY31-0458-3 (System Unit Theory Diagrams Manual) and GC21-7667-4 (RPG II Reference Manual), then expand compatibility without losing what made RPG II unique.

## How

R-YORS enables this vision through a modular library of routines that can be easily linked into projects. This approach allows developers to quickly assemble custom runtime systems by selecting and combining pre-built, tested components—eliminating the need to rewrite low-level code and accelerating experimentation on the 6502 platform.

## Example Routines

To illustrate the library's versatility, here are three example routines from different layers:

- **UTL_HEX_NIBBLE_TO_ASCII** (Utility): Converts a low nibble (0-15) in A to uppercase ASCII hex ('0'-'F'), useful for debugging output.
- **BIO_PIA_LED_WRITE** (Hardware Abstraction): Controls LED states on the PIA chip, abstracting direct hardware access for safer GPIO operations.
- **SYS_WRITE_CHAR** (System I/O): Provides device-neutral character output, routing through the selected backend (e.g., FTDI) for consistent I/O across platforms. 

## Architecture & Current Status

My predecessor project, BSO2, proved the concept but suffered from inflexible command processing, poor modularity, and AI-induced rabbit holes. R-YORS adopts a more disciplined approach with layered, reusable building blocks:

- **PIN routines** – Direct hardware interface
- **BIO routines** – Hardware abstraction layer wrapping PIN routines
- **COR routines** – Application-level functionality (currently under test)
- **SYS routines** – I/O handling for specific board devices (FTDI, ACIA, VIA, PIA)

The system includes a compact monitor (**himon**) at ~4K that currently supports: DISPLAY, FILL, COPY, MODIFY, HELP, LOAD, QUIT. Note that R-YORS/himon currently relies on bso2 for BRK handling. Future enhancements will extend himon to match the board's default onboard flash monitor capabilities.

## Documentation & References

Core references include IBM's SY31-0458-3 (System Unit Theory Diagrams Manual) and GC21-7667-4 (RPG II Reference Manual).
