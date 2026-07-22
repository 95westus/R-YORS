# Fixed-Load Banked Flash Erase AP Board Test

Purpose: prove that `flash-erase-bank-ap-2000.a` is a packageable, fixed-load
copy of the proven interactive erase tool. It is not movable: every AP run
must load it at `$2000`.

This test has one intentional Bank-0 write: storing the erase AP itself. The
first execution then aborts before any erase, proving package load and command
interaction without a destructive sector operation.

## Preconditions

- HIMON/ASM-F2 and STR8 are known-good.
- A table-free Bank-0 PUT AP is already stored; call its Bank-0 address
  `PUTPKG`.
- A reserved, erased Bank-0 sector is available for this tool. Do not select
  the only recovery copy.
- Keep an external-programmer or separate known-good recovery route.

## 1. Seal And Package The Erase AP

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/flash-erase-bank-ap-2000.a
ASM OK
SEAL OK FLAGS=$01 BASE=$2000 END=$23A5
SEAL REL @=$hhhh COUNT=$00
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
```

Stop if any `ERR=` appears while pasting, if the seal flags are not `$01`, if
the relocation count is nonzero, or if `PACKAGE` fails. The exact package
length is a recorded fact, not a precondition.

## 2. Store It In Bank 0

The package remains in the `$3000` envelope bay. Load the resident PUT tool
into `$2000`; it will ask where to store that package.

```text
>AP B0 PUTPKG $2000
```

At `DST`, choose the reserved erased Bank-0 address. At the confirmation
prompt type exact `YES`. Record the resulting address as `ERASEPKG`.

Expected shape:

```text
B0 AP PUT
PKG L=$hhhh
DST $8000-$FFFF OR ENTER=AUTO> $hhhh
STAGE OK
B0 AP @$hhhh L=$hhhh
TYPE YES TO WRITE> YES
PROGRAM OK
RET A=AC ... C
```

This is the only write in the package/load/abort proof.

## 3. Prove AP Load And Safe Abort

```text
>AP B0 ERASEPKG $2000
BANKED FLASH ERASE
BANK 0-3> 1
SECTOR 8-F OR ALL> 8
TYPE YES TO ERASE>
```

Press Enter at the `YES` prompt. Require:

```text
ABORT - NO FLASH WRITE
RET A=E0 ... c
```

No erase begins before the exact word `YES`, so this proves the Bank-0 AP
loaded at `$2000`, entered its interactive body, selected a legal target, and
honored the non-destructive confirmation path.

## 4. Optional Destructive Proof

Only with an explicitly reserved target, repeat step 3, choose the intended
bank/sector, and type exact `YES`. Require `OK`, the matching completion text,
and `RET A=AC ... C`. Dump the selected physical bank/sector afterward.

If the selected target is the Bank-0 sector containing `ERASEPKG`, the current
RAM run remains safe but the stored AP is intentionally erased. Reinstall it
before relying on it again.

Record the transcript in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`; do not alter
the historical direct-run erase evidence.
