# HIMON/STR8 Live Update Proof

This is a real terminal log from HIMON and STR8 running on the W65C02S system. It shows a ROM-resident hash dictionary for 65C02 services, with Forth instincts and assembler bones.

The important part is not just that a new S19 image was loaded. The important part is that STR8 updated the active HIMON bank, HIMON proved the new hash catalog behavior from the prompt, and STR8 restored the earlier bank afterward.

## The Version Marks

HIMON prints a build stamp in parentheses:

```text
HIMON V 00.0519(2312)
```

In this log, the stamp is the easiest way to see what is happening to bank 3.

| Stage | Bank 3 result |
| --- | --- |
| Before update | `HIMON V 00.0519(2312)` |
| After STR8 update | `HIMON V 00.0519(2317)` |
| After STR8 restore | `HIMON V 00.0519(2312)` |

That is the proof: bank 3 moved forward to `(2317)`, then came back to `(2312)`.

## Starting Point

The session starts in the older HIMON image:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0519(2312)
```

The old image can list `K=01` records, but it does not yet understand the newer comparator form:

```text
># K>2
1588A42A HSH_NF!
```

That line is useful because it proves the update changes real behavior. It is not a staged clean-room transcript.

## STR8 Updates HIMON

The user enters STR8 at `$F000` and updates HIMON in the `C000-EFFF` range:

```text
>G F000
GO F000

STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 ROT
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
........................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
```

After reset, bank 3 is now running the newer HIMON:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0519(2317)
```

## The New Hash Catalog

The new image exposes reset entries as confirmed executable records:

```text
>#
HASH     ENTRY K TEXT
EC7A30F0 C030 03 BOOT_COLD_RESET
5333AEAB C044 03 BOOT_WARM_RESET
...
B0051A80 C000 03 HIMON V 00.0519(2317)
```

The `K` filters now work:

```text
># K=02
HASH     ENTRY K TEXT

># K>00
HASH     ENTRY K TEXT
EC7A30F0 C030 03 BOOT_COLD_RESET
5333AEAB C044 03 BOOT_WARM_RESET
...
B0051A80 C000 03 HIMON V 00.0519(2317)

># K<01
HASH     ENTRY K TEXT
```

The confirmed command path also works. `BOOT_COLD_RESET` is found by hash, prompts before execution, then runs the reset path:

```text
>BOOT_COLD_RESET
RUN BOOT_COLD_RESET @C030 K=03 ? y
BOOT COLD
RAM ZERO OK

HIMON V 00.0519(2317)
```

## Backup And Restore

STR8 then rotates the backup banks:

```text
STR8>
BACKUP ERASE B0/B1/B2. Y: y
COPY B1->B0

COPY B2->B1

COPY B3->B2

OK
```

HIMON can still be entered warm from STR8:

```text
STR8>
G HIMON
BOOT WARM

HIMON V 00.0519(2317)
```

Finally, STR8 restores bank 1 back into bank 3:

```text
STR8>
RESTORE B1->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B1->B3
```

After the restore, bank 3 boots the older image again:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0519(2312)
```

## What This Demonstrates

This log demonstrates four things:

1. STR8 can update the active HIMON image in flash.
2. HIMON can expose callable services through a resident hash catalog.
3. `K=03` records can require confirmation before executing.
4. STR8 can restore a previous bank image and prove the rollback by the HIMON build stamp.

The build stamps are the quiet part that make the transcript easy to trust. Bank 3 starts at `(2312)`, becomes `(2317)`, and returns to `(2312)`.
