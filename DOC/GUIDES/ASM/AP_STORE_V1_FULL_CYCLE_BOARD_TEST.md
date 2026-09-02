# AP Store V1 LED Full-Cycle Board Test

> [!NOTE]
> Historical prepared card for the AP Store branch. It is not the current
> APMAN carrier workflow and its retained STR8-N 1.23 transcript is not a
> current installation instruction. See [the capability matrix](../CAPABILITIES.md).

Status: prepared; board proof not yet captured.

This is the managed-object alternative to the raw sector-base carrier. See
[BANKED_AP_CARRIER_VS_AP_STORE.md](BANKED_AP_CARRIER_VS_AP_STORE.md) before
choosing between the two deployment paths.

This is the exact short cycle: build a real eight-LED program with onboard
ASM-F2, seal/package it, append it to B1:8 as object `$0003`, cold boot, load
it from AP Store, and run it. The program uses PIA port A at `$7FA1` and DDRA
at `$7FA3`. It walks the two four-LED groups, shows alternating/all-on
patterns, restores the old output and direction, and returns `A=$AC`, carry
set.

## Exact files

```text
ASM NEW source
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\pia-led-show-2000.a

Object $0003 install request
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\ap-store-v1-cycle-install-b1s8-o3g1-1a00.s19

AP Store installer
C:\SRC\R-YORS\RELEASE\ARTIFACTS\AP-STORE\ap-store-v1-chain-install-tool-package-4000.s19

Commit confirmation
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\ap-store-v1-chain-confirm-1a40.s19

Object $0003 load request
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\ap-store-v1-cycle-reader-b1-o3-newest-1a00.s19

AP Store reader
C:\SRC\R-YORS\RELEASE\ARTIFACTS\AP-STORE\ap-store-v1-slice6-catalog-tool-package-4000.s19
```

Host-built counterparts, not needed for the onboard cycle:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\pia-led-show-2000.asm
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\pia-led-show-2000.s19
```

The `.a` and `.asm` shared bodies are checked instruction-for-instruction.
The host S19 is `$2000-$2056`, `$0057` bytes, FNV32 `$5D916946`.
Do not load that host S19 during this AP Store cycle; build the package from
the `.a` with `ASM NEW`.

Expected `L` reports, in order:

```text
install request   L OK=0032 ENTRY=1A00
installer         L OK=0973 ENTRY=4000
confirmation      L OK=0006 ENTRY=1A40
load request      L OK=002A ENTRY=1A00
reader            L OK=09F2 ENTRY=4000
```

## 1. Assemble, seal, and package

At the HIMON prompt:

```text
ASM NEW
```

Send this exact file:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\pia-led-show-2000.a
```

At `SEAL>` enter:

```text
SEAL
PACKAGE $3000
.
```

Require:

```text
BASE=$2000 END=$2057
LEN=$0057 FNV=$5D916946
COUNT=$06
PKG OK @=$3000 L=$00D0
```

Stop if any value differs.

## 2. Store object $0003 in B1:8

Enter `L`, then send:

```text
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\ap-store-v1-cycle-install-b1s8-o3g1-1a00.s19
```

Then enter:

```text
G 1A00
L
```

Send:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\AP-STORE\ap-store-v1-chain-install-tool-package-4000.s19
```

Then enter:

```text
AP 4000 7000
D 7C80 7C99
D 7CB0 7CB9
```

Require return/status `$A0`, package length `$00D0`, one chunk, used mask
`$01`, capacity `$0FDB`, and this plan row:

```text
08 03 10 00 00 00 A3 00 48 F2
```

Now enter `L`, then send:

```text
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\ap-store-v1-chain-confirm-1a40.s19
```

Commit exactly once:

```text
G 1A40
D 7C8A
G 7003
G 7003
```

Require `$7C8A=A5`, first `G 7003` return/status `$AC`, and replay `$D7`.
The object record occupies B1:8 offsets `$0010-$00C7`; `$00C8-$0FFF` remains
erased. B1:8 remains active generation `$0002`.

## 3. Cold boot

Press physical RESET. At this selector, press `C`:

```text
STR8-N 1.23
0-2 C W S: C
BOOT COLD
RAM ZERO OK

HIMON V ...
```

Do not allow the selector to time out: timeout is a warm boot and does not
prove the package and installer RAM were cleared.

## 4. Load object $0003 from AP Store and run it

Enter `L`, then send:

```text
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\ap-store-v1-cycle-reader-b1-o3-newest-1a00.s19
```

Then enter:

```text
G 1A00
L
```

Send:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\AP-STORE\ap-store-v1-slice6-catalog-tool-package-4000.s19
```

Then run exactly:

```text
AP 4000 7000
G 7003
G 7006
APS
```

Require:

```text
APNEW O=0003 G=0001 L=00D0
APNEW OK
G 7003 returns A=$AC with carry set
G 7006 visibly runs both four-LED groups and returns A=$AC with carry set
APS 18 + G=0002
APS OK
```

`AP 4000 7000` loads/runs the AP Store reader transient. `G 7003` validates
the selected stored object. `G 7006` reconstructs it at `$4000`, applies its
six internal relocations, and calls it. No pre-reset package bytes are used.

## Pass

Pass requires the exact seal/package facts, one confirmed B1:8 append, cold
RAM clear, `APNEW O=0003 G=0001 L=00D0`, visible eight-LED sequence, restored
PIA state, `A=$AC`/carry set, and unchanged B1:8 generation `$0002`. Append the
terminal capture to `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`; do not rewrite old
hardware evidence.
