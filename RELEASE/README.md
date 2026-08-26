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

Board-use artifacts:

- ARTIFACTS/AP-STORE/ap-store-v1-chain-install-tool-package-4000.s19
- ARTIFACTS/AP-STORE/ap-store-v1-slice6-catalog-tool-package-4000.s19
- ARTIFACTS/SOURCES/str8n-v1.22-bank-maint-menu-2000.a - onboard `ASM NEW`
  source for guarded Bank-3 directory reclaim
- ARTIFACTS/COMPONENT-IMAGES/str8n-v1.22-bank-maint-menu-2000.s19 - direct
  loader form of the same maintenance menu
- ARTIFACTS/COMPONENT-IMAGES - component, diagnostic, and recovery images
- ARTIFACTS/SOURCES - source snapshots and onboard sample sources

Historical artifacts:

- ARTIFACTS/ARCHIVE/AP-STORE - superseded AP Store transit variants
- ARTIFACTS/ARCHIVE/COMPONENT-IMAGES - superseded named component images
- ARTIFACTS/ARCHIVE/SOURCES - AP v1/v2 proof fixtures retained for regression

The canonical source remains under `SRC/` and the adjacent `STR8-N`
repository. `SHA256SUMS.txt` covers every file recursively.
