# STR8 V1 Directory-Preserving Refresh Board Test

Status: `$0091` fail-closed worker refresh/program/cold-boot hardware-accepted
as `00.0806(2135)`. Independent post-refresh directory readback and a raw
non-`$08` `$F003` probe remain open.

This card updates an already-installed V1 Bank-3 top sector without erasing or
repairing the live `$FFB0-$FFEF` directory. It is the prerequisite for testing
the directory-gated `J0-J2` interruption behavior.

Keep an external programmer and a known-good full-bank recovery image
available. Do not use the refresh writer on an old pre-V1 layout, and do not
use the one-time migration writer for this refresh.

## 1. Build and Record

From the repository root:

To reproduce the exact board-tested image rather than create a new
minute-stamped identity, use:

```text
make -C SRC str8-v1-artifact "HIMON_VISIBLE_STAMP=0806(2135)"
```

Use these two files for this test:

```text
SRC/BUILD/bin/himon-str8-v1.bin
DOC/GUIDES/ASM/SAMPLES/str8n-v1-refresh-transient-3000.a
```

Record their SHA-256 values and the visible STR8/HIMON identity. The
board-tested artifact and host layout are:

```text
tested identity    STR8-N/HIMON/ASM-F2 00.0806(2135)
himon-str8-v1.bin  B576025E5E3A6E712467A2F20F747ACCA4DC7D357FFD010DF6B7C5A83887371F
refresh source     C850105F51B2C814D18C4A3453D0FB8F60E58CD102FF7EEF9EB392DE4682E741
```

```text
resident                 $F000-$FED4
free gap                 $FED5-$FF1E  $004A bytes
packed jump worker       $FF1F-$FFAF  $0091 bytes
preserved directory      $FFB0-$FFEF  $0040 bytes
configuration/vectors    $FFF0-$FFFF
```

## 2. Snapshot the Live Directory

At Bank-3 HIMON:

```text
D FFB0 FFEF
```

Save all 64 bytes. For the already accepted first Bank-2 transaction, the
Bank-2 record at `$FFD0-$FFDF` is expected to end in journal bytes
`FC FF FF FF`. Stop if the directory differs from the state you intend to
preserve.

## 3. Assemble and Stage the Refresh

At HIMON:

```text
ASM NEW
```

Send:

```text
DOC/GUIDES/ASM/SAMPLES/str8n-v1-refresh-transient-3000.a
```

Require `ASM OK` and `SEAL>`, then enter:

```text
.
G 3000
S
Q
D 0A00 0A13
D 191F 1937
D 19B0 19EF
D 19FA 19FF
```

Require `TW STG`, `TW OK`, the candidate STR8 face at `$0A00`, the packed
jump-worker head at `$191F`, and candidate vectors at `$19FA`. Every byte at
`$19B0-$19EF` must exactly match the saved live `$FFB0-$FFEF` snapshot. Stop
before programming if any directory byte differs.

The current staged worker head and its mode gate are:

```text
191F: 4C 12 02 08 78 C9 04 B0 06 20 7C 02 28 38 60 28
192F: 18 60 AD F0 1F C9 08 F0 02 18 60 08 78 20 26 02
```

## 4. Program and Prove Preservation

Enter:

```text
G 3000
P
WRITE
I
Q
D 1A00 1A03
D F000 F013
D FFB0 FFEF
D FFFA FFFF
```

Require `TW PRG`, `TW OK`, status `01 AC 00 00`, and an exact 64-byte match
between the post-program directory and the saved snapshot. On any failure,
save `$1A00-$1A03` and do not retry before reconciling the stage and map.

Press physical RESET, enter STR8 during the live dots, and issue `J2`. The
existing COMPLETE Bank-2 record must permit the jump. This proves the new
launch gate accepts COMPLETE before any destructive interruption test begins.

## Staging Checkpoint

The 2026-08-06 board run first opened the one-time migration writer and quit
without staging or programming. It then captured the live directory, assembled
the refresh source with the `$30B4` `CDIR` loop, and returned `TW STG` / `TW
OK`. The staged `$19B0-$19EF` bytes exactly matched the live `$FFB0-$FFEF`
snapshot, including the Bank-2 COMPLETE record and `FC FF FF FF` journal.
Candidate face, packed worker head, and vectors also matched. No flash program
operation occurred in that capture, so Section 4 remained open at that
checkpoint.

The continuation issued `P`, confirmed `WRITE`, and received `TW PRG` / `TW
OK` with status `01 AC 00 00`. Installed `$F000-$F013` and the vectors matched
the staged candidate. The complete `$FFB0-$FFEF` directory also matched the
saved snapshot byte-for-byte. Physical reset booted Bank-3
`STR8-N V 00.0806(1900)`, and `J2` launched the distinct Bank-2
`STR8-N V 00.0806(1707)`. This accepts the directory-preserving refresh and
the COMPLETE-record launch gate prerequisite for interruption testing.

## Fail-Closed Worker Refresh Checkpoint

The next refresh began on Bank-3 `00.0806(1900)`. The generated
directory-preserving source assembled through `$5000` with `ASM OK`. Its
interactive path returned:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
TW> I
TW MODE=$01 RES=$AC @=$0000
```

The next cold boot identified the installed image as
`STR8-N V 00.0806(2135) $F` and reached Bank-3 HIMON. This hardware-accepts
assembly, stage verification, protected-sector erase/program/full-sector
verify, and cold boot for the `$0091` fail-closed worker image.

The updated guarded `str8-bank-maint-2000.a` then assembled with `ASM OK`.
Two `M` attempts printed `B0 !` and returned to its menu without launching
Bank 0. A `C` attempt from Bank 3 to Bank 1 also printed `!` and returned
before programming. This accepts the maintained source's fail-safe behavior
on the refreshed image.

This capture did not include the Section 2 directory snapshot, the
post-program `$FFB0-$FFEF` dump, a `J0-J2` check, or an unguarded direct
`$F003` mode-`$05/$06/$07` probe. Those narrower checks remain open and are
not inferred from the successful built-in TopWriter verify.
