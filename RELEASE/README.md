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

- str8n-v1.29-top-update-2000.s19

Board-use artifacts:

- ARTIFACTS/COMPONENT-IMAGES/apman-v1-bank2-8000.s19 - initial Bank-2
  dense 4K bootstrap carrier for the APMAN manager
- ARTIFACTS/COMPONENT-IMAGES/apman-v1-bank2-8000.bin - the same dense 4K
  sector for programmer/readback use
- ARTIFACTS/COMPONENT-IMAGES/apman-v1.ap - exact AP v2 APMAN envelope
- ARTIFACTS/AP-STORE/ap-store-v1-chain-install-tool-package-4000.s19
- ARTIFACTS/AP-STORE/ap-store-v1-slice6-catalog-tool-package-4000.s19
- ARTIFACTS/SOURCES/str8n-v1.29-bank-maint-menu-2000.a - onboard `ASM NEW`
  source for banked AP put, guarded directory rename, and directory reclaim
- ARTIFACTS/COMPONENT-IMAGES/str8n-v1.29-bank-maint-menu-2000.s19 - direct
  loader form of the same maintenance menu
- ARTIFACTS/COMPONENT-IMAGES - component, diagnostic, and recovery images
- ARTIFACTS/SOURCES - source snapshots and onboard sample sources
- BOARD-CARDS/APMAN_V1_BOARD_TEST.md - exact destructive B2/D2 preparation,
  candidate update, and first persistent carrier test
- BOARD-CARDS/BANK_AUDIT_AP_CARD.md - BANKAUDIT utility reference
- BOARD-CARDS/BANK_DUMP_AP_CARD.md - BANKDUMP install and inspection tests

Archived artifacts:

- ARTIFACTS/ARCHIVE/AP-STORE - superseded AP Store transit variants
- ARTIFACTS/ARCHIVE/COMPONENT-IMAGES - superseded and proof/test component images,
  including every retained pre-v1.29 STR8-N image, `fnv1a-hbstr-6000.s19`,
  the current console ABI test, and `rom-append-calc-b804.s19`
- ARTIFACTS/ARCHIVE/SOURCES - pre-v1.29 STR8-N sources and AP v1/v2 proof
  fixtures retained for regression

The canonical source remains under `SRC/` and the adjacent `STR8-N`
repository. `SHA256SUMS.txt` covers every file recursively.
