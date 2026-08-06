# STR8 V1 Directory-Preserving Refresh Board Test

Status: host-built; hardware proof pending.

This card updates an already-installed V1 Bank-3 top sector without erasing or
repairing the live `$FFB0-$FFEF` directory. It is the prerequisite for testing
the directory-gated `J0-J2` interruption behavior.

Keep an external programmer and a known-good full-bank recovery image
available. Do not use the refresh writer on an old pre-V1 layout, and do not
use the one-time migration writer for this refresh.

## 1. Build and Record

From the repository root:

```text
make -C SRC str8-v1-artifact
```

Use these two files for this test:

```text
SRC/BUILD/bin/himon-str8-v1.bin
SRC/BUILD/str8n-v1-refresh-transient-3000.a
```

Record their SHA-256 values and the visible STR8/HIMON identity. The accepted
host layout for this slice is:

```text
resident                 $F000-$FED4
free gap                 $FED5-$FF27  $0053 bytes
packed jump worker       $FF28-$FFAF  $0088 bytes
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
SRC/BUILD/str8n-v1-refresh-transient-3000.a
```

Require `ASM OK` and `SEAL>`, then enter:

```text
.
G 3000
S
Q
D 0A00 0A13
D 1928 1937
D 19B0 19EF
D 19FA 19FF
```

Require `TW STG`, `TW OK`, the candidate STR8 face at `$0A00`, the packed
jump-worker head at `$1928`, and candidate vectors at `$19FA`. Every byte at
`$19B0-$19EF` must exactly match the saved live `$FFB0-$FFEF` snapshot. Stop
before programming if any directory byte differs.

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
