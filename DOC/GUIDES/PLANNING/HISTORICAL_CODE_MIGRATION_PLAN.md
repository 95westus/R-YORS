# Historical Code Migration Plan

This is the plan for moving retired sample, test, proof, demo, and other
non-current code/data into the historical source area.

This document is a migration plan, not a file move. Execute it in small
`git mv` batches after the current STR8-N, HIMON V, and ASM-F2 workflows are
stable enough that a moved file is either no longer needed or has a current
onboard replacement.

## Boundary

Active source lanes should hold only code and data used to create the current
R-YORS onboard code/data. Current in-use files for STR8-N, HIMON V, and ASM-F2
keep their structure until a deliberate replacement exists.

Going forward, new code/data should be processed on board whenever practical:
through HIMON, flash ASM-F2, AP packages, STR8 update/install flows, or later
managed onboard records. Host-side sources and generators may remain while they
bootstrap or regenerate current onboard images, but new bench-only samples and
one-off proofs should have an archive path from the start.

Hardware transcripts under `DOC/GUIDES/LOGS/` stay append-only. Do not rewrite
old transcript paths just because a source file later moves. Instead, update
current operator/planning docs and add a migration note that names the old path
and the new archive path.

## Historical Home

Use `SRC/ARCHIVE/` as the historical code/data home. It already contains the
retired HIMON branches under `SRC/ARCHIVE/himon/`; expand that pattern rather
than creating another archive lane.

Planned archive shelves:

```text
SRC/ARCHIVE/himon/        retired monitor branches
SRC/ARCHIVE/proofs/       retired proof sources and proof-only data
SRC/ARCHIVE/tests/        retired host/board harnesses
SRC/ARCHIVE/samples/asm/  retired ASM paste samples and companion notes
SRC/ARCHIVE/apps/         retired demo/user applications
SRC/ARCHIVE/tools/        retired host helper scripts
SRC/ARCHIVE/data/         retired board data streams and fixtures
```

Keep companion notes with their code when the note only explains that code. Keep
operator guides, decision docs, and hardware transcripts under `DOC/GUIDES/`.

## Keep In Place

Do not move these until a replacement path is explicit:

```text
SRC/STR8/
SRC/HIMON/himon.asm
SRC/HIMON/himon-*.inc
SRC/ASM/asm-v1-core.asm
SRC/ASM/asm-v1-flash.asm
SRC/LIB/ftdi/
SRC/LIB/dev/
SRC/LIB/util/
SRC/tools/ scripts used by current firmware, docs, and board-data generation
```

Also keep current board-ingested/generated ASM sources in their existing paths
until the Makefile and operator docs point somewhere else:

```text
DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a
DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
DOC/GUIDES/ASM/SAMPLES/asm-session-report-transient-7000.a
DOC/GUIDES/ASM/SAMPLES/ASMTEST_3000.asm
DOC/GUIDES/ASM/SAMPLES/banked-ap-smoke.a
DOC/GUIDES/ASM/SAMPLES/banked-rjoin-smoke.a
DOC/GUIDES/ASM/SAMPLES/bankput-transient-3000.a
```

Those files are named like samples, but today they still support current
ASM-F2, STR8-N, AP, and reporter workflows.

## Candidate Moves

Move these only after their current Makefile targets, operator docs, and board
proof gates no longer depend on the old path.

```text
SRC/PROOFS/*.asm
  -> SRC/ARCHIVE/proofs/
```

Exception: keep `SRC/PROOFS/asm-session-report.asm` while
`make -C SRC asm-session-report` generates the current reporter sources.

```text
SRC/TESTS/*.asm
SRC/TESTS/*.inc
SRC/TESTS/support/
  -> SRC/ARCHIVE/tests/
```

Exception: `SRC/TESTS/ftdi-backend-debug.asm` is still treated as
`ROM/ftdi-backend-debug.asm` by generated docs. Either promote it into the
active library if it remains operational, or remove it from the operational doc
scan before archiving it.

```text
DOC/GUIDES/ASM/SAMPLES/*
  -> SRC/ARCHIVE/samples/asm/
```

Exceptions are the current board-ingested files listed in "Keep In Place".
When a sample becomes only proof history, move the source and its companion
`*-test.md` note together.

```text
SRC/APPS/life.asm
SRC/APPS/rom-append-calc.asm
  -> SRC/ARCHIVE/apps/
```

Do this only after `LIFE_RCAT_MEMBER.md`, release targets, and any flash-append
proof references either point at the archive path or have a current onboard
member/record replacement.

```text
SRC/HIMON/fnv1a-hbstr-6000.asm
SRC/HIMON/crc16-notable.asm
  -> SRC/ARCHIVE/tools/hash/
```

If either helper becomes active runtime support, promote it to `SRC/LIB/util/`
or an explicit HIMON include instead of archiving it.

```text
SRC/STASH/
SRC/SESH/
SRC/TEST/
  -> remove after references are gone
```

These are retired lane readmes. Keep them as breadcrumbs until docs and users no
longer need the old names.

## Execution Order

1. Freeze the current operational list.

   Record the exact files used by `make -C SRC all`, `make release`, and
   any current board workflow for STR8-N, HIMON V, and ASM-F2.

2. Create archive shelves.

   Add the destination folders under `SRC/ARCHIVE/` with short `README.md`
   files. Each README should say what was moved, why it is historical, and what
   current path supersedes it.

3. Retire generated sidecars.

   Before moving source, clean ignored `.obj`, `.lst`, `.map`, `.sym`, `.bin`,
   and `.s19` sidecars from active source directories or confirm they are
   ignored build artifacts. Do not move ignored sidecars as if they were source.

4. Move one class at a time.

   Prefer batches like "retired tests", "retired proofs", or "retired ASM
   samples". Avoid mixing a Makefile cleanup with unrelated historical moves.

5. Update active references.

   Update `SRC/Makefile`, `SRC/tools/show_make_help.ps1`, current operator
   docs, planning docs, and any non-transcript links that still point at the old
   active path. Keep historical transcript text intact.

6. Regenerate only source-derived docs.

   If the operational source scan changes, update `SRC/tools/gen_docs.ps1`
   first, then run `make -C SRC docs`. Do not hand-edit files under
   `DOC/GENERATED/`.

7. Prove the current path still builds.

   At minimum run:

   ```text
   git diff --check
   make -C SRC firmware
   make -C SRC asm-test
   ```

   Add narrower or broader checks when a batch touches release targets, STR8,
   HIMON, ASM-F2, or board-ingested data.

## Link Policy

Current docs should link to the current path. Historical docs may link to the
archive path after a move. Hardware transcripts should keep the path that was
true when the proof was recorded; add a short note near the current proof plan
when a moved source is now found under `SRC/ARCHIVE/`.

If a moved file is still a useful example, keep one forward pointer in the old
guide section rather than scattering duplicate archive links through the docs.

## Done Criteria

This migration is done when:

```text
active SRC/DOC sample/test/proof lanes contain only current onboard inputs
STR8-N, HIMON V, and ASM-F2 build paths keep their intended structure
retired source/data lives under SRC/ARCHIVE/
operator docs point only at current paths
historical docs point at archive paths where useful
DOC/GENERATED reflects only operational source
```
