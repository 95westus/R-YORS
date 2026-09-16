# BSO2 Bank 2 Installation on COM4 — 2026-09-16

BSO2 `b s o / 2 v0 . 9` is installed in all eight Bank-2 sectors and enrolled
as COMPLETE D2 `BSO-2`, TYPE `$FF`. The board booted through STR8-N `J2` and
was left at the BSO2 `-` prompt with the serial connection closed.

## Preserved source and image

The source ZIPs in `C:\SRC\bso2 backups` contain an earlier source snapshot,
not a complete bootable ROM. This installation uses the newer preserved
working-tree source in `C:\SRC\bso2 backups\GitHub\bso2`, copied unchanged
into `LOCAL/bso2-b2/source`. No historical backup was modified.

WDC assembly/link succeeded with the original build commands. The resulting
image contains CODE at `$8000-$9791`, KDATA at `$E000-$EAA9`, and the original
WDC service ROM at `$F800-$FFFF`; all other bytes are `$FF`. BSO2 depends on
the serial entry points at `$F800/$F803/$F806/$F809`. The WDC block was copied
unchanged from `BUILD/WDCMONv2-Board-3-bank3-8000-ffff.bin`, and independently
matched the same block in the live Bank-0 backup.

RESET is `$F818`, which recognizes the `WDC` signature and enters BSO2 through
`$8004`. NMI and IRQ remain `$8007` and `$800A`. Neither source nor service ROM
was patched for Bank 2. The local manifest records build commands and inputs.

| Artifact | SHA-256 |
| --- | --- |
| Preserved `bso2.asm` | `4328f8baf2c831234d892e7736e574c8557509dedf282a93806f5258f9489e0f` |
| Complete BSO2 bank BIN | `cbb006447ceb2120cf63fc9ce3d58a3fe78c50a1ca696bb016ea055edddf4689` |
| Dense installation S19 | `7e53c019c74cf29b1714a18237554dca92761951bfe7d0a9b56a28f8374261e4` |
| Complete flash before install | `c217a467f8d348ce74cd50d91e03cc0c39e938a38e92d327793307ae58915dae` |
| Complete flash after install | `9709619831504487e8a7564209e76022346802d87fadc6f3be53ae9f160cff7e` |

The local BIN/S19 are `LOCAL/bso2-b2/bso2-bank2-8000-ffff.*`. Full before/after
128 KB backups and individual bank images are retained under
`LOCAL/bso2-b2/board/before-readback/` and `after-readback/`. The old Bank-2
contents are `before-readback/bank2.bin`, SHA-256
`25c8dce360fff94dadaad58a683f90f0d71d8a001a18dc83a1e3059d50b9d72e`.
They contained 3,104 non-erased bytes and erased hardware vectors. Installing
the full BSO2 bank replaced those contents.

## Installation and exact readback

Before writing, all four banks were archived through a small RAM sector reader
using the published STR8 selector and HIMON L/G/D. The reader copies 4 KB into
RAM and restores Bank 3 before returning. Its 167 host emulator cases used the
actual STR8-N 1.34 selector and proved exact copies, state preservation,
invalid-parameter rejection, and absence of flash writes.

The complete BSO2 image also passed emulator startup through the original WDC
RESET, short/full help, memory deposit/dump, disassembly, warm entry, and reset
cookie recovery. Across 27,447,822 emulated instructions it wrote neither ROM
nor the bank selector; Bank 2 remained selected. These host checks do not claim
hardware timing proof.

The live Bank-3 preflight matched its previous qualified image exactly, and
D2 was erased. STR8-N 1.34 accepted:

```text
I
2
8-F
FF
BSO-2
I B2 8-F WRITE? Y: Y
S19
.......COMMIT? Y: Y.
OK
```

The stream contains exactly 1,024 ascending 32-byte S1 records and S9 `$F818`.
After COMMIT, all four banks were read again. Comparison proved:

- Bank 2 exactly matches every byte of the prepared 32 KB image.
- Banks 0 and 1 are unchanged.
- Bank 3 changed only at `$FFD4-$FFD9` and `$FFDC`, enrolling D2 and completing
  its first journal pair. HIMON `00.0915(2233)`, ASM-F2 `00.0915(2243)`, STR8-N
  1.34, all other directory rows, configuration, and vectors are unchanged.

D2 at `$FFD0` is now:

```text
FF FF FF FF 42 53 4F 2D 32 FE FF FF FC FF FF FF
```

## Board boot and smoke checks

STR8-N `J2` printed `J B2`, followed by `POWER ON`, `RAM CLEARED`, the BSO2
banner, and the expected reset/NMI/IRQ chain. At its `-` prompt:

- `?` and `H` printed short and full monitor help.
- `D 8000 800F` showed the expected WDC signature and BSO2 entry jumps.
- `M 3000 A9 2A 60` followed by `D 3000 3002` verified the RAM deposit.
- `U 3000 3002` printed `LDA #$2A` and `RTS`.
- `D FFF0 FFFF` showed the expected hardware vectors.

This run proves installation, exact flash readback, software bank handoff,
and these basic monitor functions. Physical RESET/power-cycle persistence and
the rest of the legacy monitor command set were not separately qualified.

To start it later, enter `J2` at STR8-N or select `2` during startup. Wait for
the BSO2 banner before typing: early serial input selects the original WDC
binary host interface. Physical RESET is the designed return to Bank 3.

The append-only serial evidence is
[BSO2_B2_INSTALL_2026-09-16.jsonl](BSO2_B2_INSTALL_2026-09-16.jsonl).
It contains 3,918,156 bytes, SHA-256
`d07b2bae0afbf862532a01295610f0e654f17d4496b7a1b05bcde3de47f00a5e`.
Machine-readable local results are `LOCAL/bso2-b2/board/verification.json`
and `boot-smoke.json`; the retained scripts reproduce image preparation,
backup/readback, the guarded installation, and the boot smoke check.
