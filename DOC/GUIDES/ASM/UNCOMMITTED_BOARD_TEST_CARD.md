# Frozen `1157` / STR8-N `1.2` Board Test Card

Status: retained historical qualification card; superseded for current loading.

STR8-N now publishes `1.21` and the current R-YORS rebuild publishes `1303`.
Use [`UNCOMMITTED_BOARD_RETEST_CARD.md`](UNCOMMITTED_BOARD_RETEST_CARD.md) for
the current board-loadable artifacts. The results below remain evidence for
the exact `1157` / STR8-N `1.2` images and are not rewritten as `1.21` proof.

The 2026-08-14 `1157` continuation transcript accepts the current `8-E`
install/cold boot, Card B's bare-hex package plus direct/AP runs and reporter,
Card C's main relocate/package/install/load/run path, and D3's guarded rewrite,
scratch cleanup, and post-map. A fresh full-card run is still valid, but the
shortest remaining procedure is
[`UNCOMMITTED_BOARD_RETEST_CARD.md`](UNCOMMITTED_BOARD_RETEST_CARD.md): an
uninterrupted explicit `J3` plus the fixed-head/STR8 tail of final persistence.
Banked AP restore and the rebuilt-session `BABB` range probe are accepted. The
earlier `J3` capture was inconclusive because an intentional physical RESET
intervened after `J B3`; a later explicitly synthetic-RESET rerun accepts that
historical `1157` handoff.

This card qualifies the complete uncommitted R-YORS and adjacent STR8-N change
sets as built on 2026-08-14. It covers the HIMON mechanical size pass, current
ASM expression and opcode work, bare-hex `SEAL>` operands, AP v2
generation/linking, the map-matched session reporter, STR8-N's new visible
`RESET` line, and the completed guarded D3 journal compactor in Bank
Maintenance. Documentation-only, host-guard, and generated-map changes have
no independent board behavior; their source behavior is mapped to a card
phase below.

Keep a known-good Bank-3 recovery image and external programmer available.
Stop at the first unexpected byte, prompt, status, reset, or sector count and
retain the whole transcript.

## Candidate Identity

```text
HIMON / ASM-F2                 00.0814(1157)
HIMON CODE / DATA / total     $28A2 / $0512 / $2DB4
HIMON end / F000 headroom     $EDB4 / $024C
ASM CODE / DATA / UDATA       $3867 / $028F / $1D6C
ASM end / C000 headroom       $BAF6 / $050A

ryors-v1.2-asm-himon-bank3-8-e.s19
  SHA-256 C218C09E85B19DCB40C2F69EF3EDAD537290E47C5FBEA7D0AC2DBE95E61EE6A5
  range $8000-$EFFF; S9 $C000

himon-apv2-bank3-c-e.s19
  SHA-256 807CD00A14AE3E38A09606F21150901BFC2597EE7F4DDB0901DD8691CF494F7B
  range $C000-$EFFF; S9 $C000

asm-session-report-v1.2-7000.s19
  SHA-256 44053E93FEDEA918A2047992C2D579FC2117751712B4D9915FD69291192E08BD
  range $7000-$771A; S9 $7000

himon-debug-proof-3000.s19
  SHA-256 5C11BF60E3872B9B448DE0501843261E484C64BECA1522C24DD67BF6CCBB3BAA
  range $3000-$3171; S9 $3000; load bytes $0172

C:\SRC\STR8-N\BUILD\v1.2\bin\str8n-v1.2-bank3-f000-ffff.bin
  SHA-256 005BABD43999FC31DC9ADA6CA0D7F7ED0E1CAC8D1DA34015C423AE6E110A7EE3
  resident $F000-$FD58; protected-sector margin $FD59-$FD5B (3 bytes)

C:\SRC\STR8-N\BUILD\v1.2\s19\str8n-v1.2-top-update-2000.s19
  SHA-256 52777412B8BB89FCA7484745A150CBB7A54D726DBFB30F2FAC562B9358639C70
  range $2000-$4FFF; S9 $2000

C:\SRC\STR8-N\BUILD\v1.2\s19\str8n-v1.2-bank-maint-2000.s19
  SHA-256 B1088334157A242B4F94AD2228BF4DAEE6328500D6C9533BF9F57E955CF98B73
  range $2000-$362A; S9 $2000

C:\SRC\STR8-N\BUILD\v1.2\s19\ryors-v1.2-asm-himon-str8n-bank0-2-8-f.s19
  SHA-256 0A590117EFD179F3070A26E3C1FE9664839A37D7A0FC7697F41ECA2FA1972E99
  range $8000-$FFFF; S9/RESET $F000; image SHA-256
  BB84FD468FF13FFE408E49B23181729BE7BF2796633923B970CDB6CB0AC85F94
```

Host preflight passed for all 33 files under `SRC/BUILD/s19` and all seven
files under `C:\SRC\STR8-N\BUILD\v1.2\s19`: S-record length, checksum,
duplicate-address, data-presence, and termination checks. The archived
`bank3-erase-8000-bfff-3000.s19` is retained but is not a current split-V1
board artifact and must not be loaded. All 11,700 canonical HIMON bytes
compare equal in:

```text
himon-c000.s19
himon-rom-c000.s19
himon-rom-c000-install-8000.s19
himon-apv2-bank3-c-e.s19
ryors-v1.2-himon-bank3-c-e.s19
ryors-v1.2-asm-himon-bank3-8-e.s19
C:\SRC\STR8-N\BUILD\v1.2\s19\ryors-v1.2-asm-himon-str8n-bank0-2-8-f.s19
```

The full STR8-N composite's `$8000-$EFFF` slice equals the R-YORS 28K stream,
and its `$F000-$FFFF` slice equals the pinned STR8-N top BIN byte for byte.

## 1. Install The Current Bank-3 Candidate

At the unchanged STR8-N 1.2 prompt, install only Bank 3 `$8000-$EFFF`:

```text
STR8-N>I
B0-3: 3
RANGE: 8-E
I B3 8-E WRITE? Y: Y
S19
```

Send exactly:

```text
SRC/BUILD/s19/ryors-v1.2-asm-himon-bank3-8-e.s19
```

Require seven completed sectors, the final commit question, and `OK`:

```text
......COMMIT? Y: Y.
OK
STR8-N>
```

This stream does not contain or rewrite Bank-3 sector F. Do not continue after
`FAIL`, the wrong dot count, a reset, or silence at end of file.

Perform a physical RESET and allow the normal selector timeout. Require:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0814(1157)
>
```

## 2. Update And Prove The Current STR8-N Top Sector

This phase rewrites protected Bank-3 sector F. Keep the known-good old and new
top-sector BINs off-board, and continue only if Bank 1 sector F is sacrificial;
the updater uses physical `$0F000-$0FFFF` as its verified backup. Do not use
RESET, NMI, or remove power after active erase begins.

From HIMON enter `STR8`, confirm with `y`, then at `STR8-N>` enter:

```text
L
```

Send exactly:

```text
C:\SRC\STR8-N\BUILD\v1.2\s19\str8n-v1.2-top-update-2000.s19
```

Require:

```text
STR8-N 1.2 TOP UPDATE
BACKUP B1:F; TARGET B3:F
TYPE BACKUP B1F>
```

Type `BACKUP B1F` only after confirming Bank 1 sector F may be overwritten.
Require `BACKUP VERIFIED`, record the printed old-sector sum, then type the
exact second confirmation `STR8-N 1.2`. Require:

```text
ERASING B3:F - NO RESET/NMI/POWER
STR8-N 1.2 VERIFIED; RESET
RESET
WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
```

Allow the selector to time out and require the `1157` HIMON cold boot. Then
perform one physical RESET and require exactly one fresh `RESET` line before
the six `WAIT...` pulses, followed by the same STR8-N identity and another
successful HIMON cold boot. Missing, duplicated, or late `RESET` text fails
the new STR8-N behavior.

If active programming fails, do not reset: use updater command `R` to retry or
`O` to restore the verified Bank-1 backup. Use the external programmer if the
RAM updater cannot recover.

## 3. Cold/Warm Initialization And Shared Text

Check the fixed head and the newly loop-initialized service/AP cells:

```text
D C000 C00F
D 7E23 7E40
```

Require:

```text
C000: 4C 07 C0 A5 5A C3 3C 78 | D8 A2 FF 9A A2 03 20 14

7E23-7E24 = 00 00
7E25-7E26 = 9B D2
7E27-7E2C = 00 00 00 00 00 00
7E2D-7E2E = 56 D4
7E2F-7E40 = all 00
```

The two nonzero words are the current `HIM_FLASH_INSTALL_COPY=$D29B` and
`HIM_AP_SERVICE=$D456` service entries. Everything else in the specified AP
request/result range must be zero.

Exercise the shared/suffix-compatible strings:

```text
?
# HIMON
D 7F00 7FFF
```

Require the help line `#? D M R X G AP L B N Q STR8`, a HIMON row containing
`#B0051A80# ENTRY=C000 K=03` and the `1157` identity, plus these exact I/O
names and suffix:

```text
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
```

Now exercise both reset-signature paths:

```text
HWARM
```

Answer the confirmation with `y`. Require `BOOT WARM`, the same `1157`
banner, and a normal prompt. Repeat `D 7E23 7E40` and require the same service
words and zero cells.

```text
HCOLD
```

Answer `y`. Require `BOOT COLD`, `RAM ZERO OK`, the same banner, prompt, fixed
head, and service/AP-cell dump. This closes the new reset-signature loop, the
new service-cell clear loop, startup tail calls, and the shared boot strings.

## 4. Loader, Dump, Modify, Quiesce, And Context

At HIMON `>` enter `L`, then send:

```text
SRC/BUILD/s19/asm-session-report-v1.2-7000.s19
```

Require:

```text
L OK=071B ENTRY=7000
```

Check its map-matched head:

```text
D 7000 700F
```

Require:

```text
7000: A2 67 A0 75 20 5E 75 20 | 5E 70 20 33 70 20 A7 71
```

Exercise writable and protected `M` returns:

```text
M 7900
```

Enter `A5`, then:

```text
D 7900
M 7E05
```

Require `$7900=$A5` and `M PROT=$7E05`.

Enter `Q`, then use the board's normal NMI control once to leave `WAI`.
Require an `NMI PC=` line, one register/flags line, and a live prompt. Enter:

```text
R
X
```

`R` must reproduce a valid NMI context. `X` must print `RESUME`, return through
the interrupted monitor path, and leave a working prompt. A hang, repeated
banner, malformed flags, or `NOCTX` fails this phase.

## 5. Debug, Breakpoint, Step, And Resume

Enter `L` and send:

```text
SRC/BUILD/s19/himon-debug-proof-3000.s19
```

Require `L OK=0172 ENTRY=3000`, then:

```text
G 3000
R
N
B 3043
B L
B C 3043
B L
X PC=3043
```

Required landmarks:

```text
HIMON DEBUG PROOF $3000
BRK $41: USE N TO STEP
BRK 41 PC=3013
STEP PC=3013 OP=18 CLC LEN=01 NEXT=3014
BP $3043
3043 A2
B C $3043
RESUME 3043
DEBUG PROOF DONE
BRK 42 PC=304C
```

The second `B L` must be empty. No `$E1-$E9` BRK is permitted. This phase
covers `G`, `R`, `N`, `B`, `X`, BRK re-entry, mnemonic output, address/flags
printing, and the debug-message tail calls.

## 6. ASM And Direct AP Cards

Run Cards A-C in
[`FINAL_IMAGE_ONBOARD_TEST_CARDS.md`](FINAL_IMAGE_ONBOARD_TEST_CARDS.md)
against this installed `1157` image. The `$7000` reporter loaded in Phase 4 is
the required map-matched reporter.

Use bare hexadecimal for every `SEAL>` command operand. In particular:

```text
RELOCATE 3000
PACKAGE WRONG 3200
PACKAGE START 3200
INSTALL 3200
LOAD 3200 3000
```

Card B's `AP 3200 3000` is the required positive direct-AP execution. In Card
C, after the final successful `LOAD` and before leaving `SEAL>`, also enter:

```text
RELOCATE BABB
```

Require `REL ERR=$06`, not `BAD OPER`. This proves a letter-leading bare-hex
operand is recognized while the target-range guard still fails closed. Then
leave with `.` as directed by Card C.

Cards A-C must each end with their documented result; both reporter runs must
end in `ASM REPORT OK`. Entering `$`-prefixed compatibility forms does not
qualify the new bare-hex gate.

## 7. Banked AP Stage/Restore

Use a deliberately invalid package pointer one byte into Bank 0's ordinary
image. This reads/stages but does not write flash or execute a BODY:

```text
AP B0 8001 3000
```

Require:

```text
APERR=$07
>
```

Then enter `ASM`, require `ASM-F2 00.0814(1157)`, and leave its source prompt
with `.`. A failure to restore Bank 3, an AP status other than `$07`, a BODY
run, or a lost HIMON/ASM identity fails this phase.

## 8. STR8-N D3 Journal Compaction

This phase qualifies the new guarded `R` branch in the current Bank Maintenance
RAM artifact. It is destructive to Bank-3 sector F, so keep a recovery image
available and do not reset, use NMI, or remove power during `B3F REWRITE`.

At HIMON load
`C:\SRC\STR8-N\BUILD\v1.2\s19\str8n-v1.2-bank-maint-2000.s19` with `L`.
Require `L OK=162B ENTRY=2000`, then enter `G 2000`. At the maintenance menu,
enter `M` and require the exact preconditions:

```text
B1 E E E E E E E U
D3 FF RYORS C000 00000000
```

Bank 1 sector 8 must be erased; Bank 1 sector F may remain used. Enter `R`,
select directory `3`, and require:

```text
B3F REWRITE
SCRATCH B1:8
TYPE RESET J3>
```

Type exactly `RESET J3`. Require `BACKUP VERIFIED`, a final `OK`, and a return
to the maintenance menu. Enter `M` again and require D3's identity unchanged,
its journal compacted, and the scratch sector erased again:

```text
B1 E E E E E E E U
D3 FF RYORS C000 FCFFFFFF
```

Enter `Q`. STR8-N must restart normally. At `STR8-N>` enter `J3`; require the
normal RESET-vector path to return to STR8-N, then select HIMON normally. Any
`J3 NOT FULL`, `NO ERASED SCRATCH`, changed D3
identity, used B1:8, or missing `BACKUP VERIFIED` fails this phase.

## 9. Final Persistence

Perform one final physical RESET and allow the normal timeout. Require the
`RESET` before the six attach pulses, then the same cold boot, `RAM ZERO OK`,
HIMON `1157`, and fixed `$C000` head. Enter `ASM`, require ASM-F2 `1157`, leave
with `.`, then enter `STR8`, confirm with `y`, and require the STR8-N 1.2
prompt.

Append the exact transcript to
[`../LOGS/HARDWARE_TEST_LOG.md`](../LOGS/HARDWARE_TEST_LOG.md). Only after all
nine phases pass should the HIMON mechanical-size, SEAL bare-hex, STR8-N
visible-reset, and D3 journal-compaction board statuses be marked accepted.

## Coverage Map

| Uncommitted area | Board evidence |
| --- | --- |
| `SRC/HIMON/himon*.asm/.inc` | Phases 1 and 3-5, 7, and 9 |
| `SRC/ASM/asm-v1-core.asm`, flash wrapper, runtime-paste wrapper | Phase 6, Cards A-C, and `BABB` rejection |
| AP checker/session-report generator and map-patched samples | Host preflight, reporter loads/runs, direct and banked AP phases |
| `SRC/INTEGRATION/str8n.lock.json` | Pinned top-sector hash, Phase 2 update, and final combined-image equality |
| `C:\SRC\STR8-N\src\str8.asm` | Phase 2 visible `RESET` on updater entry and physical RESET |
| STR8-N Bank Maintenance source/checker and D3 journal guides | Phase 8 guarded B3F rewrite, identity retention, scratch cleanup, and `J3` launch |
| STR8-N margin-check tools and Makefile | Host layout pass: resident `$F000-$FD58`, all three bytes `$FD59-$FD5B` retained |
| STR8-N README and operator/technical/example/map guides | Phase 2 transcript and the verified three-byte layout boundary |
| ASM/HIMON guides and sample-address updates | Commands and expected map values in Phases 3-7 |
| Generated maps/graphs and planning-only AIM/DC entries | Review artifacts only; no separate board execution |
