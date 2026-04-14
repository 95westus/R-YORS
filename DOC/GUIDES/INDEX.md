# R-YORS Guide

## Guide Index
- [INDEX.md](./INDEX.md)
- [TOC.md](./TOC.md)
- [BIB.md](./BIB.md)
- [GLOSSARY.md](./GLOSSARY.md)
- [REF.md](./REF.md)
- [XREF.md](./XREF.md)
- [TODO.md](./TODO.md)
- [FUTURE.md](./FUTURE.md)

## String Convention Snapshot
- `CSTR`: NUL-terminated byte strings.
- `HBSTR`: HIBIT-terminated byte strings (bit7 set on final byte).
- `UTL_FIND_CHAR_CSTR`: scan/search helper for CSTR.
- `UTL_FIND_CHAR_HBSTR`: scan/search helper for HBSTR (new).
- `SYS_WRITE_CSTRING` / `COR_FTDI_WRITE_CSTRING`: write path for CSTR.
- `SYS_WRITE_HBSTRING` / `COR_FTDI_WRITE_HBSTRING`: write path for HBSTR.
