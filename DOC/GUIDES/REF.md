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
M start [end|+count]  modify protected-range-checked RAM
G addr         execute address
L              load S0/S1/S9 into RAM; report S9, do not execute
STR8           confirmed jump to $F000
ASM            enter ASM-F2
AP pkg dst                 direct RAM/visible-package recovery form
AP Bn name|s000 [dst]      load/link/run installed carrier through APMAN
AP L Bn name|s000 [dst]    load/link installed carrier; do not run
APS                        Bank 0-2 carrier/media status
APS Bn                     list valid carriers in one bank
APS Bn name|s000           show one validated carrier
B/N/R/X        breakpoint, step, context, resume
```

`L G` and `L F` are not HIMON commands. Use `G` explicitly after HIMON `L`.

## STR8-N

```text
I        guarded dense flash-range install
L        load recovery RAM S19 and execute S9
C        cold-enter compatible Bank-3 HIMON
W        warm-enter compatible Bank-3 HIMON
J0-J2    enter enrolled Bank 0-2 guest
J3       use Bank-3 RESET vector
```

STR8-N `L` and HIMON `L` deliberately have different execution semantics.
HIMON delegates record parsing to STR8-N `$F009` `SR/02` and fails closed if
that service is absent or incompatible.

## Accepted AP Carrier Inventory

```text
B2:8  APMAN     package L=$0B40, transient body $7000-$7B11
B2:9  BANKDUMP  package L=$09AD, default body $2000-$292B
B1:E  WORK      configured application work sector
B1:F  BKUP      protected B3:F backup
B3:F  PROTECTED live STR8-N top sector
```

`SEAL> INSTALL package Bn` accepts Banks 0-2 and selects the first fully erased
4K sector. It does not rely on a hard-coded bank personality.

For the complete Bank 0-3 physical map, run `AP B2 BANKDUMP` and enter `M` at
its first prompt.

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
