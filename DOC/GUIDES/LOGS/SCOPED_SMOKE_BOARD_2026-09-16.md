# Scoped discovery: step-2 board smoke — 2026-09-16

The operator extended step 2 to include board smoke and flashing where needed.
The coordinated HIMON/AM02 pair is installed on COM4 and policy is **`$A6`**.
Host gates, installation/readback, disabled and enabled smoke, physical reset,
and final four-bank isolation **PASS**. This is bounded smoke acceptance;
the broader scoped-discovery board matrix remains open.

## Installed bytes and isolation

HIMON remains visibly `00.0915(2324)` but is now the 12,280-byte scoped image,
ending `$EFF8` with 8 bytes free. B2:8 contains AM02, BODY 3,059 bytes ending
`$7BF3` with 13 bytes free. ASM is unchanged. Roles/policy are `$FF/$2F/$A6`.

| Checkpoint | Complete 128 KiB SHA-256 |
| --- | --- |
| Fresh baseline | `3266041931068fd5a03db030eaef902be61bf2678fa75f1c559cee6df70741dc` |
| Pair installed, policy FF | `8134582cfc6567a43b5cef3b53fa93094410dacc86bd541f15989fb2cfa94b17` |
| Policy A6, before smoke | `8e75c342dcee502c1fcf5c1f2e5e024f88f4f91551bf6b4a0b9440379afff45e` |
| Final after physical reset | `8e75c342dcee502c1fcf5c1f2e5e024f88f4f91551bf6b4a0b9440379afff45e` |

Only B2:8, B2:F, and B3:C/D/E/F changed. Every changed byte matches the prepared
expected image. B0, B1 including its old B1:F backup, B2:9 APTEST, all other
carriers, and B3:8-B ASM are preserved exactly. STR8 `I` advanced the expected
B2/B3 directory journal bits; immutable directory metadata is unchanged.

B2:F is now the exact paired pre-policy top (`$FFF2=$FF`), SHA-256
`2888941e6fbbd6f80f4046a96268ca84eaa6396ea7acd9babfa05793268ca795`.
Live B3:F is the same image with policy `$A6`, SHA-256
`dee6d2a5416501a69debb4f8ac8953d6d422e8c4289206ed91908f78c96a53ee`.
Earlier backup generations remain in the archived readbacks. No test carrier
was flashed or removed.

## Smoke results

| Policy | Operation | Observed result |
| --- | --- | --- |
| FF | `AP B2 APTEST 5000` | `APMAN NF`; no launch |
| FF | bare `APTEST` | `HSH_NF!`; no launch |
| FF and A6 | Direct RAM `AP 3000 5000` | `GO 5000`, return A=5A; exact BODY bytes |
| FF and A6 | ASM NEW, assemble LDA/SEC/RTS, `G 2000` | Exact bytes; return A=AC |
| A6 | `AP B2 APTEST 5000` | B2:9 load, `GO 5002`, exact BODY |
| A6 | bare `APTEST` | B2:9 discovery, `GO 2002`, exact BODY |
| A6 | `AP B0 APTEST 5000` | `APMAN ERR=$D1`; no launch |
| A6 | `APS B2 APMAN` | B2:8, envelope `$0C21`, destination `$7000` |
| A6 | Physical RESET | `RST H`, HIMON return, exact live top, successful APTEST rerun |

The initial direct-RAM test reused APTEST, whose export entry is BODY+2.
Direct HIMON AP intentionally executes BODY base; that test caused a BRK at
`$5002`. The corrected RAM-only fixture uses entry offset zero and passes.
The first enabled test expected `APERR=` instead of the actual manager-domain
`APMAN ERR=$D1`. That assertion was corrected and the full enabled smoke rerun
passed. Both original logs and harness versions are retained. Neither correction
changed firmware. Final isolation confirms no incidental flash changes.

## Evidence and remaining gates

The [host record](SCOPED_HOST_GATES_2026-09-16.md) retains the full regression,
65,536 policy cases, 59 scoped cases, nine image identities, size checks, 432
maintenance role cases, and four updater variants. The
[board evidence](SCOPED_SMOKE_BOARD_2026-09-16/manifest.json) retains four complete
archives, raw serial, scripts, both corrected test attempts, and exact checks.
The [recovery card](../AP/SCOPED_POLICY_AND_PAIR_RECOVERY_2026-09-16.md) remains
the basis for rollback; choose the backup generation matching the live state.

Still open: on-board BANKDUMP import/link/menu proof, B1 positive discovery,
malformed/duplicate fixtures, the broader role-guard matrix, and exact LED/
bank-selection observation. B0's serial refusal and unchanged bytes do not
establish electrical proof that it was never selected. RAM-provider/HREC
discovery and SPI SRAM WORK remain separate implementation work. Do not mark
the combined scoped-search queue item complete from this smoke pass.
