# R-YORS TODO

Generated from current source scan on 2026-04-13 22:06:00 -05:00.

## Immediate Follow-Ups
- Resolve or intentionally gate the 2 unresolved imports (COR_FTDI_DEBUG_WRITE_FLAGS_A, COR_FTDI_DEBUG_WRITE_STR) seen in current full-lane scan.
- Confirm doc policy for 12 exported symbols without matching ROUTINE headers (likely constants/data labels in util-addr).
- Review 17 duplicated routine names across files and decide which should be shared vs app-local (see XREF.md).
- Add a repeatable make target to regenerate all GUIDE docs (not just CALL_MAP.md) from current source metadata.
- Keep top-shelf (STASH) promotion criteria explicit in SRC/APP/STATUS.md so stable app code remains auditable.
