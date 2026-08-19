# Current R-YORS Release Files

This flat directory is the operator-facing release location. Product names
follow top-down memory order: STR8-N (`$F000), HIMON (`$C000), then ASM-F2
(`$8000).

Primary complete product:

- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin

Bank-3 payload without the protected STR8-N top sector:

- ryors-v1.2-himon-asm-bank3-8-e.s19

The `.asm` and `.a` files are source snapshots for inspection and onboard use.
The canonical build source remains under `SRC/` and the adjacent `STR8-N`
repository. `SHA256SUMS.txt` identifies every published file.
