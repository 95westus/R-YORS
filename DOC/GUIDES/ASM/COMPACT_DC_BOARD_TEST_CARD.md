# ASM-F2 Compact DC Board Test Card

Candidate: HIMON/ASM-F2 `00.0814(1524)` with STR8-N `1.21`.

Host status: accepted. Board status: accepted on 2026-08-14.

This card qualifies the compact raw/CSTR/HBSTR/PSTR syntax, legacy-source
compatibility, empty encodings, character-literal isolation, transaction
rollback, and SEAL relocation/package/load ownership. It does not install an
AP package into flash.

## Frozen artifacts

```text
SRC/BUILD/s19/ryors-v1.2-asm-himon-bank3-8-e.s19
  SHA-256 78AB587871552620805FCC79F3CD3CFBBD1508A645E9050586C92F600AD21D48
  range $8000-$EFFF; S9 $C000

SRC/BUILD/s19/asm-v1-flash-8000.s19
  SHA-256 D7B7729ADFFD42F096C1E555C2DBD435A00D1B61E4A4A4152564AB7A9B1D21E7
  CODE $386F; DATA $028F; UDATA $1D6C; end $BAFE; headroom $0502

C:\SRC\STR8-N\BUILD\v1.21\s19\ryors-v1.2-asm-himon-str8n-bank0-2-8-f.s19
  SHA-256 73985DB34183F4AA1AB76D0CB30C4064CC42BB641050A4ABF2ABA841506DD2C9
  decoded image SHA-256 7C38410C21F0B8A7A08494BAC61B6BB2A0221242A316DAF7166D7DD74E7AAB9A
```

The host equality gate reports:

```text
BOARD S19 IDENTITY = PASS; ASM=$3AFE HIMON=$2DB4 targets=10
```

If the board does not already show `HIMON V 00.0814(1524)`, use STR8-N `I`,
Bank `3`, range `8-E`, and send the frozen 28K stream above. Require seven
program/verify dots, `COMMIT? Y`, `OK`, and a normal boot into the matching
HIMON banner. Stop on any different version or install result.

## Card A: all encodings and SEAL ownership

At the HIMON prompt enter `ASM NEW`, then paste these source lines exactly:

```asm
ORG $3000
START LDA #$D7
STA $7906
SEC
RTS
RAW DC 'OK'; RAW COMMENT BOUNDARY
CSTR DC C'OK'
HBSTR DC H'OK'
PSTR DC P'OK'
R0 DC ''
C0 DC C''
H0 DC H''
P0 DC P''
CHAR LDA #'A'
OLDC DC C,"OK"
OLDH DC HB,"OK"
OLDP DC P,"OK"
ENTRY START
END
```

Require `ASM OK` and the `SEAL>` prompt. Then enter these HIMON-style bare-hex
SEAL commands:

```text
SEAL
RELOCATE 3100
PACKAGE START 3200
LOAD 3200 3300
.
```

Require successful SEAL, relocation with `C=$00`, package creation, and
`LOAD OK=$3300 L=$001E C=$00`. At HIMON, dump both relocated and loaded bodies:

If an undefined package name such as `DCTEST` was entered and the session was
then left with `.`, do not enter `ASM NEW`: that starts a replacement session.
Resume the preserved final image with:

```text
ASM SEAL
PACKAGE START 3200
LOAD 3200 3300
.
```

```text
D 3100 311D
D 3300 331D
```

Both dumps must contain exactly:

```text
3100/3300: A9 D7 8D 06 79 38 60 4F | 4B 4F 4B 00 4F CB 02 4F
3110/3310: 4B 00 80 00 A9 41 4F 4B | 00 4F CB 02 4F 4B
```

This proves, in order, executable setup, raw `OK`, compact C/H/P `OK`, empty
C/H/P, preserved `LDA #'A'`, and legacy C/HB/P `OK`. Empty raw text owns zero
bytes. Run the loaded body and inspect its sentinel:

```text
G 3300
D 7906
```

Require a normal return with carry set and `$7906=$D7`.

## Card B: malformed input and rollback

Start a fresh session with `ASM NEW`, then paste:

```asm
ORG $3400
DB $A5
DC 'IT''S'
DC 'NO
DC X'NO'
DC 'OK'
END
```

The embedded quote, unterminated quote, and unknown mode must each report
`ERR=$03` while retaining `PC=$3401`. The final valid raw form must advance to
`PC=$3403`; leave `SEAL>` with `.` and require:

```text
D 3400 3402
3400: A5 4F 4B
```

No bytes from a failed line may appear and high-water must remain aligned with
the final `$3403` PC.

## Acceptance record

Candidate `1502` is rejected evidence: its general word lexer did not accept
the apostrophe after a compact `C`, `H`, or `P` mode. Candidate `1524` uses a
DC-local mode parser and host checks forbid a return to general tokenization in
that parse head. This card also uses the defined entry symbol `START` as the
package name and expects `RELOCATE ... C=$00`, because this body has no internal
relocation records.

Retain the complete transcript. Accept the feature only when:

- the installed banner is exactly `00.0814(1524)`;
- both relocated and AP-loaded `$001E` bodies match byte for byte;
- `G 3300` returns normally and writes `$D7` to `$7906`;
- all three malformed lines fail at unchanged `$3401`;
- the final rollback dump is exactly `A5 4F 4B`.

Accepted on `00.0814(1524)`: package length `$004C`, loaded body length `$001E`
with `C=$00`, identical relocated/loaded bytes, `$7906=$D7`, three atomic
`$03` failures at `$3401`, and final rollback bytes `A5 4F 4B`. The exact
transcript is retained in the hardware log.
