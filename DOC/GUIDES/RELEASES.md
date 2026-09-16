# Separate STR8-N, HIMON, and ASM-F2 releases

The current release lane produces three independent ZIPs and a qualified
combined Bank-3 8-E S19 under `RELEASE/`. See `RELEASE/README.md` for current
identities and hashes. Older loose images and `RELEASE/ARTIFACTS/` remain
historical snapshots; they are not inputs to this release lane.

## Package boundaries

- STR8-N v1.34 contains the canonical 4 KiB BIN, resident/update/maintenance
  S19 tools, the matching Bank Maintenance `.a`, public ABI, current guides,
  qualification reports, and WDC-to-STR8 migration kit. It contains no WDC
  firmware or owner backup. Its executable migration artifacts retain the
  identities of the 2026-09-15 factory-qualified kit.
- HIMON contains the dense C-E component S19 and 12 KiB address-labelled BIN,
  monitor documentation, application source and runnable products, Life and
  MicroChess with their exact notices, and the combined 8-E S19.
- ASM-F2 contains the dense 8-B component S19 and 16 KiB address-labelled BIN,
  the assembler guide, current map-matched reporter `.a`, terminal/bank
  inspection tools, language examples, separate validation fixtures, and
  the identical combined 8-E S19.

The component BINs are CPU-range images, not complete bootable ROMs. The
ASM-only S9 is `$FFFF` (retain HIMON's existing entry); HIMON and combined
streams use `$C000`. The 8-E stream excludes protected STR8 sector F.

Each ZIP has an exact inventory and SHA-256 checksums. The component
packages include operator, technical, installation, memory-map, AP/OIL,
and product-specific manuals under `DOC/GUIDES/`, with an entry point at
`MANUALS.md`. Included-file links work offline; references to unbundled
source and historical material are explicit links to the source revision.
Raw historical transcripts are not copied into the release ZIPs.

The component
`VERIFY.py` validates inventory, notices, S19 checksums/ranges/entries,
BIN/S19 equivalence, and the combined payload identity. It rejects optimized
Python execution rather than silently dropping validation. The STR8 package
has its own PowerShell verifier, including its nested migration ZIP.

## Qualification and version stamps

The release uses one timestamp captured at build start for both HIMON and
ASM-F2. The 2026-09-15 release stamp is `0915(2324)`. The complete `asm-test`
regression passes on that stamp; all nine board-image delivery comparisons
pass. The dense 28 KiB combined image must match the known reset-qualified
COM4 bank exactly outside three explicitly matched timestamp strings.
`QUALIFICATION.json` records the baseline hash, old/new stamps, changed-byte
count, current payload hash, host log identities, and qualification scope.

This proves timestamp-only equivalence to the hardware-qualified firmware;
it does not claim that the new stamped combined stream was reflashed or
that every optional application was requalified. Current board identities
remain in `CAPABILITIES.md`. A future functional firmware change must obtain
new hardware proof and update the qualification baseline before this
packager can accept it. Application status is listed in
[RELEASE_APPLICATIONS.md](RELEASE_APPLICATIONS.md).

## Reproduction

Use Python 3.10+ and the existing local WDC build tools. Do not bundle those
tools or vendor libraries. In the STR8-N repository build/verify the standalone
package using `tools/make_release_package.ps1`; its input migration ZIP is
created with `tools/wdcmonv2/make_wdcmonv2_migration_package.ps1`.
Then, from `R-YORS/SRC`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/publish_release.ps1 -Stamp '0915(2324)'
```

Omit `-Stamp` for a new build-time timestamp. Keep the retained qualified
bank readback at `SRC/BUILD/tmp/asmf2-size-board/final-b3.bin`, or supply its
path with `-QualifiedBankPath`. It remains local and is never copied into
an archive. The expected qualified-bank hash is fixed by the documented
board record. `make -C SRC release-files` invokes this packaging lane.
The older `make release` additionally requires the STR8 repository to be
clean; it is intended for the final source-revision publication workflow.

Commit source, tools, and manuals first. Rebuild the archives from that
revision, then commit the R-YORS release products and create annotated tags:
`v1.34` in STR8-N, and `himon-v00.0915-2324` plus `asm-f2-v00.0915-2324`
in R-YORS. Both component tags name the commit containing the corresponding
ZIPs and identical combined 8-E S19. A source manifest's dirty flag excludes
generated `RELEASE/` products so artifact-only changes do not falsely mark
the source build dirty. Tagging locally does not push or publish a release.

The script runs host checks before packaging. `-SkipBuild` is only for the
same already-completed build and requires matching final success markers
and the exact image qualification. No source files are glob-copied into
release ZIPs. A local archive is not a GitHub release: commit/tag/push or
remote publication are separate actions.

## Exclusions and retained notices

Exclude WDCMON firmware, owner bank dumps, proprietary tools, BASIC/Forth
products, obsolete Life `.a` code, and old flash proof programs. Project
code carries the repository MIT license. Life carries its independent
implementation attribution and full MIT notice. MicroChess retains its
source copyright/credits, three redistribution conditions, disclaimer, and
R-YORS adaptation notice; its own terms are not replaced by the MIT license.
