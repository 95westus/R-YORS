# HASH Routine Header IDs

`HASH` is the 4-hex-digit routine header ID written in `; ROUTINE:` lines:

` ; ROUTINE: SOME_ROUTINE  [HASH:ABCD] `

## How HASH Is Generated

For each routine header, the generator builds a canonical payload:

1. Relative file path, uppercase, `/` separators  
2. `|` separator  
3. Routine name list from the header, split on `/`, trimmed, uppercased, then rejoined as `NAME1 / NAME2`

Payload example:

`SRC/APP/STASH/UTIL/UTIL-HEX.ASM|UTL_HEX_NIBBLE_TO_ASCII`

Then it computes a simple 16-bit rolling checksum over ASCII bytes:

`hash = (hash * 31 + byte) mod 65536`

The result is formatted as uppercase 4-digit hex and written as `[HASH:XXXX]`.

## Refresh HASH Across The Repo

From `SRC/`:

`make routine-hash-comments`

or directly:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_routine_hash_comments.ps1 -Src .`

The generator updates every `; ROUTINE:` header under:

- `SRC/APP/STASH`
- `SRC/APP/TEST`
- `SRC/APP/SESH`

## Collision Check

The generator now detects duplicate `HASH` values across all scanned routine headers.

- It reports each collision group with file path, line, and routine name.
- By default it exits non-zero when any collision is found (`-FailOnCollision $true`).
- To report-only (no fail), run with:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_routine_hash_comments.ps1 -Src . -FailOnCollision $false`
