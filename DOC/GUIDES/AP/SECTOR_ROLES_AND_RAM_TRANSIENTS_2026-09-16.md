# Sector roles and RAM-transient collection - 2026-09-16

The new build removes the reserved flash WORK sector and moves the protected
raw Bank-3:F backup to **B2:F**. The role update is now installed on COM4. Two independent pre-update
readbacks and a complete post-update readback pass; physical reset and the final four-bank readback pass. See the [board record](../LOGS/SECTOR_ROLES_BOARD_2026-09-16.md).

| Bank-3 byte | Previous board layout | New build |
| --- | --- | --- |
| `$FFF0` WORK | `$1E`: B1:E | `$FF`: unassigned |
| `$FFF1` B3:F backup | `$1F`: B1:F | `$2F`: B2:F |
| `$FFF2` FNV policy | `$FF`: disabled | `$FF`: disabled |

B1:E and B1:F become ordinary sectors once the new configuration is live.
Removing a reservation does not erase either sector or establish that its
contents are disposable. B2:F becomes the single protected application-sector
location, leaving 23 locations under the role guard. Existing occupied sectors
still require the usual inventory, overwrite and mutation checks.
The first B2:F backup contains the previous top image and its old role bytes;
restoring that backup also restores the previous role configuration.

SPI SRAM is not emulated through a flash locator. Its future WORK allocation
needs the installed hardware's addressing, ownership and recovery contract.

## Implementation

STR8 owns the defaults and published constants. The top-image builder,
manifest, integration lock and host checks agree on `$FF/$2F`. The ordinary
top updater, directory refresh and embedded Bank Maintenance updater now select
Bank 2 for backup and recovery and request `BACKUP B2F`. Backup physical offsets
are `$17000-$17FFF`; the target remains B3:F at `$1F000-$1FFFF`.

APMAN and the scoped finder already read the role bytes. Their guards require
no extra firmware bytes. Compatibility tests retain an explicit old-layout
fixture; new cases exercise the unreserved B1:E/F locations and protected B2:F.
The existing scoped-search evidence remains an immutable record of its exact
earlier build and role fixture.

The top-level [RAM-TRANSIENTS](../../../RAM-TRANSIENTS/README.md) collection has
`A`, `S19`, and `BIN` folders. `make -C SRC ram-transients` builds the maintained
inputs and regenerates matching files plus a hash/load-address manifest.
Generated `.a` files are ASM-F2 byte carriers. Raw BIN files carry no addresses;
use the manifest. Package data and private overlays retain their prerequisites.

## Host qualification

The full `asm-test` regression passes, including 65,536 policy combinations
and 59 scoped cases. STR8 passes 432 maintenance startup cases across both
role layouts. All four linked updater variants back up the old role layout
to B2:F, install the new configuration, and restore the old image through
recovery in the flash model, with B0/B1 unchanged. Installation S19 identity
passes all nine targets. These tests do not replace electrical/board proof.

The top BIN changes only `$FFF0/$FFF1`; its SHA-256 is
`959C0142D9BF012C13DDDBA5AA35C5BCFE30C729A4E6370096E899A418B8266A`.
HIMON and AM02 bytes remain identical to the preceding scoped-search candidate.
The collection contains 40 images: 40 S19, 40 BIN and 42 `.a` files, including
two named-import source companions. Hashes, checksums, byte-carrier reconstruction
and BIN load ranges agree. See the [retained evidence](../LOGS/SECTOR_ROLES_2026-09-16/manifest.json).

The first export attempt stopped after successful ASM tests because a Windows
make path needed quoting. The corrected target resumed with those completed
prerequisites marked old; both logs are retained in the evidence directory.

## Ordered work and status

Steps 1 and 2: fresh archives, erased B2:F inspection, guarded installation,
backup verification and four-bank isolation are complete. The physical-reset
portion of step 2 and final four-bank isolation also pass; steps 1 and 2 are complete. Steps 3 onward have not been performed.

Later follow-up: coordinated HIMON/AM02 installation, `$A6` provisioning and
bounded [board smoke](../LOGS/SCOPED_SMOKE_BOARD_2026-09-16.md) now pass.
The later [banked AP qualification](../LOGS/SCOPED_QUALIFICATION_2026-09-16.md) completes BANKDUMP,
malformed/duplicate refusal, role predicates, paced observation, reset and final
isolation. BANKDUMP is retained at B2:A; RAM-provider/HREC and SPI SRAM work remain open.

1. Preserve fresh four-bank readbacks and inspect B2:F. Confirm its contents
   can be replaced before the updater writes the new backup there. Retain the
   old B1:F backup until the new backup and installed top have been verified.
2. Install the guarded top update with WORK disabled and backup B2:F. Use the
   ordinary updater to preserve the directory, not directory refresh. Verify
   readback, exact role bytes, physical reset and unchanged unrelated sectors.
3. Install the scoped-search HIMON and AM02 manager as a coordinated pair.
   Prove `$FFF2=$FF` disables discovery, then provision `$A6` through a separately
   checked full-sector update and prove B2/B1 lookup, B0 exclusion, malformed
   and duplicate refusal, and BANKDUMP load/link/return. Preserve B2:9 APTEST;
   choose an erased eligible carrier location for the test.
4. Close the remaining bank/sector LED observation gate and final four-bank
   isolation checks. Only then mark scoped banked discovery board-accepted.
5. Recover code space before adding RAM-provider discovery: HIMON currently
   has 8 bytes free and APMAN 13. SPI SRAM WORK and RAM-provider lookup remain
   separate future implementation tasks.
