# STR8 Flash Update Proposal

This is a proposal note for STR8 flash update behavior. The first-pass `M`
physical flash map is implemented; the `U T`, `U H`, and `U S` update commands
remain future command proposals.

The direction is deliberately simple:

```text
HIMON L F stays conservative.
STR8 owns recovery and dangerous flash update flows.
STR8 should be able to update target code/ranges; HIMON is the default target.
STR8 should also have an explicit, harder-to-trigger option to update STR8.
Monitor replacement means 4K sector rebuild, not casual byte writes.
```

## Command Shape

Keep ordinary STR8 small, but give it a few clear update/report verbs:

```text
M    map banks/sectors with condensed used/erased status
U T  update target body or normal ROM image region; HIMON is the default target
U H  alias/profile for updating the default HIMON target
U S  update STR8 protected window/top sector
```

`M` is the report command because the operator question is "show me the flash
map." `F` should stay reserved for a broader flash submenu or dangerous flash
tools. `C` should stay available for future condense/compact language rather
than meaning this cheap physical map.

`U S` should require a stronger confirmation than ordinary restore/update work:

```text
STR8>U S
UPDATE STR8? TYPE STR8:
```

This should not directly stream bytes into `$FA00`. It should stage a complete
top-sector transaction, preserve required bytes, erase/write/verify, then reset.

`U T`, `U H`, and `U S` may receive S19, but S19 is only the transport. The
update unit is a complete 4K staged sector image:

```text
copy live destination sector into RAM
merge S19 bytes into the RAM sector image
if the RAM sector differs from flash, confirm erase
erase the flash sector
write the full RAM sector image
verify the full sector
```

Near-term install packages are still prepared off board. The host build creates
the vector-complete ROM `.bin`, then converts the install range to S1/S9 text
for the board. STR8 receives that text and stages sectors; it does not need to
turn a binary into S19 onboard. Later onboard ASM/export work can bypass S19 by
handing STR8 complete sector images or sealed candidate records directly.

Future STR8 transport may add an S2/S8 profile, commonly written as `.s28`.
That name is a file/profile hint; the records themselves are S2 data records
with 24-bit addresses and an S8 termination record. The third address byte gives
STR8 room to treat incoming records as physical SST39SF010A flash-chip
addresses instead of only as CPU-visible `$8000-$FFFF` bytes.

For the current four 32K bank idea, that future linear map names physical
flash-chip addresses:

```text
bank 0  physical flash $00000-$07FFF
bank 1  physical flash $08000-$0FFFF
bank 2  physical flash $10000-$17FFF
bank 3  physical flash $18000-$1FFFF  reset/default boot bank
```

Translation is simple and visible:

```text
bank        = linear_address >> 15
bank_offset = linear_address & $7FFF
cpu_address = $8000 + bank_offset
```

So physical flash address `$18000` means bank 3 at CPU `$8000`, `$1F000` means
bank 3 top sector, and `$1FFFA-$1FFFF` means the reset/default boot bank's
vector block. That makes S2/S8 a good later fit for bank-aware restore, bulk
data storage, retrieval, and transport. It is not a V0 requirement; V0 can stay
with S1/S9 install packages and explicit STR8 bank/range policy.

V0 should not try to be clever about direct 1->0 patching for HIMON/STR8
replacement. The first rule is sector rebuild. Direct 1->0 writes remain useful
for deliberate one-way flags or later append-only records.

The implementation should still start with the friendliest proof:

```text
install default HIMON target below the protected STR8 sector
verify that STR8 survives a bad or missing target
only then add the STR8/top-sector self-update path
```

That keeps V0 small while avoiding a HIMON-only installer. The low-level
operation is "install this target image/range"; the command profile can still
say `U H` when the target is the bundled HIMON image.

## M Map Report

`M` scans bank by bank, sector by sector, then restores bank 3 before returning
to the prompt.

Current first-pass output shape:

```text
STR8>M
BANK0     BANK1     BANK2     BOOT
++--++--  --++--++  --------  ++++++++
STR8>
```

Each status character position maps to one 4K sector:

```text
8=$8000 9=$9000 A=$A000 B=$B000 C=$C000 D=$D000 E=$E000 F=$F000
```

The first line is a label line. Current labels can show bank numbers plus the
boot role, because bank 3 is the bank the board boots from. Future labels may
be role names or catalog names without changing the status grammar:

```text
BASE      RECOV     HIMON     DATA
++--++--  --++--++  --------  ++++++++
```

Status symbols:

```text
- = erased/unused, all bytes are $FF
+ = used, at least one byte is not $FF
```

A later detail mode or separate command can reuse the same eight sector
positions for semantic labels:

```text
BOOT
----+HHS
```

Possible semantic symbols:

```text
- = erased/unused, all bytes are $FF
+ = used, not yet classified
H = HIMON-like sector
S = STR8/top-sector boot material
```

The first-pass `M` report is physical and cheap. The semantic display can
arrive after STR8 has recognizers for WDCMON, HIMON, STR8, RCAT/data records,
or stored bank roles.

## Erase Policy

STR8 should prefer the obvious whole-sector rule over a clever one-byte poll.
For V0 HIMON/STR8 replacement, any changed staged sector is erased and rebuilt:

```text
if sector is all $FF:
  skip erase

if sector is not all $FF:
  issue sector erase
  wait until the whole sector scans all $FF

if erase command fails or full-sector erased wait times out:
  stop
```

The important distinction:

```text
one-byte polling asks "did one watched byte finish?"
whole-sector waiting asks "is the sector actually erased?"
```

For STR8, whole-sector waiting is slower but clearer and safer.

For a monitor update, "write" should be understood as "rebuild the selected 4K
sector." The chip still programs bytes after erase, but the operator-facing
operation is sector erase, full-sector write, and full-sector verify.

## Routine Shape

Build this as routines made from routines:

```text
STR8_CMD_M
  RAM-resident scan fills four map-mask bytes
  scan restores bank 3
  print M/map header
  for bank 0..3
    print eight mask bits as - or +

STR8_ENSURE_SECTOR_ERASED
  call STR8_SECTOR_ERASED
  if erased: success
  issue erase command
  call STR8_WAIT_SECTOR_ERASED

STR8_WAIT_SECTOR_ERASED
  repeat until timeout
    call STR8_SECTOR_ERASED
    if erased: success
  fail

STR8_SECTOR_ERASED
  scan one selected 4K sector
  return C=1 when all bytes are $FF
  return C=0 when any byte is not $FF
```

## Mermaid Map

```mermaid
flowchart TD
    RESET["Reset"] --> STR8["STR8"]
    STR8 --> BOOT{"S pressed during countdown?"}
    BOOT -->|no| HIMON["HIMON warm boot"]
    BOOT -->|yes| PROMPT["STR8 prompt"]

    PROMPT --> M["M: condensed flash map"]
    M --> SCAN_BANK["For each bank 0..3"]
    SCAN_BANK --> SCAN_SECTOR["For each sector 8..F"]
    SCAN_SECTOR --> SECTOR_ERASED["STR8_SECTOR_ERASED"]
    SECTOR_ERASED --> REPORT["Print - or +"]
    REPORT --> RESTORE_B3["Restore bank 3"]
    RESTORE_B3 --> PROMPT
    PROMPT --> DETAIL["future detail scan: semantic sector labels"]
    DETAIL --> SEMANTIC["Example BOOT = ----+HHS"]
    SEMANTIC --> PROMPT

    PROMPT --> UT["U T: update target/body"]
    PROMPT --> UH["U H: default HIMON target profile"]
    PROMPT --> US["U S: update STR8/top sector"]
    US --> CONFIRM["Require literal STR8 confirmation"]
    UT --> STAGE["Stage complete sector/image"]
    UH --> STAGE
    CONFIRM --> STAGE

    STAGE --> PRESERVE["Preserve protected bytes, config, vectors"]
    PRESERVE --> ENSURE["STR8_ENSURE_SECTOR_ERASED"]
    ENSURE --> ALREADY{"Sector all $FF?"}
    ALREADY -->|yes| PROGRAM["Program non-$FF bytes"]
    ALREADY -->|no| ERASE["Issue erase command"]
    ERASE --> WAIT["Wait for whole sector all $FF"]
    WAIT -->|timeout/fail| STOP["Stop and report failure"]
    WAIT -->|erased| PROGRAM
    PROGRAM --> VERIFY["Verify staged image by read-back"]
    VERIFY -->|fail| STOP
    VERIFY -->|ok| RESET2["Reset or return through bank 3"]
```

## Open Refinements

- Decide whether later displays need an optional verbose `ERASED/USED` mode.
- Decide whether `U T`/`U H` receive S-records, a full bank image, or both.
- Decide whether future bank-aware transport should accept S2/S8 `.s28`
  records in addition to V0 S1/S9 packages.
- Decide whether `U S` requires source image hash/version checks before
  staging.
- Decide how much progress output STR8 should print during erase/program/verify.
- Decide whether failures should report the first bad bank/sector/address.
