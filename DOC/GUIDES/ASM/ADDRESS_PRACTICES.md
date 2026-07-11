# ASM Address Practices

This is the quick operator guide for choosing addresses while using ASM,
`SEAL`, `PACKAGE`, `INSTALL`, `LOAD`, and HIMON `AP`. The main rule is:
package addresses, body addresses, flash storage addresses, and run addresses
are different roles even when the same four hex digits sometimes appear.

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

## Prompt Ownership

```text
ASM>$hhhh:   source lines: ORG, labels, instructions, END
SEAL>        post-END commands: SEAL, RELOCATE, PACKAGE, LOAD, INSTALL, NEW, .
>            HIMON commands: D, G, L, #, STR8, AP
```

If `G`, `D`, or `AP` fails at `SEAL>`, exit with `.` first.

## Usual Addresses

```text
$2000        default ASM source PC and common sealed-body origin
$3000        common RAM load/run destination for AP bodies
$3123        useful non-page-aligned relocation proof destination
$3200        common RAM AP envelope/package buffer
$4000        4K-split RAM AP envelope/package buffer
$4800        fixed run address for asm-session-report-4800.a
$8000        visible flash ASM address; also bank-window address for banked AP
$B969        current built-in ASM session reporter AP package store address
$9000        common banked AP package store address for smoke tests
$0A00-$19FF  STR8 4K sector staging buffer
$1A00        sample/tool status byte area
$5000-$7EFF  ASM/HIMON workspace while ASM is active
$7F00-$7FFF  I/O page, do not use
$F000-$FFFF  STR8 protected top sector
```

Under the 4K-split flash ASM contract, keep packageable generated code in
`$2000-$2FFF`, AP load/run overlays in `$3000-$3FFF`, and RAM AP envelopes in
`$4000-$4FFF`. Do not assemble or load into `$5000-$7FFF`.

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
>ASM NEW        paste bankput-3000.a
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
`bankput-3000.a` returns `$E2` when the package header or length at `$3200` is
no longer valid.

For the bench command sequence, use
[LIFE16_QUICK_CARD.md](LIFE16_QUICK_CARD.md). For the reasons behind it, use
[LIFE16_BANK2_EXAMPLE.md](LIFE16_BANK2_EXAMPLE.md). The example assembles
`SAMPLES/life16-column-2000.a`, stores the AP envelope in bank 2 at `$9000`,
and runs it with `AP B2 $9000 $3000`.

## Bank 0 AP Install

Use this only when bank 0 is the intended AP package store. The helper is a
two-piece `G 2000` flow, not an AP package itself. The stage piece consumes
the RAM AP envelope at `$4000`, stages the selected bank 0 sector at
`$0A00-$19FF`, and overlays the AP envelope in the staged copy only. The
commit piece asks for `YES` and programs the staged sector.

The flow follows the 4K split: helper code emits in `$2000-$2FFF`, the final
AP body runs from the `$3000-$3FFF` overlay, and the RAM AP envelope lives at
`$4000-$4FFF`. Do not let any piece cross into the next island; split again if
needed.

```text
SEAL> PACKAGE $4000
SEAL> .
ASM BYE
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-stage-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-commit-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
```

At the `DST` prompt, enter a bank 0 address such as `$8000`, or press Enter to
let the helper choose the first erased bank 0 hole that fits the AP envelope
inside one 4K sector. After the stage piece, `$1A00=$AC`, `$1A01/$1A02` hold
the selected package address, and `$1A06=$5A` marks the staged sector ready.
After commit success, `$1A00=$AC` and `$1A06=00`. Run it with:

```text
>AP B0 $hhhh $3000
```

The current hand-held board card uses
`DOC/GUIDES/ASM/SAMPLES/bank0ap-print-smoke.a`, packages it at `$4000`,
stores it in bank 0 at `$8000`, and expects the AP body to print `B0 AP RUN`.

## Session Reporter From Bank 2

The bank 2 reporter is special because it is fixed-address. It contains literal
internal calls and must be loaded at `$4800`.

Its `bank2put-8000-3000.a` helper stores at bank 2 `$8000`. Those `$8000` and
`$4800` addresses belong to the reporter procedure, not the Life procedure.

After the ASM session you want to inspect:

```text
SEAL> .
ASM BYE
>AP B2 $8000 $4800
```

If the session fails before `END`, exit source mode with `.` and run the same
command. Do not cold boot, warm boot, reload ASM, or start a new session before
running the reporter, because the report reads the live ASM tables in RAM.

## Best Practices

- Use `$2000` for small sealed bodies unless the sample says otherwise.
- Use `$3200` for RAM AP envelopes. Keep the emitted BODY below it.
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
AP B2 $8000 $3000 for the stored session reporter
```

Wrong for the fixed reporter. Use `$4800` as the destination:

```text
AP B2 $8000 $4800
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
