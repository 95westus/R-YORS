# STR8 Bank Jump Record Board Test

This is the hardware-proof rail for the published record of the last validated
STR8 `J0`-`J2` handoff.

```text
status:       HOST ACCEPTED; HARDWARE PENDING
candidate:    himon-str8-rom.bin
source date:  2026-07-31
record:       $1FFD-$1FFF = 42 4A bank/FF
```

Install HIMON and STR8 together. The worker writes the record and HIMON cold
start preserves it through RAM clearing, so installing only the top STR8 sector
does not test the complete contract. Keep a known-good Bank 3 image and an
external recovery path available.

## Host Candidate Facts

```text
HIMON START/NMI/IRQ/END = C000/E64C/E64F/EECC
STR8 START/NMI/IRQ/END  = F000/F0C0/F0D4/FAEF
WORKER RUN/STORE/SIZE   = 0200/FD03-FFEF/2ED
STR8 RES/WORKER GAP     = FAEF-FD02/214 (min 200)
BANK JUMP RECORD        = 1FFD-1FFF; 42 4A bank/FF
Vectors NMI/RESET/IRQ   = F0C0/F000/F0D4
```

The combined-image build must reject disagreement in the record addresses
among resident STR8, the RAM worker, and HIMON. It must also reject signature
or unknown-bank values other than `$42`, `$4A`, and `$FF`.

## Contract Under Test

```text
successful J0 -> before JMP publish 42 4A 00
successful J1 -> before JMP publish 42 4A 01
successful J2 -> before JMP publish 42 4A 02
invalid target/vector -> do not replace the preceding committed record
HIMON warm start -> RAM is not cleared; record remains unchanged
HIMON cold start -> preserve a valid record and republish its bank
no valid signature -> after cold clear publish 42 4A FF
```

The record is historical state. It deliberately does not claim that the live
PCR still selects that bank after the guest resets or returns through Bank 3.

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
6. Exercise an invalid or erased-vector handoff if a safe fixture is available.
   Confirm that it returns to Bank 3 and does not commit a new record.
7. Recheck all four bank CRCs. The non-destructive handoff tests must not alter
   flash.

Append the raw transcript and candidate fingerprint to the hardware log. Do
not rewrite the earlier accepted selector/J evidence, whose addresses belong
to its historical image.
