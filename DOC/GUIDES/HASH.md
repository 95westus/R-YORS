# R-YORS Hash Reference

R-YORS uses FNV-1a as the one hash algorithm for HIMON runtime/catalog/symbol
lookup. STR8 V0 does not use FNV; future catalog-owning STR8 may use the same
hash path.
and routine block identity.

FNV means Fowler/Noll/Vo. The external algorithm reference for the constants,
update order, and little-endian persistent storage convention is RFC 9923:
<https://www.rfc-editor.org/rfc/rfc9923.html>.

```text
[HASH:XXXXXXXX]  32-bit FNV-1a routine/catalog/symbol hash
```

FNV-1a is current, not future-only. It is already used by Himonia-F command
dispatch and is the intended lookup hash for catalogs, symbols, commands,
routines, fixups, and routine block comments.

`[HASH:XXXXXXXX]` is the 8-hex-digit routine header hash written in `; ROUTINE:`
lines:

` ; ROUTINE: SOME_ROUTINE  [HASH:12345678] `

That value is FNV-1a over the canonical uppercase routine name.

## FNV-1a Catalog Hash

FNV-1a is:

```text
size:       32 bit
algorithm:  FNV-1a
storage:    hash0,hash1,hash2,hash3 low byte through high byte
owner:      Himonia-F/HIMON command, catalog, symbol, and fixup lookup
```

Example:

```text
SYS_WRITE_CHAR -> $49023C1B -> stored 1B,3C,02,49
```

Current Himonia-F command records use this proving shape:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,entry...
```

The compact future catalog record keeps FNV-1a but can replace the 3-byte
signature with one versioned signature byte. See [HASH_MAP.md](./HASH_MAP.md).

Routine block comments may include both fields:

```text
; ROUTINE: SYS_WRITE_CHAR  [HASH:49023C1B]
; FNV1A_LE: 1B,3C,02,49
```

The first line carries the canonical hash. A following `FNV1A_LE` line is only
an optional storage reminder for catalog records.

## How HASH Is Generated

For each routine header, the generator builds a canonical payload:

1. Routine name from the header
2. Uppercase ASCII
3. If a legacy header lists multiple names with `/`, the first name is the
   primary hash identity

Payload example:

`SYS_WRITE_CHAR`

Then it computes 32-bit FNV-1a:

```text
offset basis: $811C9DC5
prime:        $01000193
step:         hash = (hash xor byte) * prime mod 2^32
```

The result is formatted as uppercase 8-digit hex and written as
`[HASH:XXXXXXXX]`.

## Refresh HASH Across The Repo

From `SRC/`:

`make routine-hash-comments`

or directly:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_routine_hash_comments.ps1 -Src .`

The generator updates every `; ROUTINE:` header under:

- `SRC/STASH`
- `SRC/TEST`
- `SRC/SESH`

## Collision Check

The generator detects duplicate `HASH` values across all scanned routine headers.

- It reports each collision group with file path, line, and routine name.
- By default it exits non-zero when any collision is found (`-FailOnCollision $true`).
- To report-only (no fail), run with:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_routine_hash_comments.ps1 -Src . -FailOnCollision $false`
