# ASM Address Practices

This is the quick operator guide for choosing addresses while using ASM,
`SEAL`, `PACKAGE`, `INSTALL`, `LOAD`, and HIMON `AP`. The main rule is:
package addresses, body addresses, flash storage addresses, and run addresses
are different roles even when the same four hex digits sometimes appear.
The current Bank-0 assignments and pending AP entries are recorded in
[SAMPLES/bank0-ap-entry-points.md](SAMPLES/bank0-ap-entry-points.md).

## The Short Model

```text
ASM source PC       where ASM emits the BODY bytes now
SEAL base/end       the frozen BODY span from the last clean END
PACKAGE addr        where an AP envelope is written as data
INSTALL addr        where that AP envelope is stored in visible flash
LOAD dest           where BODY bytes are copied/relocated in RAM
AP pkg addr         where HIMON reads the AP envelope from RAM/flash/bank
AP dest             where HIMON loads/runs the BODY in RAM
```

An AP envelope is not the executable body. It is a container holding seal,
relocation, export/import, and body sections. You can copy the envelope around
as data. You only get runnable code after `LOAD`, `RELOCATE`, or `AP` copies
the BODY to a RAM destination and applies relocation rows.

The short Deck Plan name for this container is an **AP Capsule (APC)**. Its
normal working route is the **AP Island Runway (AIR)**: Build Bay `$2000-$2FFF`,
Envelope Bay `$3000-$3FFF`, and Run/Tray Bay `$4000-$4FFF`. The Capsule Rule
applies: an APC stored in flash is data, not executing code.

## Prompt Ownership

```text
ASM>$hhhh:   source lines: ORG, labels, instructions, END
SEAL>        post-END commands: SEAL, RELOCATE, PACKAGE, LOAD, INSTALL, NEW, .
>            HIMON commands: D, G, L, #, STR8, AP
```

If `G`, `D`, or `AP` fails at `SEAL>`, exit with `.` first.

## Usual Addresses

```text
$2000-$2FFF  AIR Build Bay: source/body and fixed RAM transient island
$3000-$3FFF  AIR Envelope Bay: Bank 0 APC, then normal load/run space
$3123        useful non-page-aligned relocation proof destination
$3200        common RAM AP envelope/package buffer outside the bank 0 flow
$4000        recommended load/run address for movable session reporter AP
$4800        legacy fixed run address for asm-session-report-4800.a
$8000        visible flash ASM address; also bank-window address for banked AP
B0:$hhhh     Bank 0 ASM session reporter AP package store address
$9000        common banked AP package store address for smoke tests
$0200-$09FF  LRS Symbol Name Lane; later STR8 Worker Code Tray
$0A00-$19FF  LRS Fixup Name Lane; later STR8 Sector Staging Deck
$1A00        sample/tool status byte area
$1B00-$1B0F  Flash Transaction Card for interactive flash APs
$1C00-$1CFE  Console Input Deck for interactive flash APs
$1FE9-$1FFF  STR8 Recovery State Capsule
$5000-$61A9  ASM Work Hold in the current map
$61AA-$79FF  Safe Output Deck
$7A00-$7DFF  Volatile Output Deck
$7E00-$7EFF  High Service Deck (HSD)
$7F00-$7FFF  I/O Bulkhead, do not use as ordinary RAM
$F000-$FFFF  STR8 protected top sector
```

For the compact Bank 0 flow, keep transient code and packageable BODY bytes in
`$2000-$2FFF` and write the one-sector envelope at `$3000-$3FFF`. The current
HIMON AP loader still limits BODY destinations to `$2000-$4FFF`; flash ASM may
emit into the separate upper arena beginning at the map-reported workspace end.

## Current AP Envelope Limit

The current `$1000` limit is on the complete serialized AP envelope, not on
ASM output in general and not on a separately reserved metadata block. The
package length is:

```text
$001B fixed package bytes
+ ($01 + 5 * relocation count)
+ serialized EXPORT record length
+ serialized IMPORT record length
+ sealed BODY length
```

Empty EXPORT and IMPORT records are two bytes each. With no relocations, the
minimum envelope overhead is therefore `$0020`, leaving at most `$0FE0` bytes
for BODY data. Imports, exports, and relocations reduce that BODY maximum.

`PACKAGE $3000` means "write the envelope beginning at RAM `$3000`." It does
not mean that the package is `$3000` bytes long. A maximum-size envelope there
occupies `$3000-$3FFF`. The `$1000` check is a current one-sector package and
installer policy; it is not imposed by the AP header's address field widths.

After an APC has been written at `$3000-$3FFF`, `$4000-$4FFF` is still a usable
Run/Tray Bay, but it has no automatic role. It may hold transient data, an AP
load destination, a sector tray, or a session reporter, but those uses must not
overlap. This is the Runway Rule. A separate source may begin with `ORG $4000`; adding
`ORG $4000` to a BODY that began at `$2000`, however, does not create a second
independent package segment. `SEAL` records one span from the initial PC
through the high-water PC, including the hole, so that span would already
exceed the current AP envelope limit.

ASM-F2's own high UDATA is not at `$4000`; it currently begins at `$5000`.
Moving UDATA down to `$4000` is possible only as a new map decision, and would
evict both reporter forms and the remaining lower AP load/transient island.

Practical larger-program options are to run a direct RAM transient without
packaging, split code/data into several APs, keep resources in disposable data
APs, or add a future multi-sector/segmented package format. Merely raising the
`$1000` constant would also require new package-buffer placement, multi-sector
Bank 0 staging/programming, discovery, loader checks, and board proof.

## Source Lifecycle Names

Sample names containing `-transient-$hhhh.a` are normally fixed-address RAM
programs: paste them, leave ASM, run them with `G hhhh`, and discard them.
`bank0ap-put-transient-2000.a` retains its historical filename but now also
has `ENTRY BANK0_AP_PUT` and packages as a fixed-load Bank-0 AP. Other sources
with `ENTRY` are AP-capable. The legacy `$4800` reporter is fixed-load; the new
`asm-session-report-ap-2000.a` self-relocates its complete internal body.

## RAM Package Recipe

Use this when you want to assemble a body, make an AP envelope in RAM, load it
somewhere else in RAM, and run it.

```text
>ASM NEW
ASM>$2000: ORG $2000
ASM>$2000: MAIN ...body...
ASM>$hhhh: ENTRY MAIN        optional; keep it at BODY offset zero for HIMON AP
ASM>$hhhh: END
ASM OK
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$llll
SEAL> LOAD $3200 $3000
LOAD OK=$3000 L=$bbbb C=$rr
SEAL> .
ASM BYE
>G 3000
```

In that recipe, `$3200` is the AP envelope address. `$3000` is the relocated
BODY address. They are not interchangeable.

## Visible Flash Install Recipe

Use this when the AP envelope should live in the currently visible low-flash
window and be reloadable later.

```text
SEAL> PACKAGE $3200
SEAL> INSTALL $3200
INST @=$hhhh L=$llll
SEAL> INSTALL $3200 $hhhh
INST @=$hhhh L=$llll
SEAL> .
```

`INSTALL $3200` only suggests an erased flash hole. It does not write. Use the
printed `$hhhh` in `INSTALL $3200 $hhhh` to write the unchanged AP envelope.

Later, from HIMON:

```text
>AP $hhhh $3000
```

Here `$hhhh` is the installed AP envelope source address. `$3000` is the RAM
load/run destination.

## Banked AP Recipe

Use this when the AP envelope should live in bank 0-2 instead of the currently
visible flash window. Bank 2 is the preferred test bank.

```text
>ASM NEW
ASM>$2000: ...AP body source...
ASM>$hhhh: END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$llll
SEAL> .
ASM BYE
>D 3200 5       expect 41 50 version lenlo lenhi
>ASM NEW        paste bankput-transient-3000.a
ASM>$30D4: END
ASM OK
SEAL> .
ASM BYE
>G 3000
>D 1A00 8       expect AC at $1A00
```

Then run the ordinary banked package from HIMON:

```text
>AP B2 $9000 $3000
```

In `AP B2 $9000 $3000`, `$9000` is the AP envelope address in bank 2's flash
address space, and `$3000` is the RAM destination/run address. The body does
not execute from banked flash.

Keep `$3200` unchanged between `PACKAGE $3200` and the completed `G 3000`
writer run. Do not run `AP`, `LOAD`, or another `PACKAGE` in that interval.
`bankput-transient-3000.a` returns `$E2` when the package header or length at `$3200` is
no longer valid.

For the bench command sequence, use
[LIFE16_QUICK_CARD.md](LIFE16_QUICK_CARD.md). For the reasons behind it, use
[LIFE16_BANK2_EXAMPLE.md](LIFE16_BANK2_EXAMPLE.md). The example assembles
`SAMPLES/life16-column-2000.a`, stores the AP envelope in bank 2 at `$9000`,
and runs it with `AP B2 $9000 $3000`.

## Bank 0 AP Install

Use this only when Bank 0 is the intended AP package store.
`bank0ap-put-transient-2000.a` is both a direct `G 2000` RAM tool and a
fixed-load AP package. It consumes the target AP envelope at `$3000`, stages
the selected Bank-0 sector at `$0A00-$19FF`, validates the staged package,
asks for exact `YES`, then programs and verifies the sector. Its required AP
load address is `$2000`.

Bootstrap the installer once by assembling that file at `$2000`, packaging it
at `$3000`, then running its still-present BODY directly with `G 2000`.
Record its actual `PKG OK` length and the Bank-0 address printed by the
installer as `PUTPKG`. The appendable installer has internal relocations but
must remain within HIMON's `$10` relocation-row limit.

During assembly, the LRS holds its Symbol and Fixup Name Lanes. Starting the
STR8 worker reloads the Worker Code Tray at `$0200` and reuses the SSD at
`$0A00-$19FF`. This is the Switchyard Rule: it intentionally ends the
reportable ASM session after `PACKAGE` has serialized the APC metadata.

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
>G 2000
```

At the `DST` prompt, enter a bank 0 address such as `$8000`, or press Enter to
append after the last framed `AP/01` envelope in the first sector whose clean
erased tail can hold the new envelope. It does not reuse an interior `$FF`
run, and it never crosses a 4K sector boundary. At the confirmation prompt,
type exact `YES`. On success, `$1A00=$AC`, `$1A01/$1A02` hold the selected package address, and
`$1A06=00`. It also clears `$1A06` on abort or failure.

For every later target, assemble the target BODY, create its envelope at
`$3000`, exit ASM, and load the resident installer at its required `$2000`
address:

```text
SEAL> PACKAGE $3000
SEAL> .
ASM BYE
>AP B0 PUTPKG $2000
```

In that command, `PUTPKG` is where the installer envelope is stored in Bank 0.
`$2000` is where HIMON loads and runs the installer BODY. Neither operand is
the new target's flash address; the installer asks for that address at its
`DST` prompt, or chooses the first verified clean append tail when Enter is
pressed.

The current hand-held board card uses archived fixture
`DOC/GUIDES/ASM/SAMPLES/OLD CODE/bank0ap-print-smoke.a`, packages it at `$3000`,
stores it in bank 0 at `$8000`, and expects the AP body to print `B0 AP RUN`.

`bank0ap-stage-transient-2000.a` and `bank0ap-commit-transient-2000.a` remain available for
diagnosing the staged sector or separating the irreversible write from the
selection pass. They are not the normal operator path.

## Session Reporter From Bank 0

The preferred Bank-0 reporter source is now
`asm-session-report-ap-2000.a`. Its AP entry is `START`, its body is `$0C5F`,
and its expected package is `$0C8B`. It accepts AP destinations
`$2000-$43A1`; `$4000` is recommended and occupies `$4000-$4C5E`.

The reporter has one ordinary AP relocation, then applies its own 224-row
private table to every remaining internal address. This makes the whole body
load-address relocatable despite ASM's 16-row ordinary relocation limit. It
is still ASM-map-matched because it reads current ASM-F2 tables and calls
current ASM-F2 output helpers. Rebuild and reinstall it after an ASM code or
map change.

Build its envelope with `PACKAGE $3000`, then store it with
the resident `BANK0_AP_PUT`. The printed Bank-0 package address is the first
operand of the later `AP B0` command; `$4000` is its RAM load/run address.

Load the stored reporter before the ASM session you want to inspect:

```text
>AP B0 $hhhh $4000
>ASM NEW
...assemble the target session...
SEAL> .
ASM BYE
>G 4000
```

The initial `AP` also runs the reporter once; that preliminary report may be
ignored. Its important job is to leave the patched reporter resident before
the target session begins. If the target session fails before `END`, exit
source mode with `.` and use `G 4000`.

The older `asm-session-report-4800.a` remains available for a board that
already stores it. That form must be loaded and later rerun at exactly `$4800`.
Do not cold boot, warm boot, reload the reporter, start another session, run a
banked `AP`, or invoke a flash worker first. Those operations overwrite state
or reuse the low-RAM symbol/fixup name pools.

## Best Practices

- Use `$2000` for RAM transients and small sealed bodies unless the sample says
  otherwise.
- Use `$3200` for ordinary RAM AP envelopes and `$3000` for Bank 0 install.
- Use `$3000` as the default load/run destination for ordinary AP tests.
- Use `$3123` when you deliberately want to prove relocation across an odd
  page offset.
- Use `INSTALL $3200` as an address finder, then copy its printed address into
  `INSTALL $3200 $hhhh`.
- Do not install into visible `$8000-$BFFF` unless you mean to overwrite the
  flash ASM image. Prefer the suggested erased hole or a banked AP install.
- Use bank 2 first for destructive banked AP storage tests.
- Use `$` on literal hex addresses in ASM and `SEAL>` commands.
- Keep `PACKAGE` buffers, `LOAD` destinations, and status bytes separate.
- Dump `$1A00` after board-buildable installers; `$AC` is the usual success
  byte for these samples.
- Run HIMON `D`, `G`, and `AP` only from the `>` prompt.

## Common Mistakes

```text
PACKAGE $3200 then G 3200
```

Wrong: `$3200` is an AP envelope, not the relocated body.

```text
INSTALL $3200 then assume flash was written
```

Wrong: one-argument `INSTALL` is advisory. Use the two-argument form to write.

```text
AP B0 $hhhh $4800 for the movable session reporter
```

Legal for the legacy fixed reporter, but needlessly fixed for the movable
reporter. Prefer its recommended destination:

```text
AP B0 $hhhh $4000
```

```text
LOAD $3200 $3200
```

Usually wrong: the package source and body destination overlap.

```text
ORG $5000
```

Wrong under flash ASM: `$5000-$7EFF` is live ASM/HIMON workspace.

```text
Run reporter after BOOT or L F
```

Wrong for session inspection: those actions destroy or replace the live session
state the reporter is meant to read.
