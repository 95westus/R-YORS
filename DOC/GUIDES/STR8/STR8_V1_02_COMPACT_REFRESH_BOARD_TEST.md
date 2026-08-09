# STR8 V1.02 Compact-Image Refresh Board Test

Status: prepared from commit `ee45327281b2`; board proof pending.

This is the final proof for the compact V1.02 resident. It refreshes only Bank
3 sector F through the directory-preserving writer. It does not reinstall ASM,
HIMON, any Bank 0-2 payload, or any directory record.

Keep an external programmer and a known-good full-bank image available. Stop
if the live `$FFB0-$FFEF` directory cannot be captured exactly.

## 1. Reproduce The Frozen Candidate

From the repository root:

```text
make -C SRC str8-v1-artifact "HIMON_VISIBLE_STAMP=0808(2058)"
```

Use the generated refresh source, not the older tracked hardware-evidence
copy under `DOC/GUIDES/ASM/SAMPLES`:

```text
SRC/BUILD/generated/asm-samples/str8n-v1-current-compact-refresh-transient-3000.a
```

Before opening the terminal, verify that exact path from PowerShell:

```text
Get-FileHash SRC/BUILD/generated/asm-samples/str8n-v1-current-compact-refresh-transient-3000.a -Algorithm SHA256
```

Require these identities:

```text
source commit                  ee45327281b2
visible STR8 identity          STR8-N V 00.0808(2058) $F
himon-str8-v1.bin SHA-256      B786C0A5C33B72212EADFBE9289A3293825CAB9830CF412E0EADC548EA41668B
refresh source SHA-256         BFC071230493EC6F8E09717CC4E6EFAEB396AD4D40B5E1BBD754A2EBEF1389DB
```

The pasted source header must also say `FACE CHECK: ROM $FD37` and
`PROMPT CHECK: ROM $FD60`. `$FD79`/`$FDA2` identifies the older tracked
candidate and is an immediate stop.

The compact layout is:

```text
resident                       $F000-$FE5E  $0E5F bytes
free/reserve gap               $FE5F-$FF1E  $00C0 bytes
packed jump worker             $FF1F-$FFAF  $0091 bytes
preserved live directory       $FFB0-$FFEF  $0040 bytes
configuration                  $FFF0-$FFF9  all $FF
NMI / RESET / IRQ-BRK          $F09C / $F000 / $F0B0
```

## 2. Snapshot The Live Sector

At Bank-3 HIMON:

```text
D FFB0 FFEF
D FFF0 FFFF
```

Save all 64 directory bytes. `$FFF0-$FFF9` should be erased. Do not proceed if
the directory differs from the state you intend to preserve or the config
pocket is not the expected erased/default state.

## 3. Assemble, Stage, And Verify

Enter `ASM NEW`, send the generated refresh source above, require `ASM OK`,
finish with `.`, then:

`ASM OK` creates the writer and its embedded image at `$3000/$4000`; it does
not update the `$0A00-$19FF` flash tray. `S` is mandatory after every assembly
or candidate change, even when an older tray already exists.

```text
G 3000
S
V
Q
D 0A00 0A13
D 185F 186E
D 191F 192E
D 19B0 19EF
D 19F0 19FF
```

Require `TW STG`, `TW OK`, and a second `TW OK` from `V`. The staged directory
at `$19B0-$19EF` must match the saved live `$FFB0-$FFEF` bytes exactly.
Require these other staged bytes:

```text
0A00: 4C 13 F0 4C 3E F7 18 60 EA 4C F5 F8 53 52 01 07
0A10: 4C 44 F7 78
185F: FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
191F: 4C 12 02 08 78 C9 04 B0 06 20 7C 02 28 38 60 28
19F0: FF FF FF FF FF FF FF FF FF FF 9C F0 00 F0 B0 F0
```

Stop before programming on any mismatch.

## 4. Program And Read Back

Run the writer again and authorize only the exact Bank-3 prompt:

```text
G 3000
P
WRITE
I
Q
D 1A00 1A03
D F000 F013
D FE5F FE6E
D FF1F FF2E
D FFB0 FFEF
D FFF0 FFFF
```

Require `TW PRG`, `TW OK`, and:

```text
1A00: 01 AC 00 00
F000: 4C 13 F0 4C 3E F7 18 60 EA 4C F5 F8 53 52 01 07
F010: 4C 44 F7 78
FE5F: FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
FF1F: 4C 12 02 08 78 C9 04 B0 06 20 7C 02 28 38 60 28
FFF0: FF FF FF FF FF FF FF FF FF FF 9C F0 00 F0 B0 F0
```

The post-program directory must be byte-for-byte identical to the saved
snapshot.

## 5. Reset, Handoff, And NMI Smoke

Press physical RESET, press `S` during the live dots, and require:

```text
STR8-N V 00.0808(2058) $F
0/1/2=BOOT H=HIMON S=STR8
I H J0-3
```

Enter `H`. It must print `BOOT WARM` and reach the marked local HIMON without a
bank jump. The HIMON version remains the already installed Bank-3 payload; a
sector-F refresh does not replace `$C000-$EFFF`.

At the HIMON prompt, press NMI once. Require a legible register/flag report and
a returned prompt with no control characters in the eight flag positions. If
the transient flag-render anomaly recurs, do not reset or power-cycle first;
capture the HIMON banner plus:

```text
D 7EE6 7EFF
D CF62 CFCF
```

Finally press physical RESET once more and allow the normal Bank-3 cold path
to reach HIMON. This closes the exact compact-image refresh gate. It does not
reopen the already accepted range, journal, AP, or bank-jump matrices.

## Rejected Old-Source Checkpoint

The first 2026-08-08 attempt accidentally pasted the older tracked refresh
source. Assembly, `S`, and `V` succeeded because that source and its embedded
image were internally consistent, but the required external identity checks
rejected it:

```text
staged face       4C 13 F0 4C 55 F7 ... 4C 1C F9   not compact
staged $185F      4C 20 A4 20 52 45 46 55 ...      not erased gap
staged vectors    9E F0 00 F0 B2 F0                not compact
```

The live directory was copied exactly into the tray. The operator issued `Q`
without `P`; there was no `TW PRG`, confirmation prompt, or flash mutation.
That attempt is rejected-stage evidence only and leaves this proof pending.

## Rejected Stale-Tray Checkpoint

The next attempt assembled the correct compact source: its header named
`$FD37/$FD60`, embedded identity was `00.0808(2058)`, and embedded vectors were
`9C F0 00 F0 B0 F0`. The operator then selected `P` without first selecting
`S`, so the tray still contained the rejected older image.

`P` performed its mandatory pre-program stage verification and returned:

```text
TW ERR=$E0 @=$0A00
TW MODE=$02 RES=$E0 @=$0A00
```

It never printed the confirmation prompt or `TW PRG`. The following live dumps
still showed the old `4C 55 F7` face, message bytes at `$FE5F`, and
`9E F0 00 F0 B2 F0` vectors, with the directory unchanged. This accepts the
stale-tray fail-closed guard; it is not a compact-image program attempt.
