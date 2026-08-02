# Interactive RAM Flash-Bank AP Packages

These are movable RAM tools for inspecting or replacing one 4K flash sector.
They run at `$3000`, use `$4000-$4FFF` as the sector tray, and call the
existing STR8 flash worker at `$F003`.

## Recorded Entry Points

The supplied 2026-07-20 board transcript records the original packages:

| AP | Bank-0 package | Old envelope | RAM entry | Installer entry |
|---|---:|---:|---:|---:|
| `FLASH_BANK_READ` | `$86A6` | `$0100` | `$3000` | `$2000` |
| `FLASH_BANK_ERASE_WRITE` | `$87A6` | `$01B4` | `$3000` | `$2000` |

For example, the old read package would be loaded with:

```text
AP B0 $86A6 $3000
```

`$86A6` or `$87A6` is the address of an AP Capsule stored in Bank 0.
`$3000` is the AIR Envelope Bay where HIMON copies and relocates its executable
body. Both exported entry points are at body offset zero, so the callable RAM
entry is `$3000`.
The installer itself was started with `G 2000`.

Those two installed packages are the earlier non-interactive versions. The
transcript proves successful assembly, packaging, and Bank-0 installation; it
does not contain an `AP B0` execution of either package.

The source files now contain interactive successors. Their Bank-0 addresses
are not known until they are rebuilt and installed into new erased holes. Do
not overwrite or relabel `$86A6/$87A6` as the interactive builds.

## What Each AP Does

`FLASH_BANK_READ` asks for a bank and sector, copies that complete 4096-byte
sector into the AIR Run/Tray Bay at `$4000-$4FFF`, computes CRC-16/CCITT-FALSE,
and prints the result. It never erases or programs flash.

`FLASH_BANK_ERASE_WRITE` assumes the complete new sector image is already in
the AIR Run/Tray Bay at `$4000-$4FFF`. It asks for the destination, computes
and prints the buffer CRC, then requires exact `YES`. Only then does it erase,
program, and read back the complete sector. The Card Rule applies: a changed
request or buffer is rejected before writing.

The write AP permits:

```text
Banks 0-2  $8000-$FFFF
Bank 3     $8000-$BFFF only
```

Bank 3 `$C000-$FFFF` remains reserved for STR8 update and recovery paths.

## New Interactive Package Sizes

| AP source | Body | Relocations | Export | Imports | Expected envelope |
|---|---:|---:|---:|---:|---:|
| `flash-bank-read-ap-2000.a` | `$01FB` | `$0D` | `$0F` | `$22` | `$0289` |
| `flash-bank-erase-write-ap-2000.a` | `$02EE` | `$0E` | `$15` | `$22` | `$0387` |

The two imports are `BIO_FTDI_PUT_CSTR` and
`SYS_READ_CSTRING_ECHO_UPPER`. The onboard `PKG OK` length is authoritative;
stop and preserve the transcript if it differs.

## Build And Install The Interactive Read AP

At the HIMON prompt:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/flash-bank-read-ap-2000.a
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$0289
SEAL> .
ASM BYE
>AP B0 PUTPKG $2000
```

`PUTPKG` is the recorded Bank-0 address of the fixed-load resident
`BANK0_AP_PUT` installer. If it has not been bootstrapped yet, follow the
bootstrap procedure in `bank0ap-put-transient-2000.a` and record the current
board-built package length; the appendable revision no longer has the old
fixed `$0486` size.

At the destination prompt, press Enter for automatic erased-hole selection.
Review the selected address and `$0289` length. Type exact `YES` only if both
are right, require `PROGRAM OK` and `RET A=AC`, and record the new address as
`READPKG`.

## Run The Interactive Read AP

Replace `READPKG` with the recorded four-digit address:

```text
>AP B0 READPKG $3000

FLASH READ B/S (2F)> 2F

READ ST=$AC B=2 S=F000 CRC=$hhhh BUF=$4000
```

The example stages Bank 2 `$F000-$FFFF`. The actual four CRC digits replace
`hhhh`. On success `$1B00=$AC`, carry is set, and the complete sector is in
`$4000-$4FFF`. Bad input returns `$E0` with carry clear.

## Build And Install The Interactive Write AP

Rebuild the RAM envelope, then repeat the same installer flow:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/flash-bank-erase-write-ap-2000.a
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$0387
SEAL> .
ASM BYE
>AP B0 PUTPKG $2000
```

Require the installer to report the new `$0387` length. Select a genuinely
erased Bank-0 hole, require `PROGRAM OK` and `RET A=AC`, and record the new
address as `WRITEPKG`.

## Run The Interactive Write AP

First place the entire desired sector image in `$4000-$4FFF`. Then:

```text
>AP B0 WRITEPKG $3000

FLASH WRITE B/S (2F)> 2F

READY B2 F000 CRC=$hhhh TYPE YES> YES
```

The first line only chooses the destination. Before the `YES` prompt, the AP
has performed a read-only preflight and captured the destination and buffer
CRC; no flash write has occurred. Exact `YES` performs erase, full-sector
program, and full-sector read-back verification. Anything else aborts and
returns `$E4` with carry clear.

Require `RET A=AC` and carry set after a real write. Stop on any other return
and inspect `$1B00-$1B0F` before doing anything else.

## Flash Transaction Card (FTC)

```text
$1B00  status
$1B01  bank: 00-03
$1B02  sector high byte: 80,90,A0,B0,C0,D0,E0,F0
$1B03  buffer high byte: 40
$1B04  CRC16 low
$1B05  CRC16 high
$1B06  worker failure address low
$1B07  worker failure address high
$1B08  write-ready marker
$1B09-$1B0A  private one-shot arm
$1B0B-$1B0E  private write-preflight snapshot
$1B20-$1B53  formatted interactive text and scratch
$1C00-$1CFE  Console Input Deck (CID)
```

CRC bytes are little-endian in RAM. The printed CRC is conventional
high-byte-first hexadecimal. The algorithm is CRC-16/CCITT-FALSE: polynomial
`$1021`, initial value `$FFFF`, no reflection, and no final XOR.

Write statuses are:

```text
$5A  preflight ready; no flash write occurred yet
$AC  erase, program, and full-sector verify passed
$E0  bad or forbidden destination
$E1  commit without a valid preflight
$E2  destination or buffer changed after preflight
$E3  STR8 worker failure; failure address is at $1B06/$1B07
$E4  operator did not type exact YES
```

Every write failure clears the ready marker and arm. Reloading the package
also cancels its package-local preflight cookie.

## First Hardware Run

Run the read AP first because it is non-destructive. For the first actual write
proof, use an explicitly sacrificial 4K sector with a saved before-image and a
known recovery path. Do not use Bank 0 `$8000`, the Bank-2 recovery image, or
Bank 3 `$C000-$FFFF`.

Do not run STR8 `B` while Bank 0 is enrolled in backup rotation if the Bank-0
AP packages are meant to remain there.
