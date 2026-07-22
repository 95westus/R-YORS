# Bank 0 AP Entry-Point Ledger

This ledger separates the address where an AP Capsule (the serialized AP
envelope) is stored in Bank 0 from the address where HIMON loads and runs its
BODY in the AP Island Runway (AIR).

```text
AP B0 $XXXX $YYYY
```

`$XXXX` is the Bank-0 address of the stored AP Capsule. `$YYYY` is the RAM
BODY destination and entry base. The command loads, links, and runs the AP; it
does not mean "write flash at `$XXXX` or `$YYYY`." An AP such as
`BANK0_AP_PUT` may ask for a flash destination after it starts.

## Recorded Board Assignments

| AP package | Bank-0 envelope | RAM entry | Envelope | Meaning |
|---|---:|---:|---:|---|
| legacy `asm-session-report-4800.a` | `$8000` | `$4800` | `$06A6` installed revision | Fixed-load, ASM-map-matched session report |
| old `FLASH_BANK_READ` | `$86A6` | `$3000` | `$0100` | Non-interactive sector-to-`$4000` read and CRC |
| old `FLASH_BANK_ERASE_WRITE` | `$87A6` | `$3000` | `$01B4` | Non-interactive armed sector erase/write/verify |

The `$86A6/$87A6` assignments and lengths are from the 2026-07-20 hardware
transcript. That transcript proves assembly, packaging, and installation, but
does not prove an `AP B0` runtime of either flash package. Bank 0 `$8000` is
the operator-recorded current placement of the fixed `$4800` reporter. Do not
rename any of these old envelopes as the new interactive builds.

## New AP Sources Awaiting Board Addresses

| Export/entry | Pasteable `.a` source | Required or recommended RAM entry | Body | Expected envelope | What it does |
|---|---|---:|---:|---:|---|
| `BANK0_AP_PUT` | `bank0ap-put-transient-2000.a` | `$2000` required | board-build | board-build | Interactively appends the target Capsule already in the AIR Envelope Bay at `$3000` to a verified clean Bank-0 sector tail |
| `FLASH_BANK_READ` | `flash-bank-read-ap-2000.a` | `$3000` recommended | `$01FB` | `$0289` | Prompts for bank/sector, reads 4K to `$4000-$4FFF`, and prints CRC; never writes flash |
| `FLASH_BANK_ERASE_WRITE` | `flash-bank-erase-write-ap-2000.a` | `$3000` recommended | `$02EE` | `$0387` | Prompts for bank/sector and exact `YES`, then erases, programs from `$4000-$4FFF`, and fully verifies |
| `START` | `asm-session-report-ap-2000.a` | `$4000` recommended; `$2000-$43A1` legal | `$0C5F` | `$0C8B` | Self-relocates, then reports the just-finished ASM session and current RAM regions |

Record each Bank-0 address printed by `BANK0_AP_PUT` as `PUTPKG`, `READPKG`,
`WRITEPKG`, or `REPORTPKG`. Those names are notebook placeholders, not HIMON
symbols; substitute the recorded four hex digits at the prompt.

## Resident Installer Workflow

Bootstrap the installer itself once:

```text
>ASM NEW
paste bank0ap-put-transient-2000.a
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
>G 2000
```

At the prompt, accept or choose a verified erased Bank-0 address, type exact
`YES`, and record the resulting address as `PUTPKG`.

For every later AP source:

```text
>ASM NEW
paste the target .a source
SEAL> PACKAGE $3000
SEAL> .
ASM BYE
>AP B0 PUTPKG $2000
```

The resident installer is fixed-load at `$2000`; its prompt decides where the
target Capsule is written in Bank 0. Record the printed target address. A
normal later run of the target is then, for example:

```text
>AP B0 READPKG $3000
```

## Reporter Preload Rule

Load either reporter before the ASM session it will inspect. For the movable
form:

```text
>AP B0 REPORTPKG $4000
>ASM NEW
...target source...
SEAL> .
ASM BYE
>G 4000
```

Do not issue a banked `AP` after the target session. The Switchyard Rule
applies: package staging takes the LRS away from the low symbol/fixup lanes.
The movable reporter knows the current split:
`$0200-$09FF` symbols, `$0A00-$19FF` fixups, `$1A00-$1FE8` tool space,
`$1FE9-$1FFF` STR8 state, `$2000/$3000/$4000` islands, `$5000-$61A9` ASM
UDATA, `$61AA-$79FF` safe output, and `$7A00-$7DFF` volatile space.

The movable reporter relocates every internal body address, but its calls and
table reads still match one ASM-F2 map. Rebuild and reinstall it after ASM-F2
code or map changes.

Its **Reporter Rebase Table (RBT)** is deliberately local to this reporter,
not a change to the AP Capsule ABI:

```text
'S' 'R' $01 count
kind site_lo site_hi target_lo target_hi    repeated count times
```

`kind=$01` writes a complete 16-bit `actual_base+target`; `$02` writes its low
byte and `$03` its high byte. `site` and `target` are BODY offsets, so rerunning
the bootstrap writes the same bytes instead of adding another relocation
delta. The ordinary AP table contains only the entry's `JSR BOOT` row.

## Proof Boundary

All four new `.a` sources assemble in the host checks. Their package sizes and
new Bank-0 locations remain board gates: the onboard `PKG OK` length and the
installer's `PROGRAM OK` address are authoritative.
