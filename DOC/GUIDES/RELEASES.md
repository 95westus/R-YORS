# R-YORS Release Guide

This guide describes the GitHub release lane for R-YORS. The release artifact
is the bench-built firmware image and its matching S19 streams. Git retains
all current operator-facing files together under `RELEASE/`; generated build
products elsewhere remain ignored.

## Release Meaning

A GitHub Release should mark a source revision whose release artifacts were
built from tracked source and whose board proof status is clear.

The primary `himon-str8-rom.*` artifacts use the accepted split-V1.02 layout.
The `himon-str8-v1.*` names remain compatibility outputs for frozen board
cards, not a second firmware baseline.

Use releases for:

- the current STR8-N/HIMON/ASM-F2 onboard image;
- first-install and update S19 streams;
- release notes that say what is host-built, board-proven, or still
  bench-caution material.

Do not publish `make release-local` artifacts unless the release is explicitly
for local/private composite images.

## Preflight

From the repository root:

```text
git status --short
make -C SRC release
git diff --check
```

`make -C SRC release` regenerates source-derived docs and produces the release
artifacts under `SRC/BUILD/`.

If generated docs change only by timestamp, include them in the release commit
or rebuild from a clean tree before tagging. Do not hand-edit files under
`DOC/GENERATED/`.

## Assets

Attach these primary files to the GitHub Release:

```text
RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin
RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19
```

The separately installable ASM and HIMON slices retained beside them are
`ryors-v1.2-asm-bank3-8-b.s19` and
`ryors-v1.2-himon-bank3-c-e.s19`. The standalone/install S19 variants are
also retained because `board-s19-check` verifies that all delivery forms carry
the same current bytes.

Optional but recommended checksum commands:

```text
Get-FileHash RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin -Algorithm SHA256
Get-FileHash RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19 -Algorithm SHA256
Get-FileHash RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19 -Algorithm SHA256
```

## Tagging

Use a tag that names the release meaning, not just the build time.

For the OIL .710 release:

```text
v0.710
```

If a release is only a dated bench snapshot, use:

```text
rYYYY-MM-DD
```

Create the tag only after the source tree, generated docs, and release notes
match the artifacts being uploaded.

## Release Notes Template

````markdown
## R-YORS v0.710

### Build
- Command: `make -C SRC release`
- Complete BIN: `RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin`
- Complete S19: `RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19`
- Bank-3 payload: `RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19`

### Proven
- STR8-N recovery/update path:
- HIMON monitor/debug/catalog path:
- ASM-F2 package/load/install/AP path:
- Banked AP or Life path:

### Caution
Bench-proven firmware. Keep an external programmer and known-good image nearby.

### Checksums
```text
ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin  SHA256:
ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19  SHA256:
ryors-v1.2-himon-asm-bank3-8-e.s19          SHA256:
```
````

## Publish Steps

1. Build with `make -C SRC release`.
2. Confirm `git status --short`.
3. Commit tracked release docs or source changes.
4. Tag the release commit.
5. Push the commit and tag.
6. Open `https://github.com/95westus/R-YORS/releases/new`.
7. Choose the tag.
8. Mark the release as a prerelease if it is bench-proven but not field-ready.
9. Attach the three release assets and publish.

## Optional Self-Hosted Workflow

`.github/workflows/release-self-hosted.yml` defines a manual GitHub Actions
workflow for a self-hosted Windows runner. Use it only on a runner with the WDC
toolchain, `make`, and PowerShell available.

The workflow runs `make -C SRC release`, writes `SRC/BUILD/release-sha256.txt`,
and uploads the release assets as a workflow artifact. It does not publish a
GitHub Release by itself.

## After Publishing

Create or update a board-proof issue using the GitHub issue template. Link the
release, the relevant hardware transcript, and any follow-up recovery notes.
