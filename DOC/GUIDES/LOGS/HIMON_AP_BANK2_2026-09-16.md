# Persistent APMAN Bank-2 board cycle - 2026-09-16

Bank 2 now holds the tested APMAN at `$8000` and an onboard-built APTEST smoke
fixture at `$9000`. Sectors A-F are erased. COM4 at 115200 baud passed 22
workflow/isolation checks and five physical-reset follow-up checks using HIMON/ASM-F2 `00.0915(2324)` and
STR8-N 1.34. No firmware source, build stamp, or published release changed in
this slice. The preceding [contract correction and extraction](../AP/HIMON_AP_CONTRACT_CHANGE_2026-09-16.md)
identifies the exact workbench bytes and their passing full host regression.

## Authorized conversion and recovery copies

The operator authorized discarding the temporary BSO2 multi-image validation
in Bank 2. Before mutation, the previously qualified read-only RAM sector
reader archived all four banks and restored Bank 3 after every sector. The
complete 128K backup matched the expected live images, including the exact
BSO2 Bank-2 SHA-256
`cbb006447ceb2120cf63fc9ce3d58a3fe78c50a1ca696bb016ea055edddf4689`.

STR8-N 1.34 Bank Maintenance performed `E / 2 / ALL / ERASE 2ALL`, verified
all eight sectors, then `R / 2 / CLEAR D2`. Reclaim printed `BACKUP VERIFIED`
before rewriting B3:F. Full readback proved that Bank 2 was entirely `$FF`
and that only the old D2 row was cleared in Bank 3. The temporary B2:F backup
was erased after the protected-sector rewrite passed verification. B1:F's
existing backup was preserved.

STR8-N's resident installer then accepted the exact dense 4K APMAN carrier:

```text
I / 2 / 8 / A2 / APC02
I B2 8-8 WRITE? Y: Y
S19
COMMIT? Y: Y.
OK
```

D2 is now `A2 APC02 FFFF FCFFFFFF`. Bank 2 is application storage, with erased
hardware vectors; do not launch it with `J2` or the boot selector's `2` choice.
Its stored packages are launched through HIMON `AP`.

## Persistent workflow

- `APS` discovers all existing carriers and the new manager. Named manager
  discovery reports exactly `APMAN L=0C2E @7000` at B2:$8000.
- `AP D` by name and sector address inspects the manager. Attempted execution
  and load-only execution of APMAN each return a single `$DB` self guard.
- `AP L B1 BANKAUDIT 5000` loads without execution. Named execution at `$5000`
  links the existing imports, reports all 32 sector CRCs, restores Bank 3,
  and returns to HIMON. A missing child returns one `$D1` diagnostic/status.
- Fresh onboard ASM produces an exact independently encoded `$0034`-byte
  APTEST envelope. Its six-byte BODY is `00 00 A9 5A 38 60`, with exported
  entry offset `+2`. The leading zero bytes deliberately distinguish the
  BODY base from the entry point.
- Real `INSTALL 3000 B2` writes the first erased sector, B2:$9000, through
  APMAN's carried worker and returns status `$AC`. ASM restarts at `$2000`
  with symbol/fixup counts zero. The source package at `$3000` remains exact.
- Persistent APTEST runs at destinations `$2000`, `$5000`, and `$6FFA`, with
  GO entries `$2002`, `$5002`, and `$6FFC`. The last BODY ends at `$6FFF`.
  A separate RAM caller captures the resident MANAGER/child RTS result as
  A=`$5A`, C=1. A destination of `$6FFB` fails `$D4` before copying and leaves
  the `$6FF0-$6FFF` sentinel intact.
- `ASM S` refuses the invalidated session with `EXEC ERR=$03`. Both STR8
  software W and C entries clear the resume byte, rediscover the persistent
  manager, and run APTEST again.

The automation initially expected the older combined maintenance menu's
`BM>` prompt; the current standalone tool prints `Q/ENTER=QUIT>`. This stopped
before mutation. A second harness assertion expected G's register report
after a named AP command; that path correctly returns directly to the HIMON
prompt. The harness was corrected and rerun; the explicit RAM caller then
measured A/C. The raw serial evidence retains the initial runs and corrected
reruns.

## Exact final flash state

| Region | Result / SHA-256 |
| --- | --- |
| Bank 0 | Unchanged: `2f0000c74eceec809a814e31f822702977d7bfed5ee6f3bc4869627864ca59a8` |
| Bank 1 | Unchanged: `bdba6529824b41be3d4d9d862532c4ba30c455c4391408dcef7d72d3b9b30211` |
| Bank 2 | Exact APMAN sector, exact APTEST sector including FF tail, six erased sectors: `52011800db06a1c13b3c86688f1a55d35e079590e8b92073a11253e82c84fb44` |
| Bank 3 | Only the intended D2 identity changed: `3eead7cab55b85c887eb67ff1720584931d5fee934a099e3c88358029927c533` |
| Complete 128K flash | `eae12365e00769d88006d3da3caae0c18cd41ad28f3e7336f52bd33af2899b4e` |

HIMON, ASM, STR8 executable bytes, vectors, role configuration, other directory
rows, and the D3 journal are unchanged. APMAN remains exactly 3,072 BODY bytes
with no overlay headroom. Its package SHA-256 is
`4bf5ad6432f379acca19adc2d352fcacf207a1fcce5bd842beb219235aab67ef`;
its 4K carrier SHA-256 is
`cb35dca62db5523b536dfd42ff30ab618c5e9f3a241b6a8f38319258f794c5f9`.

## Physical gates

The operator confirmed pressing physical RESET. The receive-only capture
contains `RST H`, STR8-N 1.34, default `BOOT WARM`, and HIMON
`00.0915(2324)`. The resume byte was cleared; both B2 carriers were rediscovered;
APTEST ran at `$5002` with its exact BODY. Fresh ASM assembled and ran
`LDA #$AC / SEC / RTS`, returning A=`$AC`, C=1. Complete Bank-3 readback remained
byte-identical. COM4 was closed at the HIMON prompt.

NMI and operator-observed bank/sector LED values were not qualified in this
cycle; the LED feature queue remains open for its visual gate. Software W/C
success is recorded separately above.

## Retained evidence

The [evidence manifest](HIMON_AP_BANK2_2026-09-16/manifest.json) hashes the raw
serial transcript, exact input artifacts, before/final bank images, erased
checkpoint, onboard fixture, scripts, and machine-readable check results.
Local transaction checkpoints and full intermediate readbacks remain under
`LOCAL/himon-ap-bank2-20260916/`. Original BSO2 and earlier HIMON/AP transcripts
were preserved. There was no commit or release publication.
