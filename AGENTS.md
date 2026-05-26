# Agent Notes

This repository is the R-YORS W65C02/HIMON/STR8 workbench. Prefer small,
inspectable changes and keep hardware-proven transcripts intact. Favor
size-conscious W65C02 code built as routines made from routines.

## Common Commands

- `make -C SRC asm-test` builds the ASM v1 core and runs the smoke checks.
- `make -C SRC routine-word-tree` regenerates the routine word hierarchy.
- `make -C SRC help Q=<term>` lists relevant make targets.
- `git diff --check` should pass before committing; line-ending warnings are
  common on Windows and are not whitespace errors.

## Editing Guidelines

- Use existing WDC 65C02 assembly style and local naming conventions.
- Treat files under `DOC/GENERATED/` as generated output. Update the generator
  in `SRC/tools/` when changing generated document structure.
- Do not remove or rewrite hardware transcripts in `DOC/GUIDES/LOGS/`; append
  new evidence instead.
- Keep ASM slice changes narrow and update `DOC/GUIDES/ASM/TEST_PLAN.md` when
  a test phase or hardware proof changes.
- Avoid reverting unrelated dirty files; assume they may be user work.

## Current Project Shape

- HIMON resident FNV records use `F N (V|$80) hash0 hash1 hash2 hash3 K`.
- RJOIN currently resolves executable FNV records through `THE_JOIN_EXEC_XY`.
- ASM v1 loads at `$2000` and currently emits smoke code at `$7000`.
- STR8/HIMON hardware transcripts are the source of truth for on-board proof.
