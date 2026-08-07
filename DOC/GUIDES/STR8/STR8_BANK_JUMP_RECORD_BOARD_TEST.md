# STR8 Bank Jump Record Board Test

This is the hardware-proof rail for the published record of the last validated
STR8 `J0`-`J3` handoff.

```text
status:       FULL J0-J3 COLD-PRESERVATION MATRIX HOST+HARDWARE PASS
candidate:    himon-str8-rom.bin / current post-fix HIMON update S19
source dates: 2026-08-02 through 2026-08-05
record:       $1FFD-$1FFF = 42 4A bank/FF
```

Install HIMON and STR8 together. The worker writes the record and HIMON cold
start preserves it through RAM clearing, so installing only the top STR8 sector
does not test the complete contract. Keep a known-good Bank 3 image and an
external recovery path available.

## Host Candidate Facts

```text
HIMON START/NMI/IRQ/END = C000/E64C/E64F/EECC
STR8 START/NMI/IRQ/END  = F000/F0BA/F0CE/F9D1
WORKER RUN/STORE/SIZE   = 0200/FD93-FFEF/25D
STR8 RES/WORKER GAP     = F9D1-FD92/3C2 (min 200)
BANK JUMP RECORD        = 1FFD-1FFF; 42 4A bank/FF; banks 00-03
Vectors NMI/RESET/IRQ   = F0BA/F000/F0CE
```

The combined-image build must reject disagreement in the record addresses
among resident STR8, the RAM worker, and HIMON. It must also reject signature
or bank-count disagreement. The shared `STR8_BANK_COUNT=$04` makes valid bank
bytes `$00-$03`; `$FF` remains the explicit unknown value.

## Contract Under Test

```text
successful J0 -> before JMP publish 42 4A 00
successful J1 -> before JMP publish 42 4A 01
successful J2 -> before JMP publish 42 4A 02
successful J3 -> before JMP publish 42 4A 03
invalid target/vector -> do not replace the preceding committed record
HIMON warm start -> RAM is not cleared; record remains unchanged
HIMON cold start -> preserve a valid record and republish its bank
no valid signature -> after cold clear publish 42 4A FF
```

The record is historical state. It deliberately does not claim that the live
PCR still selects that bank after the guest resets or returns through Bank 3.
The separately published live byte is `STR8_BANK_STATE_BYTE = $7FEC`, masked
by `STR8_BANK_STATE_MASK = $EE`. `$CC/$CE/$EC/$EE` are the explicit
B0/B1/B2/B3 selector-write patterns, while other raw states remain undecoded.
Capturing `D 7FEC 7FEC` is deferred until the next suitable board test and is
not part of the accepted historical-record matrix below.

## Board Procedure

1. Record the SHA-256 and install the combined HIMON/STR8 image.
2. Reach HIMON without a preceding valid record and run `D 1FFD 1FFF`. Expect
   `42 4A FF`.
3. From STR8 run `J0`, allow the qualified Bank 0 guest to return through
   reset/HIMON, then run `D 1FFD 1FFF`. Expect `42 4A 00`.
4. Run `HCOLD`, return to the prompt, and repeat the dump. Expect the same
   `42 4A 00`.
5. Repeat the handoff and cold-preservation check for `J1` and `J2`, expecting
   `42 4A 01` and `42 4A 02`.
6. From a copied STR8 bank, issue `J3`, allow Bank-3 STR8 to time out through
   `RAM ZERO` into the updated HIMON, and run `D 1FFD 1FFF`. Expect
   `42 4A 03`. Run `HCOLD` and repeat the dump; it must remain `42 4A 03`.
7. Exercise an invalid or erased-vector handoff if a safe fixture is available.
   Confirm that it returns to Bank 3 and does not commit a new record.
8. Recheck all four bank CRCs. The non-destructive handoff tests must not alter
   flash.

The J3 switching path itself is already hardware-accepted. The updated test is
specifically for the corrected HIMON cold-clear bound: the earlier `CMP #$03`
rejected record byte `$03`, while the shared `$04` bound preserves Banks 0-3.
The instruction size and all resident addresses are unchanged.

## 2026-08-02 J3 Cold-Preservation Acceptance

The updated HIMON `00.0802(1536)` installed through resident `U`. From
Bank-3 STR8 `1518`, selector `0` entered the verified Bank-0 STR8 `1509` copy.
Its resident `J3` returned to Bank-3 STR8 `1518`; the normal timeout then
entered updated HIMON through `BOOT COLD` and `RAM ZERO OK`.

The first dump proved that the corrected cold clear preserved Bank 3:

```text
>D 1FFD 1FFF
1FFD: 42 4A 03 | BJ.
```

An explicit confirmed `HCOLD` printed `BOOT COLD` and `RAM ZERO OK`; the repeat
dump remained exactly `42 4A 03`. This closes the J3 cold-preservation fix.

## 2026-08-05 Full Matrix Acceptance

The focused continuation captured J0 as `42 4A 00` through two `HCOLD`
operations and J1 as `42 4A 01` through `HCOLD`. Earlier accepted captures
already retained J2 as `42 4A 02` and J3 as `42 4A 03` through cold entry.
Together these close the complete J0-J3 Bank Jump Record cold-preservation
matrix. Invalid-vector rejection and non-destructive bank CRC checks remain
separate accepted gates in their own transcripts.

Append the raw transcript and candidate fingerprint to the hardware log. Do
not rewrite the earlier accepted selector/J evidence, whose addresses belong
to its historical image.
