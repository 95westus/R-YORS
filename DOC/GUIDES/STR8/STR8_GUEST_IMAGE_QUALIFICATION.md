# STR8 Independent Guest-Image Qualification

This is the generic H/P/V/C procedure for approving an unrelated 32K system
for `J0`, `J1`, or `J2`:

```text
H     warm handoff and recovery behavior
P     peripheral and surviving machine state
V     reset, NMI, and IRQ/BRK vectors
C     exact image identity and non-destructive proof
```

> **IMPORTANT: QUALIFY EVERY EXACT GUEST IMAGE**
>
> Passing `J` with R-YORS does not qualify OSI BASIC, FORTH, WOZMON, or any
> other system. Each exact 32K `$8000-$FFFF` image, build, configuration, and
> intended bank needs its own H/P/V/C record. Changing any image byte,
> startup wrapper, vector, device configuration, or destination bank
> invalidates the old qualification until the affected checks are repeated.

STR8 V1 checks reset-vector plausibility only. It does not identify the guest,
authenticate its full image, validate its interrupt vectors, normalize all
hardware, or prove that the guest can survive a warm handoff.

Historical proof that OSI BASIC or fig-FORTH booted through the fixed
`$C000-$EFFF` payload-update gate is still valid. It is not qualification of a
completely unrelated opaque 32K image entered by `Jn`; that path introduces
different top-sector, vector, and warm-peripheral assumptions.

## Handoff Contract

On an accepted `Jn`, the RAM worker selects the target bank, reads its reset
vector from `$FFFC-$FFFD`, and enters it with:

```text
PC    target reset vector, little-endian from $FFFC-$FFFD
I     1; maskable IRQ disabled
D     0; binary arithmetic
X     $FF
S     $FF
A/Y   unspecified
N/V/Z/C and other non-I/D status assumptions are not a guest ABI
RAM   survives; it is not cleared
I/O   survives; devices are not electrically reset
NMI   cannot be masked and must remain quiescent during handoff
PCR   selects the target bank through VIA CA2/CB2
```

This resembles reset entry but is not an electrical reset. Pending interrupt
flags, VIA configuration, console state, timers, and application RAM may all
differ from power-on defaults.

An image passes the handoff contract only if its reset entry initializes every
state it depends on. If its original reset code assumes power-on defaults,
build a guest-owned warm-entry wrapper into that exact 32K image and point
`$FFFC-$FFFD` at the wrapper. The wrapper must preserve the target bank
selection, establish required CPU/RAM/device state, clear unsafe interrupt
sources, and then enter the original system startup.

## Qualification Record

Create one record per exact image and destination bank:

```text
qualification ID:
system and version:
source/provenance:
build command/configuration:
host filename:
host SHA-256:
mapped range:             $8000-$FFFF, exactly 32768 bytes
destination bank:
CRC algorithm:            CRC-16/CCITT-FALSE over $8000-$FFFF
expected full-image CRC:
NMI vector $FFFA-$FFFB:
RESET vector $FFFC-$FFFD:
IRQ/BRK vector $FFFE-$FFFF:
console/device profile:
RAM initialization:
warm-entry address:
known NMI sources:
known IRQ sources:
rollback image/location:
H result:
P result:
V result:
pre/post CRC result:
physical-reset recovery:
decision and date:
transcript location:
```

Use a host SHA-256 to identify the source artifact and the board fixture's
CRC-16/CCITT-FALSE to identify the complete flashed 32K bank. Record both;
they serve different comparison paths.

## Procedure 0: Prepare Recovery

Before programming or jumping:

1. Keep a known-good Bank-3 STR8 image and its CRC.
2. Make physical RESET immediately reachable.
3. Keep an external programmer or a separately proven restore image available.
4. Capture the terminal transcript from before the first mutation.
5. Disable or quiesce every possible NMI source.
6. Back up the chosen destination and prove the rollback image.
7. Record the role of all four banks. Do not run `B`, bare `0`/`1`/`2`, or a
   high restore unless that exact overwrite is intended.

Stop if physical reset does not repeatedly return to Bank 3 and its normal
timeout/default payload.

## Procedure 1: Qualify The Image Offline

1. Produce the exact binary that will occupy `$8000-$FFFF`.
2. Require exactly 32,768 bytes. Define padding explicitly; do not depend on
   the programmer to invent missing bytes.
3. Record its build configuration, timestamp/tag, and host SHA-256.
4. Decode the three little-endian vectors at `$FFFA-$FFFF`.
5. Require RESET in `$8000-$FFFE`; reject `$FFFF`.
6. Inspect the reset target and confirm that its bytes are present in the
   mapped image.
7. Determine whether startup tolerates the warm contract above. If not, add
   and review a target-owned warm-entry wrapper.
8. Compute the expected CRC-16/CCITT-FALSE over all 32K bytes in address
   order, `$8000` through `$FFFF`.
9. When practical, execute the exact image in an emulator or RAM-controlled
   test with nonzero RAM and non-default device state.

Do not infer identity from a banner, vector, or a few face bytes. Those are
diagnostic clues; the exact artifact hash and full-image CRC identify the
qualified build.

## Procedure 2: Peripheral Qualification

Inventory every device or state that STR8 may leave active and every power-on
default the guest assumes. At minimum check:

```text
FTDI/console VIA direction and control registers
VIA PCR at $7FEC, especially CA2/CB2 bank-select outputs
VIA interrupt enables and pending interrupt flags
timers, handshakes, and console receive/transmit state
all possible NMI sources
guest zero-page, stack, workspace, and RAM-clear assumptions
clock, baud, and board-revision assumptions
```

The guest must not overwrite the complete PCR with a value that
unintentionally changes CA2/CB2 and maps its own ROM out. If it must rewrite
the PCR, its startup must preserve or deliberately reassert the current
bank-selection pattern.

Test the guest from deliberately non-default but safe states when possible:

1. Place recognizable nonzero values in guest-owned RAM.
2. Leave harmless pending input or device status that could survive STR8.
3. Enter with IRQ masked, as STR8 does.
4. Require the guest to initialize its workspace before use.
5. Require it to clear or acknowledge interrupt sources before enabling IRQ.
6. Keep NMI quiescent until the guest has installed usable state.
7. Exercise the console and each required peripheral after startup.

Record PASS only when the guest initializes what it needs without changing
banks unexpectedly. Record every state that the test deliberately did not
cover.

## Procedure 3: Vector Qualification

Read vectors from the exact host binary and again from the flashed bank:

```text
$FFFA-$FFFB   NMI
$FFFC-$FFFD   RESET / Jn entry
$FFFE-$FFFF   IRQ/BRK
```

Apply these rules:

1. RESET must be `$8000-$FFFE`, must not be `$FFFF`, and must point to present
   target code. This is the only vector plausibility rule STR8 V1 enforces.
2. NMI is not validated by STR8. If any NMI source can fire, its vector and
   handler must be usable immediately after bank selection, even before the
   guest reset entry completes.
3. IRQ/BRK is not validated by STR8. IRQ starts masked, but the vector and
   handler must be valid before the guest enables IRQ or executes `BRK`.
4. Document intentional shared stubs, RAM vectors, or unused interrupts.
   `$FFFF` is acceptable only when the corresponding interrupt is proven
   impossible and that restriction is part of the qualification record.
5. Test NMI and IRQ/BRK only after the guest has reached its initialized
   state. Do not inject NMI during the bank-switch window.

A plausible RESET vector with unsafe NMI/IRQ vectors is not a qualified
system.

## Procedure 4: Program And Verify

Programming is separate from `J`:

1. From the known Bank-3 system, capture a complete pre-program inventory.
2. Program only the intended destination with the already-proven flash path.
3. Read back the complete destination bank.
4. Require byte-for-byte agreement with the host image when tooling permits.
5. Run the Bank-3 all-bank CRC tool and require:

```text
status/PCR/bank   $AC / $EE / $03
destination CRC  exact expected CRC-16/CCITT-FALSE
all three vectors match the qualification record
unmodified banks retain their prior CRCs
```

Run
[str8n-v1.2-bank-crc-all-3000.a](../ASM/SAMPLES/str8n-v1.2-bank-crc-all-3000.a)
only from Bank 3. It bootstraps the installed `$F010` selector, stages through
its copied `$0203` entry, and restores Bank 3 after every sector.

Do not issue `Jn` when the read-back CRC or any required vector differs.

## Procedure 5: First Handoff

Use a bounded, single-attempt rail:

1. Physical reset and require Bank-3 STR8/default boot.
2. Enter the Bank-3 STR8 prompt with `S`.
3. Record the STR8 identity printed on menu entry. Type `?` and require the
   command help line; `?` is intentionally an unknown command now.
4. Enter the chosen `Jn`.
5. Capture the visible `STR8-N>Jn` and `J Bn` lines.
6. Require the guest's unique build identity or a documented deterministic
   behavior. A generic prompt alone is not enough when builds can collide.
7. Exercise only the minimum console/recovery check on the first entry.
8. Press physical RESET; do not use an unqualified guest bank-switch command.
9. Require the Bank-3 countdown and default payload again.

If the guest is silent, hangs, changes banks unexpectedly, or cannot recover
through physical reset, stop. Do not repeat `Jn` or issue blind flash
commands.

## Procedure 6: Post-Handoff CRC Proof

After physical reset returns to Bank 3:

1. Reassemble or reload the current inventory fixture from Bank 3.
2. Run it and require `$AC/$EE/03`.
3. Compare all four CRCs and vectors against the immediate pre-`Jn` inventory.
4. Require every value to match byte for byte. `J` performs no erase or
   program operation, so any CRC change is a stop condition.
5. Repeat the `Jn`/reset/inventory cycle enough times to expose intermittent
   device or bank-latch behavior; three clean cycles is the default minimum.
6. Append the transcript. Never replace an earlier failure or partial result.

## Acceptance Matrix

| Gate | PASS evidence |
| --- | --- |
| Handoff | visible `Jn`, correct guest identity, stable basic operation |
| Peripheral | startup survives warm state; bank selection stays correct |
| Reset vector | exact value, in range, points to present startup code |
| NMI | source quiescent during handoff; handler qualified before use |
| IRQ/BRK | remains masked until initialized; handler qualified before use |
| CRC | host/read-back CRC matches; all pre/post bank CRCs unchanged |
| Recovery | physical reset repeatedly returns to Bank 3/default |
| Record | exact artifact, bank, results, and transcript are retained |

Qualification fails if any required row lacks affirmative evidence. A failure
does not invalidate the already-proven STR8 bank-switch mechanism; it means
that exact guest image is not yet safe for routine `Jn` use.

## Promotion Boundary

Manual launch should remain the highest permission for a newly qualified
guest. Timed alternate-bank boot or unattended managed launch additionally
requires the future Bank-3-owned manifest: bank number, expected full-image
CRC, expected reset vector, image role/type, build tag/timestamp, and
enabled/committed state. V1's reset-vector plausibility gate is not a
substitute for that metadata.
