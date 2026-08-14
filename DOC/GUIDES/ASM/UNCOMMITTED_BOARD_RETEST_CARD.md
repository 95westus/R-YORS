# STR8-N `1.21` / R-YORS `1303` Board Card

Status: host-accepted and board-accepted; all three phases complete.

This card supersedes the `1157` residual procedure. The retained `1157`
transcripts accept the ASM/HIMON behavior, including Card B, Card C, bare
`BABB`, banked AP restore, and D3 journal compaction. A final `1157` capture
explicitly identifies the RESET after `J B3` as synthetic and accepts the
uninterrupted Bank-3 handoff for that installed image. The current rebuild
publishes STR8-N `1.21`, consumes one authorized resident-growth byte, and
carries a new generated R-YORS `1303` identity.

Do not repeat the destructive D3 compaction. Install and identify the current
images, smoke the renamed RAM tool, then repeat one uninterrupted `J3` as a
current-image integration and identity smoke. Do not press RESET or send any
input after `J3`; wait for the synthetic RESET and cold HIMON identity.

## Candidate Identity

```text
STR8-N                         1.21
HIMON / ASM-F2                 00.0814(1303)
STR8 resident                  $F000-$FD59; 3418 bytes
available before worker        $FD5A-$FD5B; 2 bytes
worker                         $FD5C-$FFAF; unchanged

SRC/BUILD/s19/ryors-v1.2-asm-himon-bank3-8-e.s19
  SHA-256 9B638FCCD949E2A3E5A5A01C8F14EB7CE7DA103769DF07DDD214BABE3D2D25D1

C:\SRC\STR8-N\BUILD\v1.21\bin\str8n-v1.21-bank3-f000-ffff.bin
  SHA-256 442E316F7C0A502E5D6635408076423C397930A710452E28A936DCA96796047E

C:\SRC\STR8-N\BUILD\v1.21\s19\str8n-v1.21-top-update-2000.s19
  SHA-256 AF369B21DCEB83CF5F323B2277345756DF09E185B4DCAB87E1CCA3899996EEED

C:\SRC\STR8-N\BUILD\v1.21\s19\str8n-v1.21-bank-maint-2000.s19
  SHA-256 D243E7D1DDB6E34604CB6AA5BB6138628C9CF0029A1C71FFB18DD0EC37EAD919

C:\SRC\STR8-N\BUILD\v1.21\s19\ryors-v1.2-asm-himon-str8n-bank0-2-8-f.s19
  S19 SHA-256 6CE8CCDB56D40BED21E646986347AD5A7B7DB59F707DA11B3D3C75BDAB7D0AB5
  image SHA-256 641A15855D427F1D3FF7425236DE711D1071EC34A15854485943D3D7AA29D5A1
```

## 1. Install R-YORS `1303` In Bank 3

Board status: accepted 2026-08-14. A complete `8-E` install committed with
seven program/verify dots and `OK`; warm HIMON reported `00.0814(1303)`. A
later transfer failed closed after the six non-final sectors and before
`COMMIT`; its remaining S-records were rejected at the STR8-N shell, and a
clean retry completed normally. The failed transfer has no proven root cause
and is retained as fail-closed/retry evidence.

At the installed STR8-N prompt, use `I`, Bank `3`, and range `8-E`. Send:

```text
C:\SRC\R-YORS\SRC\BUILD\s19\ryors-v1.2-asm-himon-bank3-8-e.s19
```

Require seven program/verify dots, the commit confirmation, `OK`, and a live
STR8-N prompt. Allow a normal Bank-3 cold boot and require:

```text
HIMON V 00.0814(1303)
ASM-F2 00.0814(1303)
```

## 2. Install The STR8-N `1.21` Top Sector

Board status: accepted 2026-08-14. The updater verified the B1:F backup,
reported target sum `$08F8`, erased and verified B3:F, then entered the new
RESET vector and displayed STR8-N `1.21`.

This rewrites protected Bank-3 sector F. Bank 1 sector F is the verified
temporary backup and must be sacrificial. Do not press RESET/NMI, remove power,
or interrupt transfer after active erase begins.

Enter STR8, confirm with `y`, issue `L`, and send:

```text
C:\SRC\STR8-N\BUILD\v1.21\s19\str8n-v1.21-top-update-2000.s19
```

Require:

```text
STR8-N 1.21 TOP UPDATE
BACKUP B1:F; TARGET B3:F
TYPE BACKUP B1F>
```

After confirming Bank 1 sector F is disposable, type `BACKUP B1F`. Require
`BACKUP VERIFIED`, then type the exact final confirmation `STR8-N 1.21`.
Require `STR8-N 1.21 VERIFIED; RESET` and automatic entry through the new RESET
vector. If programming fails, use the updater's `R` retry or `O` restore path;
do not reset a partially written top sector.

## 3. Persistence, RAM-Tool Smoke, And Uninterrupted `J3`

Board status: accepted 2026-08-14. The first RESET in the supplied capture was
physical and intentional; every later RESET in that capture was synthetic. The
physical boot retained STR8-N `1.21`, cold-booted HIMON `1303`, matched the
fixed `$C000` head, and entered ASM-F2 `1303`. The renamed Bank Maintenance
tool loaded, displayed a valid map and D3 `RYORS C000 00FFFFFF`, and quit
without mutation. Explicit `J3` then produced its own RESET and cold-booted
matching STR8-N `1.21` / HIMON `1303` without physical intervention.

Perform one intentional physical RESET and touch nothing through the timeout.
Require `RESET`, six `WAIT...` pulses, `STR8-N 1.21`, `BOOT COLD`,
`RAM ZERO OK`, and HIMON `1303`. Check:

```text
D C000 C00F
```

Require:

```text
C000: 4C 07 C0 A5 5A C3 3C 78 | D8 A2 FF 9A A2 03 20 14
```

Enter `ASM`, require ASM-F2 `1303`, and leave with `.`. Enter STR8, confirm
with `y`, issue `L`, and send the v1.21 Bank Maintenance S19 named above.
Require `STR8-N 1.21 BANK MAINT`, a live menu, and use `Q` without performing a
mutation.

At the returned STR8-N prompt enter `J3`, then touch nothing. One continuous
capture must show:

```text
STR8-N>J3
J B3
RESET
WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.21
0-2 H S: ......
BOOT COLD
RAM ZERO OK

HIMON V 00.0814(1303)
```

The `RESET` line after `J B3` must be produced by the command, not by the
physical RESET control. Append the exact transcript to
`../LOGS/HARDWARE_TEST_LOG.md`.

## Result

Accepted. The current STR8-N `1.21` / R-YORS `1303` board installation,
physical-reset persistence, ROM head, ASM identity, RAM-tool smoke, directory-
gated synthetic RESET-vector handoff, and final cold identity all match this
card.
