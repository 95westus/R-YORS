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
SUGGEST `$02`, and LINK `$03`. Success returns `C=1`; failure returns `C=0`
with the status in A and `$7E30`. Successful LOAD returns the destination in
X/Y, and successful SUGGEST returns the suggested install base in X/Y.

## AP v2 Package Boundary

An AP v2 package begins `A P 02 total_lo total_hi`, followed by exactly five
tagged sections in `S R E I B` order. Every section has a tag and little-endian
16-bit payload length. The seal payload is eleven bytes: flags, base, end,
length, and FNV-1a, with all words little-endian. Packages are at most `$1000`
bytes.

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
