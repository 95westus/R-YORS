# R-YORS Operator's Guide

This guide covers the current R-YORS/STR8-N split. R-YORS owns ASM-F2 and
HIMON at `$8000-$EFFF`. The adjacent standalone STR8-N repository owns the
reset supervisor, protected sector `$F000-$FFFF`, flash-install streams, Bank
Maintenance, top updater, and directory refresh tool.

Historical combined-image procedures and their hardware transcripts remain
under `DOC/GUIDES/STR8/` and `DOC/GUIDES/LOGS/`; do not use their old R-YORS
build target names for a current installation.

## Safety

Keep a verified external-programmer STR8-N BIN before changing flash. Do not
press RESET or NMI, remove power, or interrupt a transfer while a STR8-N erase,
program, restore, or protected-top operation is active.

Banks 0-2 are opaque guest systems after `J0`-`J2`. Physical RESET is the
universal return to Bank 3.

## Build And Image Ownership

With sibling checkouts named `R-YORS` and `STR8-N`:

```text
make all
```

R-YORS verifies the locked STR8-N manifest and public ABI, then builds:

```text
RELEASE/ryors-v1.2-asm-bank3-8-b.s19
RELEASE/ryors-v1.2-himon-bank3-c-e.s19
RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19
RELEASE/himon-apv2-bank3-c-e.s19
```

The last file is the dense 28K `$8000-$EFFF` payload. To compose a complete
32K Bank-0/1/2 payload, use the product that owns sector F:

```text
make -C ../STR8-N ryors-full-bank
```

This writes:

```text
RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
```

STR8-N validates the 28K S19, appends its current checked 4K top image, and
verifies the final RESET vector. For Bank 3, install `$8000-$EFFF` through the
guarded `I` path and update sector F only with the standalone programmer BIN
or guarded top updater.

For a HIMON-only APv2 update, build `make -C SRC himon-apv2-install-s19`.
At the STR8-N prompt choose `I`, Bank 3, range `C-E`, confirm the displayed
range, and send `SRC/BUILD/s19/himon-apv2-bank3-c-e.s19` only after STR8-N
prints `S19`. The file is a dense payload-only `$C000-$EFFF` stream with S9
`$C000`; it contains no `$0200` worker records and never writes sector F.

Use `STR8N_HOME=<path>` when the repositories are not siblings. `make release`
also requires the locked standalone STR8-N checkout to be clean.

## Current Integrated Layout

```text
$8000-$BAFD   ASM-F2, entry $800C
$BAFE-$BFFF   low-flash headroom/AP-store hole
$C000-$EDB3   HIMON
$EDB4-$EFFF   HIMON headroom
$F000-$FD59   standalone STR8-N v1.21 resident
$FD5A-$FD5B   available 2-byte growth margin
$FD5C-$FFAF   stored unified STR8-N worker, runs at $0200-$0453
$FFB0-$FFEF   bank directory
$FFF0-$FFF9   configuration pocket
$FFFA-$FFFF   STR8-N-owned hardware vectors
```

The Bank Jump Record is RAM `$7DFD-$7DFF = 42 4A nn`, with `$FF` meaning no
validated target is known.

## Reset And STR8-N

At physical RESET, STR8-N offers its attach/selection interval and then starts
compatible Bank-3 HIMON unless the operator selects STR8-N or another guest.
The current resident commands are:

```text
I        install a dense payload S19 in a selected legal flash-sector range
L        load a recovery S19 into RAM and execute its S9 entry
H        warm-enter compatible Bank-3 HIMON at $C000
J0-J2    enter an enrolled Bank 0, 1, or 2 guest
J3       hand off through the Bank-3 RESET vector
```

STR8-N `L` accepts RAM `$2000-$7AFF` and always executes a valid in-range S9.
Ctrl-C aborts without executing. Use it for the standalone Bank Maintenance,
console ABI probe, protected-top updater, and directory refresh artifacts.

The exact prompts, confirmations, recovery states, and artifact names are in
the standalone [STR8-N Operator's Guide](../../../STR8-N/docs/OPERATORS_GUIDE.md)
when the repositories are sibling folders.

## HIMON Commands

```text
?              help
# [token]      list records, or resolve a token without executing it
D start [end]  dump one byte or an inclusive address range
M addr         modify RAM below $7A00
G addr         execute an address
STR8           enter resident STR8-N at $F000 after confirmation
L              load S0/S1/S9 into RAM and report the S9 address
ASM            enter flash-resident ASM-F2 when present
AP ...         load/link/run an AP package
R [regs]       display or edit trapped context
B start        set a one-shot breakpoint
B C start      clear a breakpoint
B L            list breakpoints
N              single-step trapped context
X              resume trapped context
Q              quiesce with WAI
```

HIMON `L` is deliberately load-only. It does not execute S9. `L G` and `L F`
are rejected. To run a loaded program, inspect the reported S9 and issue an
explicit `G address`. HIMON rejects S1 spans at `$7A00` or above and rejects
flash destinations.

If a record is malformed or targets protected/flash space, HIMON prints the
loader error, poisons that load, and silently consumes the remaining S-records
through S9 before returning to its prompt. Later S1 records are not written.
Press Ctrl-C if a failed or truncated sender will not provide S9. Earlier valid
RAM records are retained; cancellation and failure are not rollback.

Example:

```text
>L
...send a RAM S19...
L OK ... GO=2000
>G 2000
```

This differs intentionally from STR8-N `L`, whose recovery workflow loads and
runs in one operation.

## A Complete ASM Session

ASM-F2 is already resident in the normal R-YORS 28K payload:

```text
>ASM
ASM>$2000: ORG $2000
ASM>$2000: LDA #$5A
ASM>$2002: RTS
ASM>$2003: END
SEAL> PACKAGE $3200
SEAL> LOAD $3200 $3000
SEAL> .
>D 3000 3002
>G 3000
```

During the ASM session, ASM owns its published low-RAM tables and workspace.
After `END`, `PACKAGE` emits an AP envelope. `LOAD` loads that package into
RAM; `INSTALL package flash_addr` may store it in a verified erased low-flash
hole. Exit with `.` to return to HIMON. If a detailed table report is needed,
run the separately stored ASM session reporter AP after leaving ASM.

An optional checked ASM build spends 651 additional bytes on full AP checking
and leaves only `$0108` flash headroom. The normal compact build leaves
`$0393`; use the checked variant for integrity-focused sessions, not as the
default Bank-3 image.

## RAM Debug Loop

```text
make -C SRC life
>L
...send SRC/BUILD/s19/life-2000.s19...
>B 2000
>G 2000
```

Set breakpoints after loading. HIMON `L` clears active debug patches. Debug
patch targets are limited to user RAM; monitor RAM, I/O, and flash are
protected.

## Import/Export Boundary

R-YORS has complete host-side build/export products for ASM/HIMON S19, AP
package construction, and the verified 28K integration payload. STR8-N owns
guest BIN normalization, dense install payload preparation, the full 32K
composer, protected-top artifacts, and the release manifest. There is no
resident general flash-to-S19 export command; preserve programmer readbacks
and host artifacts for full-image export and recovery.

## Further Reference

- [Memory Map](MEMORY/MEMORY_MAP.md)
- [HIMON Map](HIMON/HIMON_MAP.md)
- [ASM User Guide](ASM/ASM_USER_GUIDE.md)
- [STR8-N integration boundary](STR8/PRODUCT_BOUNDARIES.md)
- [Hardware test log](LOGS/HARDWARE_TEST_LOG.md)
