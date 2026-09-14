# ASM ABI v1

ASM ABI v1 freezes the two binary boundaries shared by ASM-F2, HIMON, and
stored AP programs. The canonical machine-readable constants are
`SRC/ASM/asm-abi-v1.inc`; `make -C SRC asm-abi-check` rejects drift.

## HIMON Service Boundary

The resident service header is `RY`, version `$01`, with eleven ordered
16-bit vectors at `$7E06-$7E1B` and an XOR checksum at `$7E1C`. The vector
order is join, write byte, write C string, write hex byte, CRLF, read C string,
hex-nibble conversion, FNV initialize, FNV update, uppercase conversion, and
write HB string.

ASM also consumes the PACK40 vectors at `$7E1F/$7E21`, the flash-install
doorway at `$7E25`, and the AP service doorway at `$7E2D`. The AP request/result
card is frozen at `$7E2F-$7E40`; operations are PARSE `$00`, LOAD `$01`,
SUGGEST `$02`, LINK `$03`, and foreground APMAN bootstrap `$04`. Success
returns `C=1`; failure returns `C=0` with the status in A and `$7E30`.
Successful LOAD returns the destination in X/Y, and successful SUGGEST returns
the suggested install base in X/Y.

### Interface ledger

`SRC/ASM/asm-abi-v1.inc` is the one literal-address owner for this boundary.
HIMON and ASM may retain local role names, but those names must be aliases of
the canonical constants. `asm-abi-check` rejects a second literal `EQU` in the
published `$7E00-$7E40` span and pins the boot-vector order.

HIMON common initialization must complete before an ASM entry. It publishes
the join pointer, copies the service header and eleven destinations, computes
the checksum, and publishes the extension doorways. ASM verifies `RY`, version,
minimum vector count, and checksum before copying or calling a destination.

| Cell/vector | Call input | Contract result | Visible writes |
| --- | --- | --- | --- |
| `$7E00-$7E01` hash acquire | Cell contains `THE_JOIN_EXEC_XY`; call it with X/Y pointing to four little-endian FNV bytes | C set with X/Y at the executable entry; C clear on no compatible EXEC record | HIMON hash-scan and returned-record metadata |
| `$7E06` join | Same as hash acquire | Same join result, including the extra-record pointer when present | HIMON hash-scan and returned-record metadata |
| `$7E08` write byte | A is the byte | Byte is written synchronously | Console/device state and HIMON TX indication |
| `$7E0A` write C string | X/Y point to a NUL-terminated string | String is written synchronously | Console/device state and HIMON TX indication |
| `$7E0C` write hex byte | A is the byte | Two uppercase hexadecimal digits are written | Console/device state and HIMON TX indication |
| `$7E0E` write CRLF | None | CR/LF is written | Console/device state and HIMON TX indication |
| `$7E10` read C string | X/Y point to writable storage for at most 255 bytes plus NUL | C set and A is the accepted length; C clear and A is the input-abort status | Destination prefix and NUL, HIMON input/editor state, console echo, and RX/wait indication |
| `$7E12` hex nibble | A is an ASCII hexadecimal character | C set and A is `$00-$0F`; C clear for invalid input | Utility-private scratch only |
| `$7E14` FNV initialize | None | Shared FNV state becomes the 32-bit offset basis | Shared FNV zero-page state |
| `$7E16` FNV update | A is one byte | Shared FNV state is folded once | Shared FNV and multiply-term zero-page state |
| `$7E18` uppercase | A is one byte | Lowercase ASCII becomes uppercase; every other byte is unchanged | None outside flags/registers |
| `$7E1A` write HB string | X/Y point to a high-bit-terminated string | Low seven bits of each byte are written through the terminating byte | HIMON parser pointer, console/device state, and TX indication |
| `$7E1F` PACK40 ASCII | A is ASCII or a high-bit final character | C set and A is code `$00-$27`; C clear if unsupported | PACK40-private scratch only |
| `$7E21` PACK40 pack three | A/X/Y are three codes `$00-$27` | C set and X/Y are the packed little-endian word; C clear if a code is invalid | PACK40-private scratch |

The flash-install doorway uses `$7E27-$7E2C` as source, destination, and length
words. It accepts a nonzero RAM source copied into erased Bank-3 low flash
`$8000-$BFFF`, verifies every programmed byte, and returns only C. Failure may
leave an already-programmed prefix; there is no rollback promise.

For the AP doorway, the caller writes operation `$7E2F`, source `$7E31-$7E32`,
and destination `$7E33-$7E34` as required. Parse fills package/body lengths,
counts, install/relocation pointers, and status without copying BODY. Load may
copy or patch part of the destination before a later validation/link failure;
the caller must never execute a failed result. Suggest is read-only and returns
the chosen install address in X/Y. Link consumes the parsed import/relocation
state. Manager is a foreground transition that may overwrite the documented
APMAN staging, command-shadow, and overlay ranges.

All calls require Bank 3 on entry and return with Bank 3 selected. They are
foreground and non-reentrant. A, X, Y, and processor flags are volatile except
for results named above. Each call is hardware-stack balanced on return, but
its internal depth is provider-private. HIMON parser, load, hash, and service
scratch is likewise provider-private; callers may rely only on the published
cells and explicit result registers. Interrupt-time and nested use are outside
ABI v1.

## AP v2 Package Boundary

An AP v2 package begins `A P 02 total_lo total_hi`, followed by exactly five
tagged sections in `S R E I B` order. Every section has a tag and little-endian
16-bit payload length. The seal payload is eleven bytes: flags, base, end,
length, and FNV-1a, with all words little-endian. Packages are at most `$1000`
bytes.

The five-tag sequence is called **SREIB** (pronounced approximately
“shrybe”): **S**eal, **R**elocations, **E**xports, **I**mports, **B**ody. The
pronunciation deliberately echoes German *schreib*, the imperative and stem
form of *schreiben* (“to write”). SREIB is an English project mnemonic, not a
German spelling or a second encoding order; the canonical serialized and
displayed order remains `S R E I B`.

Relocation rows are five bytes: kind, site offset, and target/addend word.
Kinds `$01-$03` are internal ABS16/LO8/HI8. Kinds `$04-$06` are import
ABS16/LO8/HI8; their final byte is the signed addend. Export and import
sections begin with a count and contain at most 64 variable-length PACK40 name
rows. Kinds are EXEC `$01` and DATA `$02`; export flag `$80` marks the unique
runnable ENTRY. BODY bytes are covered by the seal FNV.

## Compatibility Rule

The frozen ABI includes the addresses, signatures, versions, vector order,
request/result cells, operation and status values, serialized field order,
row meanings, limits, and call results above. Any incompatible change requires
a new ASM ABI version and either a new AP format version or an explicit
backward-compatible reader.

ASM routine addresses, zero-page scratch, UDATA, internal tables, parser
implementation, command wrapper state, and code/data sizes are deliberately
not ABI. They may move without an ABI version change.
