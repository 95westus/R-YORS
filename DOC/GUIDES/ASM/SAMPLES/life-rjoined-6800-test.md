# Tiny Life ASM Sample Test

Purpose: exercise a pasteable ASM-native Conway Life toy through the current
ASM path. The sample is an 8x8 toroidal board with a glider seed, single-step
advance, random fill, and quit back to HIMON.

Source:

```text
DOC/GUIDES/ASM/SAMPLES/life-rjoined-6800.asm
```

Resource shape:

```text
entry              $2000
neighbor handling  computed in code, no table
seed board         initialized in code, no table
cell glyph/random  computed in code, no table
live board         $7800-$783F
next board         $7840-$787F
user ZP            $30-$3B
resident calls     BIO_FTDI_WRITE_BYTE_BLOCK
                   PIN_FTDI_READ_BYTE_NONBLOCK
```

The table-free shape is deliberate. Current flash ASM protects `$6000-$7EFF`
against assembly output because that range holds the live wrapper workspace,
and the seal relocation table is only 16 rows. The Life program may still use
`$7800/$7840` after leaving ASM and running under HIMON.

Host preflight:

```text
make -C SRC asm-test
```

Board preflight:

```text
HIMON V 00.0704(2011) or newer
flash ASM image already loaded at $8000, or load current asm-v1-flash-8000.s19 with L F
```

Enter flash ASM:

```text
>ASM
expect ASM FLASH
expect ASM>$hhhh: on builds with the PC prompt, or ASM> on older quiet builds
```

Paste the program:

```text
paste DOC/GUIDES/ASM/SAMPLES/life-rjoined-6800.asm
expect ASM FLASH OK
expect SEAL>
```

Optional seal check:

```text
SEAL> SEAL
expect SEAL OK FLAGS=$01 BASE=$2000
expect SEAL REL ... COUNT=$0F
```

Run it:

```text
SEAL> .
expect ASM FLASH BYE

>G 2000
expect G0 and the initial glider:

G0
.#......
..#.....
###.....
........
........
........
........
........
```

Step once:

```text
N
expect G1:

........
#.#.....
.##.....
.#......
........
........
........
........
```

More controls:

```text
space  advances one generation
N      advances one generation
R      randomizes the 8x8 board and resets generation to G0
Q      returns to HIMON
```

Notes:

```text
The generation display is a single ASCII digit; after G9 it intentionally rolls
through the following character codes rather than printing a multi-digit count.

A 2026-07-04 board attempt with the earlier fixed-address sample proved that
ORG $7000, ORG $7200, and ORG $7240 now fail with BAD RANGE under flash ASM.
A follow-up inline-table version assembled but hit SEAL ERR=$02 FLAGS=$09,
meaning the 16-row relocation metadata table truncated. This computed-neighbor
version then sealed cleanly, but its first board run found `BNE SLOOP` was out
of rel8 range. The current source uses `BEQ SDONE` / `JMP SLOOP` for that
loop. The fixed-branch version is board-captured in HARDWARE_TEST_LOG.md on
2026-07-04 with `SEAL REL ... COUNT=$0F`, deterministic glider stepping,
random fill, and `Q` return.
```
