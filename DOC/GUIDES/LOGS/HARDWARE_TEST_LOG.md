# R-YORS Hardware Test Log

This file records bench transcripts that prove behavior on real hardware. Keep
entries short enough to scan, but include enough serial output to reconstruct
what was actually tested.

## 2026-05-17 STR8 U OSI BASIC Payload And B0 Rotation Proof

Source transcript:

```text
operator transcript pasted into Codex session
```

Build artifacts under test:

```text
Payload S19:       SRC/BUILD/s19/msbasic-osi-str8-update.s19
S1 records:        495
S19 gate:          $C000-$EFFF only
Entry:             START $C000 -> COLD_START $DD1F
FNV header:        $C003
MSBASIC entry:     $C00B
Code end:          $DEEE
Console read/write: $F6BD / $F6E4
```

### Result

Pass.

Validated:

- `E` enrolled Bank 0 into backup rotation and changed the STR8 state from
  `B0 HOLD` to `B0 ROT`.
- After enrollment, `B` erased Bank 0/1/2 and rotated `B1->B0`, `B2->B1`,
  and `B3->B2`.
- STR8 `U` accepted the OSI BASIC `$C000-$EFFF` payload stream and printed
  `OK` after confirmed erase/write/verify.
- `G HIMON` entered the new `$C000` payload and booted OSI BASIC.
- OSI BASIC printed its memory and terminal prompts, banner, and `OK` prompt.
- A simple BASIC program entered and ran: `10 PRINT "HELLO"` / `RUN` /
  `HELLO`.
- Restore from the rotated backup chain brought back the expected images:
  HIMON U2 from Bank 0, fig-Forth from Bank 1, and OSI BASIC from Bank 2 at
  the final rotation stage.

Important backup-chain lesson:

- Bank 0 enrollment makes Bank 0 a normal rotating backup slot.
- Once enrolled, `B` no longer preserves Bank 0 as a factory/base image.
- Payloads rotate exactly like HIMON. Running `B` after BASIC or Forth is an
  intentional promotion of that payload into the backup chain.

Not tested in this pass:

- STR8 self-update.
- Restore over non-erased ordinary sectors below `$C000`.
- Deliberate high-flash failure behavior with a sacrificial image.

### Transcript Extract

Bank 0 was enrolled:

```text
STR8>
B0 ROT ON. NEXT B ERASES B0. Y: y
OK
STR8>
```

The next backup included Bank 0:

```text
STR8>
BACKUP ERASE B0/B1/B2. Y: y
COPY B1->B0

COPY B2->B1

COPY B3->B2

OK
```

The BASIC payload was installed through the same fixed `U` gate:

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...............................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
```

The payload booted OSI BASIC and ran a small program:

```text
MEMORY SIZE?
TERMINAL WIDTH?

 29950 BYTES FREE

OSI 6502 BASIC VERSION 1.0 REV 3.2
COPYRIGHT 1977 BY MICROSOFT CO.

OK
10 PRINT "HELLO"
RUN
HELLO

OK
```

The rotated chain restored the expected payloads:

```text
RESTORE B0->B3 ... HIMON U2
RESTORE B1->B3 ... fig-FORTH  1.0
RESTORE B2->B3 ... OSI 6502 BASIC VERSION 1.0 REV 3.2
```

## 2026-05-17 STR8 U fig-Forth Payload Proof

Source transcript:

```text
operator transcript pasted into Codex session
```

Build artifacts under test:

```text
Payload S19: SRC/BUILD/s19/fig-forth-str8-update.s19
S1 records: 397
S19 gate:   $C000-$EFFF only
Entry:      START $C000 -> FORTH_ORIG $C00B
FNV header: $C003
Code end:   $D8C9
MON exit:   $F000
```

### Result

Pass.

Validated:

- STR8 `B` first made HIMON U1/U2 recoverable in the backup chain.
- STR8 `U` accepted a non-HIMON `$C000-$EFFF` payload stream and printed `OK`
  after confirmed erase/write/verify.
- `G HIMON` entered the new `$C000` payload and booted `fig-FORTH  1.0`.
- Simple stack words and numeric output worked from the Forth prompt.
- STR8 remained reachable after the payload boot.
- High-flash restore from a backup bank put HIMON back into Bank 3.

Important backup-chain lesson:

- `B` always means "rotate the current Bank 3 into the backup chain."
- Running `B` while Bank 3 contains fig-Forth promotes fig-Forth into Bank 2.
- After that, `2` with high flash restores fig-Forth, not old HIMON.
- To preserve old HIMON, keep at least one backup bank untouched, or restore
  from the older bank such as Bank 1.

Not tested in this pass:

- OSI MS BASIC as a `$C000` STR8 `U` payload.
- STR8 self-update.
- Deliberate failed high-flash restore behavior.

### Transcript Extract

The known-good monitor was first backed up:

```text
STR8>
BACKUP ERASE B1/B2. Y: y
COPY B2->B1

COPY B3->B2

OK
```

The Forth payload was installed through the same fixed `U` gate:

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
.............................................................................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON

fig-FORTH  1.0
```

Basic stack checks ran from the Forth prompt:

```text
1 2 4 8 OK
dup OK
. 8 OK
. 8 OK
. 4 OK
. 2 OK
. 1 OK
```

Restoring an older backup brought HIMON back:

```text
STR8>
RESTORE B1->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B1->B3

BOOT COLD
RAM ZERO OK

HIMON U2
>
```

A later restore from Bank 2 booted Forth again because a backup had been run
after Forth was installed:

```text
STR8>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3

fig-FORTH  1.0
```

## 2026-05-17 STR8 UPDATE HIMON U1->U2 And Recovery Proof

Source transcript:

```text
operator transcript pasted into Codex session
```

Build artifacts under test:

```text
ROM candidate: SRC/BUILD/bin/himon-str8-rom.bin
SHA256:        7176A1E7450A6EDF5D3102CFFDAD000325715576C8A3159E3977DBCEE439F7D5
Update S19:    SRC/BUILD/s19/himon-str8-himon-update.s19
S1 records:    315
S19 gate:      $C000-$EFFF only
Visible bytes: $E220 = 0D 0A 48 49 4D 4F 4E 20 55 B2
```

### Result

Pass.

Validated:

- STR8 `M` showed Bank 3 as the boot image before backup.
- STR8 `B` copied Bank 3 to Bank 2, making U1 the known-good recovery image.
- HIMON booted visibly as `HIMON U1` before the update.
- STR8 `U` accepted the compact `$C000-$EFFF` S19 stream, asked before
  programming, erased/wrote/verified C/D/E, and printed `OK`.
- Reboot after `U` showed `HIMON U2`, proving the visible HIMON update.
- STR8 remained reachable after the update through `G F000`.
- High-flash restore Bank 2 -> Bank 3 with `FLASH C000-FFFF? Y` restored the
  known-good U1 image.
- Reboot after restore showed `HIMON U1`.

Not tested in this pass:

- Bank 0 enrollment with `E`.
- Restore over non-erased ordinary sectors below `$C000`.
- Deliberate high-flash failure behavior with a sacrificial image.
- STR8 self-update; this pass intentionally touched HIMON `$C000-$EFFF` only.

### Transcript Extract

Backup made Bank 2 match live Bank 3:

```text
STR8>
BANK0     BANK1     BANK2     BOOT
--------  --------  --------  ----++++
...
B3 | . . . . * * * * |
STR8>
BACKUP ERASE B1/B2. Y: y
COPY B2->B1

COPY B3->B2

OK
STR8>
BANK0     BANK1     BANK2     BOOT
--------  --------  ----++++  ----++++
...
B2 | . . . . * * * * |
B3 | . . . . * * * * |
```

The baseline monitor was visibly U1:

```text
BOOT COLD
RAM ZERO OK

HIMON U1
>G F000
GO F000
```

The update stream programmed successfully:

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...........................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
```

The updated monitor booted visibly as U2:

```text
BOOT COLD
RAM ZERO OK

HIMON U2
>G F000
GO F000
```

The high-flash restore recovered the previous U1 image from Bank 2:

```text
STR8>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3

BOOT COLD
RAM ZERO OK

HIMON U1
>
```

## 2026-05-15 STR8/HIMON/HREC/Search/Debug Smoke

Source transcript:

```text
C:\Users\Walter\Desktop\putty.log
PuTTY log 2026-05-15 21:38 local
follow-on operator transcript pasted into Codex session
```

Build artifacts under test:

```text
ROM:    SRC/BUILD/bin/himon-str8-rom.bin
SHA256: 614800F0AEB1865EBAE6F67EF604999768036F0A257A8804B9FFAD4C7EFA2011
HREC:   SRC/BUILD/s19/hrec-join-proof-4000.s19
Search: SRC/BUILD/s19/himon-search-proof-3000.s19
Debug:  SRC/BUILD/s19/himon-debug-proof-3000.s19
```

### Result

Pass with one resident HIMON finding.

Validated:

- STR8 prompt, map, `G` handoff, and Bank 2 to Bank 3 restore path.
- Current ROM burn-check bytes at `$C000`, `$F000`, `$F800`, and vectors.
- HREC join proof at `$4000`, including positive joins and negative probes.
- Search RAM proof at `$3000`, including mixed-case apostrophe text, I/O skip,
  no-found, and `+0` rejection.
- Debug RAM proof at `$3000`, `BRK 41`, breakpoints, resume, `N` decode,
  `JSR` step-over, branch next-PC handling, and HREC execution through debug.
- `#` catalog listing and lookup for `BIO_FTDI_WRITE_BYTE_BLOCK`.

Finding:

- Resident HIMON shared range parsing currently treats `+n` as an inclusive
  offset rather than a byte count. Example: `D C000 +10` printed `$C000-$C010`.
  The search proof already implements the target `+count` behavior by using
  `count - 1` and rejecting `+0`.

Not tested in this pass:

- STR8 `B` backup rotation.
- STR8 `E` Bank 0 enrollment.
- Restore that programs non-erased ordinary bytes below `$C000`; the map showed
  Bank 2 and Bank 3 lower sectors erased in this session.
- High-flash restore failure/RAM-only halt behavior.

### STR8 And Burn Check

STR8 reported the expected resident shell and bank map. The restore path was
exercised from Bank 2 to Bank 3 while declining high flash.

```text
STR8 V0
ROM $F000
? B E M 0 1 2 G R
B0 HOLD
STR8>
BANK0     BANK1     BANK2     BOOT
--------  --------  ----++++  ----++++
     8 9 A B C D E F
   +---------------+
B0 | . . . . . . . . |
B1 | . . . . . . . . |
B2 | . . . . * * * * |
B3 | . . . . * * * * |
   +---------------+
STR8>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B2->B3

OK
STR8>
G HIMON
BOOT WARM

HIMON
```

Burn-check dumps matched the current ROM image:

```text
>D C000 +10
C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 34 AD E7 7E C9 | x......~...4..~.
C010: 5A | Z
>D F000 +10
F000: 78 D8 A2 FF 9A 20 1D F0 | 20 53 F0 B0 0A A2 66 A0 | x.... .. S....f.
F010: F6 | .
>D F800 +10
F800: 08 78 AD 07 0A C9 04 F0 | 09 C9 02 F0 0A 20 78 02 | .x........... x.
F810: 80 | .
>D FFFA FFFF
FFFA: 1C DE 00 F0 1F DE | ......
```

The extra `$C010`/`F010`/`F810` byte is the `+n` finding, not a burn mismatch.

### HREC Join

The HREC join proof loaded and passed all expected probes:

```text
>L G
L S19
L @4000
L OK=0248 GO=4000
HREC JOIN PROOF $4000
WRITE OK
READ OK
FLUSH OK
CTRL OK
HEX OK
MISSING OK
KIND OK
HEXINV OK
DONE

#LOADGO# ENTRY=4000
RET A=0A X=43 Y=00 P=75 S=FD NV-BdIzC
```

Catalog lookup also proved the named routine hash, while showing that `_FNV`
labels are assembler labels for record headers and are not advertised catalog
names:

```text
># BIO_FTDI_WRITE_BYTE_BLOCK_FNV
7CB4E965 HSH_NF!
># BIO_FTDI_WRITE_BYTE_BLOCK
379FE930 ENTRY=DC26 K=00
```

The full `#` listing showed duplicate helper records in HIMON and STR8 ranges.
Current lookup scans upward and first match wins, so the HIMON/BIO entry at
`$DC26` wins over the later STR8-linked duplicate at `$F3F5`.

### Search Proof

The search RAM proof loaded at `$3000` and preserved lowercase/mixed-case
apostrophe text:

```text
>L G
L S19
L @3000
L OK=0565 GO=3000
HIMON SEARCH PROOF $3000
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT
S> s 0 ffff 'aBc
780A 7800: 73 20 30 20 66 66 66 66 | 20 27 61 42 63 00 00 00 | s 0 ffff 'aBc...
7900 7900: 61 42 63 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | aBc.............
S IO
S> s 3000 30ff 4d
S NF
S> s 7f00 7fff 00
S IO
S NF
S> s 3000 +0 20
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT
S> q
S DONE
```

This validates the current RAM-proof behavior: command letters can be lowercase,
apostrophe text is exact, I/O page `$7F00-$7FFF` is skipped, no-found is loud,
and `+0` is rejected before scanning.

### Debug And Step

The debug proof loaded at `$3000`, stopped at the intentional start BRK, and
then debug was used against the already-loaded HREC proof at `$4000`.

```text
>L G
L S19
L @3000
L OK=0163 GO=3000
HIMON DEBUG PROOF $3000
BRK $41: USE N TO STEP

BRK 41 PC=3013
A=16 X=3B Y=16 P=75 S=FB NV-BdIzC
```

Breakpoints and resume through HREC:

```text
>B 4004
BP $4004
>B 4007
BP $4007
>B L
4004 20
4007 B0
>G 4000
GO 4000

@4004 A=01 X=D5 Y=41 P=75 S=FB NV-BdIzC
>X
RESUME 4004

@4007 A=00 X=26 Y=DC P=B5 S=FB Nv-BdIzC
>X
RESUME 4007
HREC JOIN PROOF $4000
WRITE OK
READ OK
FLUSH OK
CTRL OK
HEX OK
MISSING OK
KIND OK
HEXINV OK
DONE
```

Single-step `N` transcript:

```text
>B L
>B 4000
BP $4000
>G 4000
GO 4000

@4000 A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
>N
STEP PC=4000 OP=A2 LDX #$D5 LEN=02 NEXT=4002
RESUME 4000

@4002 A=01 X=D5 Y=30 P=F5 S=FB NV-BdIzC
>N
STEP PC=4002 OP=A0 LDY #$41 LEN=02 NEXT=4004
RESUME 4002

@4004 A=01 X=D5 Y=41 P=75 S=FB NV-BdIzC
>N
STEP PC=4004 OP=20 JSR $40F5 LEN=03 NEXT=4007
RESUME 4004

@4007 A=00 X=26 Y=DC P=B5 S=FB Nv-BdIzC
>N
STEP PC=4007 OP=B0 BCS $01 LEN=02 NEXT=400A
RESUME 4007

@400A A=00 X=26 Y=DC P=B5 S=FB Nv-BdIzC
```

Interpretation:

- `N` decoded immediate loads at `$4000` and `$4002`.
- `N` stepped over `JSR $40F5`, proving the join routine returned to `$4007`.
- `X/Y=26/DC` after the join is callable entry `$DC26`, matching
  `BIO_FTDI_WRITE_BYTE_BLOCK`.
- `N` computed the taken branch target `$400A` for `BCS $01`.

### Follow-Up

- Fix resident HIMON `CMD_PARSE_RANGE_PLUS` so `+count` means byte count:
  reject `+0`, compute `end = start + count - 1`, and reject wrap.
- Re-run `D C000 +10`, `U 4000 +10`, and a search proof `+count` smoke after
  the parser fix.
- Run a later STR8 destructive pass for `B` backup rotation and, separately,
  high-flash failure behavior.
