# Archived HIMON Branches

This directory holds retired monitor branches that are kept for reference but
are no longer active build or generated-documentation inputs.

The broader archive policy lives in `SRC/ARCHIVE/README.md` and
`DOC/GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md`.

Active HIMON work is `SRC/HIMON/himon.asm`.
Some archived source includes preserve old pre-move include paths because these
files are reference material, not current build inputs.

Archived here:

- `himon-parent.asm`
- `mon.asm`
- `mon-cmd-*.inc`
- `himonia.asm`
- `himonia-f.asm`
- `tools/*himonia*.ps1`

The useful Himonia-F line has been folded back into `himon.asm`. When we say
HIMON in current work, we mean that active file and its directly included
support files.
