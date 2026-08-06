# STR8 V1 Migration and First Transaction Board Test

Status: hardware-accepted on `00.0806(1707)`.

Accepted evidence includes TopWriter status `01 AC 00 00`, the exact `$F000`
service face, packed `$FF28-$FFAF` jump worker, empty `$FFB0-$FFEF` directory,
vectors, physical-reset entry, compact command surface, first COMPLETE Bank-2
transaction, `J2`, `42 4A 02`, and reset-persistent directory state.

This card installs the fitted V1 supervisor into Bank 3, verifies the packed
jump worker and empty directory, then proves one complete journaled `I`
transaction using Bank 2. Bank 2 is erased and replaced. Use another bank only
after changing every Bank-2 address and expectation below.

Keep an external programmer and a known-good 32K/128K recovery image available.
Do not begin if Bank 2 contains anything that has not been backed up.

## Build and Record the Candidate

From the repository root:

```text
make -C SRC str8-v1-artifact
```

The build must pass and produce:

```text
SRC/BUILD/bin/himon-str8-v1.bin
SRC/BUILD/s19/himon-str8-v1-install.s19
SRC/BUILD/s19/str8-v1-i-bank012.s19
SRC/BUILD/str8n-v1-topwrite-transient-3000.a
```

Record SHA-256 values for all four files. The full-bank install S19 is an
external/recovery transport. The `str8-v1-i-bank012.s19` file is the only file
sent at the `I` command's `SEND S19` prompt; it already contains the mutation
worker followed by the complete bank payload.

The accepted host layout is:

```text
resident                 $F000-$FEC3
reserve/free gap         $FEC4-$FF27  $0064 bytes
packed jump worker       $FF28-$FFAF  $0088 bytes
empty directory          $FFB0-$FFEF  $0040 bytes
configuration/vectors    $FFF0-$FFFF
```

## 1. Record the Installed Starting State

At HIMON:

```text
D F000 F013
D FF28 FFEF
D FFFA FFFF
D 1FFD 1FFF
```

Save the output. This is evidence for recovery; it is not expected to match
the V1 bytes below.

## 2. Stage and Inspect the V1 Top Sector

At HIMON:

```text
ASM NEW
```

Send file:

```text
SRC/BUILD/str8n-v1-topwrite-transient-3000.a
```

Require `ASM OK` and `SEAL>`, then enter:

```text
.
G 3000
S
Q
```

Require `TW STG` and `TW OK`. Inspect the staged top sector:

```text
D 0A00 0A13
D 1928 1937
D 19B0 19EF
D 19FA 19FF
```

Require:

```text
0A00: 4C 13 F0 4C 46 F7 18 60 EA 4C 19 F9 53 52 01 07
0A10: 4C 4D F7 78
1928: 4C 12 02 08 78 C9 04 B0 06 20 73 02 28 38 60 28
19B0-19EF: every byte FF
19FA: AB F0 00 F0 BF F0
```

Stop if any byte differs. Rebuild and reconcile the map before programming;
do not substitute addresses from an older candidate.

## 3. Program Bank 3 Sector F

Enter:

```text
G 3000
P
WRITE
I
Q
D 1A00 1A03
D F000 F013
D FF28 FF37
D FFB0 FFEF
D FFFA FFFF
```

Require:

```text
TW PRG
TW OK
TW MODE=$01 RES=$AC @=$0000
1A00: 01 AC 00 00
F000: 4C 13 F0 4C 46 F7 18 60 EA 4C 19 F9 53 52 01 07
F010: 4C 4D F7 78
FF28: 4C 12 02 08 78 C9 04 B0 06 20 73 02 28 38 60 28
FFB0-FFEF: every byte FF
FFFA: AB F0 00 F0 BF F0
```

Stop and preserve `$1A00-$1A03` on any failure. Do not retry `P` before
recording the failure tuple.

## 4. Boot and Command-Surface Check

Press physical RESET. During the live selector dots press `S`. Require the
normal clear/dot/banner shape followed by:

```text
I 0-3 J0-3
STR8-N>
```

Enter `?`, `G`, and `R` separately. Each is now unmatched input and must return
to the same compact help and prompt. Bare `3` must still enter HIMON warm; use
HIMON `STR8` to return.

## 5. Journaled Bank-2 Install

At `STR8-N>`, enter the following one response at a time:

```text
I
2
A5
RYORS
Y
```

Require the summary to name Bank 2, range `$8000-$FFFF`, type `$A5`,
description `RYORS`, state `EMPTY`, and pair `$00`. At `SEND S19`, send exactly
one file:

```text
SRC/BUILD/s19/str8-v1-i-bank012.s19
```

Do not separately send the mutation-worker S19. Require eight sector dots and:

```text
I OK
STR8-N>
```

Enter warm HIMON without clearing RAM, then dump the new directory record:

```text
3
D FFD0 FFDF
```

Require:

```text
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF FC FF FF FF
```

This proves immutable metadata, seal, and journal pair 0 COMPLETE. Any failure
must leave the record nonlaunchable or visibly incomplete; save the complete
record and the printed failure code before recovery.

## 6. Launch and Reset Recovery

At STR8:

```text
J2
```

Require `J B2`, then a fresh STR8 startup from the installed Bank-2 image.
Press `S` during its live dots and require `I 0-3 J0-3`. Dump the Bank Jump
Record when practical and require `42 4A 02`.

Press physical RESET. Bank 3 must return to the same V1 STR8 selector. Enter
HIMON and dump `$FFD0-$FFDF` again; the Bank-2 COMPLETE record must still match
the bytes above.

The complete serial evidence, candidate hashes, exact visible identities, and
the recovered wrong-artifact pre-pass are recorded in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.
