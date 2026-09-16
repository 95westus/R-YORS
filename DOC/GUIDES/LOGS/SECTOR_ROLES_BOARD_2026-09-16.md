# Sector-role board installation — 2026-09-16

COM4 installation and exact four-bank verification **PASS**. Physical reset
(`RST H`), return to HIMON, exact live-top readback, and the final four-bank
archive also **PASS**. The final archive equals the post-install archive byte for byte.

Two independent fresh 128 KiB readbacks were identical. B2:F contained 4096
erased bytes. The ordinary STR8-N 1.34 updater verified its backup at B2:F,
installed the top while preserving the live directory, and returned through
software reset to HIMON `00.0915(2324)`.

| Address | Before | Installed |
| --- | --- | --- |
| `$FFF0` WORK | `$1E` (B1:E) | `$FF` (unassigned) |
| `$FFF1` protected backup | `$1F` (B1:F) | `$2F` (B2:F) |
| `$FFF2` FNV policy | `$FF` | `$FF` (disabled) |

The full post-install readback differs only in B2:F and B3:F. B2:F is an
exact copy of the previous live B3:F. The installed B3:F differs from its
predecessor only at `$FFF0/$FFF1`. The old B1:F backup, directory, HIMON,
ASM, AM01 manager, and all other application sectors are unchanged.
Removing B1:E/F protection does not erase or authorize reuse of their contents.
Restoring the new B2:F backup would restore the old role configuration too.

SHA-256 receipts:

| Artifact | SHA-256 |
| --- | --- |
| Before, both complete archives | `a0af5849bcb4985699b58f22daa1a801262469e2172bb15827189990cf5bf1cc` |
| After, complete archive | `3266041931068fd5a03db030eaef902be61bf2678fa75f1c559cee6df70741dc` |
| Previous live top / new B2:F | `fb3aad6d9e8f6402f318100685f39a5ee4eb8eb2cda2927c5e82965e693dd250` |
| Installed live top | `abc71e61edd8e065f8995a89ca958c77fdda3d7d2a200d943d6bf36c36934e21` |
| Retained B1:F | `5dddc4d0ec70afa5d154cf1ffccab8c2d70bf72b21cd49f3b99c4c9fd55099a0` |

[Retained evidence](SECTOR_ROLES_BOARD_2026-09-16/manifest.json) includes the
four complete archives, per-sector images, scripts, updater, raw serial
snapshot, and preflight/install/isolation results. The canonical top hash
differs from the live top because the ordinary updater retains the live directory.

This does not install the scoped HIMON/AM02 candidate or enable FNV discovery.
Directory-refresh, embedded-updater recovery, and factory installation with
these roles retain their separate host-only gates. The bank/sector LED sequence
gate and RAM-provider implementation also remain open.
