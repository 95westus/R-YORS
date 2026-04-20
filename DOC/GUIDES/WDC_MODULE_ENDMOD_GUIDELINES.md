# WDC MODULE/ENDMOD Guidelines

- Use `MODULE`/`ENDMOD` around each logical unit that should export symbols.
- `XDEF` = symbols this module provides to other modules.
- `XREF` = symbols that come from outside this module.
- Hardware register/constants can be local `EQU`s inside a module; avoid repeating the same global symbol name in multiple modules unless using unique names, because `wdclib` tracks symbols in a global module dictionary.
- `make rom` rebuilds only when source modules changed; `make/test` links `test.obj` against `rom.lib`.
