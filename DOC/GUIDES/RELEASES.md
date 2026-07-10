# R-YORS Release Guide

This guide describes the GitHub release lane for R-YORS. The release artifact
is the bench-built firmware image and its matching S19 streams, not the ignored
build directory itself.

## Release Meaning

A GitHub Release should mark a source revision whose release artifacts were
built from tracked source and whose board proof status is clear.

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

Attach these files to the GitHub Release:

```text
SRC/BUILD/bin/himon-str8-rom.bin
SRC/BUILD/s19/himon-str8-rom-install.s19
SRC/BUILD/s19/himon-str8-himon-update.s19
```

Optional but recommended checksum commands:

```text
Get-FileHash SRC/BUILD/bin/himon-str8-rom.bin -Algorithm SHA256
Get-FileHash SRC/BUILD/s19/himon-str8-rom-install.s19 -Algorithm SHA256
Get-FileHash SRC/BUILD/s19/himon-str8-himon-update.s19 -Algorithm SHA256
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
- ROM: `SRC/BUILD/bin/himon-str8-rom.bin`
- First install: `SRC/BUILD/s19/himon-str8-rom-install.s19`
- HIMON update: `SRC/BUILD/s19/himon-str8-himon-update.s19`

### Proven
- STR8-N recovery/update path:
- HIMON monitor/debug/catalog path:
- ASM-F2 package/load/install/AP path:
- Banked AP or Life path:

### Caution
Bench-proven firmware. Keep an external programmer and known-good image nearby.

### Checksums
```text
himon-str8-rom.bin              SHA256:
himon-str8-rom-install.s19      SHA256:
himon-str8-himon-update.s19     SHA256:
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
