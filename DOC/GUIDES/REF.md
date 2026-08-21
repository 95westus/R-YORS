# R-YORS Quick Reference

## Source Lanes

```text
SRC/HIMON        current monitor source
SRC/ASM          current onboard assembler source
SRC/LIB          shared board/ROM support
SRC/APPS         standalone applications
SRC/PROOFS       current proof scaffolds
SRC/TESTS        test harnesses
SRC/INTEGRATION  locked external STR8-N contract
SRC/ARCHIVE      retired code/data
SRC/tools        host build and verification tools
```

STR8-N implementation source and release tools live in the adjacent `STR8-N`
repository.

## Flash Layout

```text
$8000-$BFFF  ASM-F2 / R-YORS low flash
$C000-$EFFF  HIMON
$F000-$FFFF  standalone STR8-N protected sector
```

R-YORS builds a dense 28K `$8000-$EFFF` S19. STR8-N composes the complete 32K
Bank-0/1/2 payload and owns all sector-F installation/update paths.

## HIMON

```text
?              help
# [token]      list/resolve FNV records
D start [end]  dump one byte or inclusive range
M addr         modify protected-range-checked RAM
G addr         execute address
L              load S0/S1/S9 into RAM; report S9, do not execute
STR8           confirmed jump to $F000
ASM            enter ASM-F2
AP ...         load/link/run AP package
APS            provisional read-only AP-sector header inventory
B/N/R/X        breakpoint, step, context, resume
Q              quiesce
```

`L G` and `L F` are not HIMON commands. Use `G` explicitly after HIMON `L`.

## STR8-N

```text
I        guarded dense flash-range install
L        load recovery RAM S19 and execute S9
H        warm-enter compatible Bank-3 HIMON
J0-J2    enter enrolled Bank 0-2 guest
J3       use Bank-3 RESET vector
```

STR8-N `L` and HIMON `L` deliberately have different execution semantics.

## Public STR8-N Contract

```text
$F003   console init
$F006   ABI query
$F009   S-record service (SR/02, capabilities 03)
$F010   bank select service
$F013   character input
$F019   character output
$F03E   character ready
$0203   return-capable RAM selector
$7DFD-$7DFF   Bank Jump Record "BJ", bank/FF
```

The generated `str8n-public.inc` and
`SRC/INTEGRATION/str8n.lock.json` are authoritative; private STR8-N labels are
not R-YORS interfaces.

## Make Targets

```text
make -C SRC all                     verify STR8-N; build ASM/HIMON 28K
make -C SRC ryors-v1.2              build versioned R-YORS payload slices
make -C SRC str8n-external-check    verify manifest/lock/public ABI
make -C SRC himon-banked-ap-check   verify selector and AP staging boundary
make -C SRC asm-test                build/run ASM smoke checks
make -C SRC life                    build standalone Life S19/BIN
make -C SRC docs                    regenerate source-derived R-YORS docs
make -C SRC help Q=<term>           search targets
make -C ../STR8-N ryors-full-bank   compose complete Bank-0/1/2 payload
```

`make release` requires a clean external STR8-N checkout whose content matches
the lock.

## Key Documents

- [Operator's Guide](OPERATORS_GUIDE.md)
- [Technical Guide](TECHNICAL_GUIDE.md)
- [Memory Map](MEMORY/MEMORY_MAP.md)
- [ASM User Guide](ASM/ASM_USER_GUIDE.md)
- [STR8-N Boundary](STR8/PRODUCT_BOUNDARIES.md)
- [Hardware Test Log](LOGS/HARDWARE_TEST_LOG.md)
