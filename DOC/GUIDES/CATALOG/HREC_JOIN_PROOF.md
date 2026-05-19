# HREC JOIN PROOF

This note records the design thread and RAM proof for joining callers to
resident hash records. It is deliberately small and operational: search stays
at `$3000`, while the HREC join proof loads at `$4000`.

## Current Proof

```text
make -C SRC hrec-join-proof
source: SRC/TEST/apps/hrec-join-proof.asm
S19:    SRC/BUILD/s19/hrec-join-proof-4000.s19
map:    SRC/BUILD/map/hrec-join-proof-4000.map
start:  $4000
```

Expected current output:

```text
HREC JOIN PROOF $4000
WRITE OK
READ OK
FLUSH OK
CTRL OK
HEX OK
MISSING OK
KIND OK
HEXINV OK
DONE
```

The proof uses the "C" bootstrap path: it emits no text until it has joined
`BIO_FTDI_WRITE_BYTE_BLOCK` from resident ROM. If the write join fails, the
program simply returns.

## Terminology Trail

The first working words were `HREC_FIND` and `HREC_BIND_EXEC`. `bind` was
accurate, but it sounded larger than the current operation: not a full linker,
not relocation, not future CLINK.

`joint` was considered as the thing formed by a hash and an address. That was
close, but the routine name wanted a verb. We settled on `join`:

```text
HREC       hash record in active memory
FIND       locate a matching HREC by hash
JOIN       validate the record and join the caller to its payload
EXEC JOIN  require K=$00, then return a callable entry
```

So the current routine names are:

```text
HREC_FIND_XY
HREC_JOIN_EXEC_XY
```

The join result lives in:

```text
HREC_JOIN_LO
HREC_JOIN_HI
```

## Record Shape

The current tiny generic hash record is:

```text
'F' 'N' ('V'|$80) h0 h1 h2 h3 K
```

For today:

```text
K=$00  executable inline payload
       callable entry = record + 8
```

The proof rejects any other `K` for `HREC_JOIN_EXEC_XY`. Future records can use
other kind bytes for strings, pointer records, import lists, text lists, or
fuller RREC descriptors.

## What Is Tested

The positive joins prove that existing ROM HREC headers can be found and used:

```text
BIO_FTDI_WRITE_BYTE_BLOCK
BIO_FTDI_READ_BYTE_BLOCK
BIO_FTDI_FLUSH_RX
BIO_FTDI_GET_CTRL_C
UTL_HEX_ASCII_TO_NIBBLE
```

The error probes are intentionally boring:

```text
MISSING OK   a made-up hash `$DEADBEEF` is not found and returns C=0
KIND OK      a non-exec kind `$01` is rejected by the EXEC join gate
HEXINV OK    a joined helper can still report its own input error
```

`HEXINV` calls the joined `UTL_HEX_ASCII_TO_NIBBLE` with `'G'` and expects
`C=0`.

## Size Notes

The first proof, with only positive checks at `$3000`, was:

```text
$01D4 bytes = 468 decimal
```

After moving the proof to `$4000` and adding the negative probes:

```text
CODE  $01D5 = 469 decimal
DATA  $0073 = 115 decimal
TOTAL $0248 = 584 decimal
```

The reusable core from `HREC_JOIN_EXEC_XY` through `HREC_FIND_MATCH` is about
`$99` bytes, or 153 decimal bytes, in the current proof map. The rest is proof
harness, messages, test hashes, and output helpers.

The current search RAM proof is still separate:

```text
SRC/BUILD/s19/himon-search-proof-3000.s19
start: $3000
size:  $0565 bytes = 1381 decimal
```

## Edge Cases

Keep these visible before promotion into HIMON:

- Missing first write join is silent because there is no output path yet.
- A stale ROM image without a needed HREC header will make joins fail.
- `K` must be checked before calling; hash match alone is not permission to
  execute.
- The current HREC header does not encode a full ABI contract. The routine
  name/hash and documentation carry that burden until fuller RREC records exist.
- Duplicate hashes or duplicate records currently mean first match wins by scan
  order. Future catalog policy must decide ROM-vs-flash precedence.
- Hash collisions remain possible. RREC should eventually add stronger identity
  or proof fields when records become writable/user-created.
- The current scanner walks `$8000..$FFF7`, matching the existing HIMON command
  scan. Other active record regions should be explicit, not accidental.
- A record at the end of scan space must leave room for the full 8-byte header.
- `record+8` can cross a page; the carry path is required and currently present.
- The `BNE` kind check relies on `A=K` and `SEC` not changing the Z flag.
- Joined routines keep their own status contracts. Joining a routine does not
  make its input valid.
- `BIO_FTDI_GET_CTRL_C` is a consuming abort poll, not a non-destructive peek.
- The proof uses user/free zero page; a resident HIMON version needs a published
  scratch contract or a monitor-owned API surface.

## Promotion Path

The next clean step is to move the reusable pieces into HIMON:

```text
HREC_FIND_XY
HREC_JOIN_EXEC_XY
```

Then `S`, `COPY`, `MOVE`, `FILL`, `MODIFY`, and similar flash members can call
one resident join routine instead of each carrying a private scanner.

The durable version should eventually be reachable through a fixed monitor API
entry or jump table, so a member does not need a bootstrap scanner just to find
the scanner.
