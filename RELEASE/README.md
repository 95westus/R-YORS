# Current R-YORS Release Files

The root of this directory contains only board-facing update products.
Supporting images, transient tools, and source carriers are under
`ARTIFACTS/` so they cannot be mistaken for the normal board update.

Complete 32K Bank-0/1/2 product:

- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin

Bank-3 sectors 8-E update, without protected sector F:

- ryors-v1.2-himon-asm-bank3-8-e.s19

Guarded Bank-3 sector-F update, retaining a verified B1:F backup:

- str8n-v1.22-top-update-2000.s19

Moved-aside material:

- ARTIFACTS/AP-STORE - AP Store transit tools and exact `.a`/`.asm` carriers
- ARTIFACTS/COMPONENT-IMAGES - component, diagnostic, and recovery images
- ARTIFACTS/SOURCES - source snapshots and onboard sample sources

The canonical source remains under `SRC/` and the adjacent `STR8-N`
repository. `SHA256SUMS.txt` covers every file recursively.
