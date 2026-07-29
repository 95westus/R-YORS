# STR8 Common String And Bank 0-2 Installer Game Plan

This is the proposed next-improvement game plan for:

- one STR8-hosted Bank-3 common HB/NUL output service;
- compatible HIMON and ASM-F2 use of that service;
- measured product-prefix compression above the string ABI;
- a guarded Bank 0-2 sector installer built on the existing STR8 RAM worker;
- a later, separately approved full-bank installer.

```text
status:     worker-home and string-ABI policy frozen; implementation proposed
provenance: ORIG-WLP2, COLLAB-AI
evidence:   DERIVED-SRC for current entries, worker behavior, and RAM ownership
```

This plan does not change the accepted `J0`-`J2` opaque-bank handoff. Bank 3
remains the physical-reset supervisor and recovery root. Banks 0-2 remain
opaque 32K systems that own all of `$8000-$FFFF`.

## Ownership Boundary

The common string implementation is physically hosted by STR8, but its
contract is the R-YORS Bank-3 system ABI. The proposed Bank 0-2 installer is
also a Bank-3 supervisor service.

Neither service is a board-global ABI after an opaque guest is selected:

- while Bank 3 is selected, HIMON and ASM-F2 may use the local STR8 services;
- after `Jn` commits, Bank 3 is unmapped and the guest owns its complete image;
- a coherent R-YORS image in Bank 0-2 may provide its own compatible STR8
  services;
- an unrelated guest is not required to provide STR8, HB output, a service
  header, or any fixed entry.

The RAM service cells survive a bank switch, but a saved `$Fxxx` address names
the currently selected bank's bytes. A Bank-3 service pointer must never be
used as though it still names Bank-3 code after another bank is selected.

## Worker Classes

Handoff and returning bank access are different contracts:

| Worker class | Home | Target | Return contract |
| --- | --- | --- | --- |
| `Jn` handoff | Bank 3 | Bank 0-2 | commits target and never returns |
| first installer | Bank 3 | Bank 0-2 | restores and verifies Bank 3 before return |
| future guest worker | explicit `HOME_BANK` | another bank | restores and verifies `HOME_BANK` before return |

NMI vector ownership follows the currently selected bank, not the bank that
started the RAM worker. When a Bank-1 guest temporarily selects Bank 2, CPU
execution may remain in RAM, but NMI vector fetches come from Bank 2 until
Bank 1 is restored.

## Bank-3 Supervisor Worker Policy

The first Bank 0-2 installer remains Bank-3-owned and uses a supervisor-only
worker contract.

Entry rules:

1. Decode the actual current bank before any destructive action.
2. Require the actual bank to be Bank 3.
3. Reject Bank 0-2 entry with `NOT_SUPERVISOR`.
4. Accept target banks 0-2 only.
5. Reject Bank 3 as an installer target.
6. Validate the complete request before selecting another bank.

Selected-bank rules:

1. Disable maskable IRQ.
2. Keep every instruction, helper, table, pointer, state byte, and failure path
   needed during selected-bank access in RAM.
3. Do not call ROM, print, or read a Bank-3 literal while another bank is
   selected.
4. Keep every NMI source quiescent. The W65C02 cannot mask NMI.
5. Record status, failure address, observed byte, and expected byte in RAM.

Return rules:

1. Restore Bank 3 on every returning success or failure path.
2. Decode the current bank again and require Bank 3.
3. Return to ROM only after the Bank-3 verification succeeds.
4. Use `BAD_HOME` for a detected home-bank mismatch.
5. If Bank 3 cannot be restored and verified, do not execute `RTS`, `RTI`, or
   any ROM transfer.
6. On restoration failure, reset the flash command state where possible,
   execute `SEI`, record `BAD_HOME`, and halt/recover entirely in RAM until
   physical reset.

`NOT_SUPERVISOR` and `BAD_HOME` names are frozen here. Numeric status values
remain to be assigned with the installer ABI so they do not collide with
existing STR8 record-service results.

## Future Home-Aware Guest Worker

A reusable home-aware guest worker is a later optional specification. It is
not part of the first installer.

Its minimum contract is:

```text
IN:
    HOME_BANK
    TARGET_BANK
    operation-specific request

ENTRY:
    decode actual bank
    require actual bank == HOME_BANK
    reject mismatch with BAD_HOME

SELECTED:
    execute completely from RAM
    make no home-bank ROM calls
    keep NMI sources quiescent

RETURN:
    restore HOME_BANK
    verify actual bank == HOME_BANK
    only then return to the caller
```

A guest worker should reject Bank-3 mutation unless a separate, explicit
recovery authority is designed and approved. A handoff operation and a
temporary-access operation must remain distinct: handoff never returns;
temporary access always restores `HOME_BANK`.

Opaque guests remain free to implement a different policy. Qualification must
record whether their bank/mutation commands are disabled, supervisor-only, or
genuinely home-aware. Accidental return through a different bank's matching
address is never accepted as compatibility.

## Common String ABI

The HB ABI is unchanged by the bank-worker policy. It remains local to the
selected coherent R-YORS bank and is never called while a different bank is
temporarily selected.

The proposed common entry recognizes both HB and NUL termination so old
C-string interfaces can remain compatibility aliases while ROM display
literals standardize on HB.

```text
routine:  STR8_SYS_WRITE_STRING_XY
scope:    foreground service in the currently selected coherent R-YORS bank

ZP:
    $C5  SYS_STR_PTR_LO
    $C6  SYS_STR_PTR_HI
    volatile across the call

IN:
    X = source address low
    Y = source address high

OUT:
    A = characters emitted, $00-$FF
    C = 1 terminator found
    C = 0 255-character cap reached

PRESERVED:
    X, Y

FORMAT:
    $00       stop without emitting or counting the terminator
    $81-$FF   mask bit 7, emit and count the final character, then stop
    $80       reserved/invalid HB terminal
```

The routine is not reentrant and is not callable from NMI. NMI code must not
call it or use `$C5/$C6`. It may be used again only after a temporary bank
worker has restored the coherent home bank. It is never called while another
bank is temporarily selected.

At the 255-character boundary:

- 255 emitted characters followed by `$00` return `A=$FF`, `C=1`;
- 255 emitted characters followed by more text return `A=$FF`, `C=0`;
- no 256th character is emitted.

The first fixed-entry candidate is `$F010`, after the existing
`$F000/$F003/$F006/$F009` entries and `$F00C-$F00F` service header. That
address is not frozen until the build layout and compatibility gates pass.

Proposed additive STR8 capability bits are:

```text
$08  common HB/NUL string entry available
$10  Bank 0-2 sector installer service available
```

Existing capability bits `$01/$02/$04` and record-service behavior remain
unchanged. Old clients that mask required bits `$07` must continue to work.

The existing HIMON C-string and HB-string service-vector order, count, and
version remain unchanged. Once compatibility is proven, both vector slots may
point to the same common implementation. `BIO_FTDI_PUT_CSTR` and
`SYS_WRITE_CSTRING` remain valid compatibility names.

## NMI Policy

The common string service is deliberately foreground-only. The current
default-NMI debug snapshot therefore cannot simply be redirected to it.

The proposed production policy is:

1. The pre-HIMON default NMI path performs no string or console output.
2. HIMON installs and owns its qualified NMI trap during normal Bank-3 use.
3. Explicit debug builds may retain a separate debug output mechanism.
4. The old C backend leaves the production link only after no production NMI
   or debug path requires it.

This NMI change is a separate proof gate. If silent default NMI is not
approved, the existing debug/C backend remains.

## Product-Prefix Compression

Prefix compression is a layer above the common string ABI. It must not make
product names part of the foundational output contract.

Candidate prefix IDs are:

```text
0 ASM
1 HIMON
2 STR8
```

`ASM` includes `ASM BYE`, `ASM OK`, `ASM V1`, `ASM>$`, and
`ASM-F2 00.0728(2113)`.

Before implementation:

1. Regenerate the complete string inventory and duplicate counts.
2. Measure prefix-table, offset/pointer-table, decoder, and call-site cost.
3. Compare an A-prefix/X-Y-suffix interface with a tokenized stream.
4. Implement only a net-positive linked result.
5. Do not consume constrained STR8 space merely to save bytes in another
   product.

## First Bank 0-2 Installer Service

The first service promotes the already-proven 4K staging mechanism:

```text
BANK_STAGE_SECTOR
    target bank 0..2
    target sector $80,$90,$A0,$B0,$C0,$D0,$E0,or $F0
    approved 4K staging buffer

BANK_PROGRAM_STAGED
    target bank and sector
    erase
    program
    read-back verify
    restore and verify Bank 3
```

The public operation must not require callers to manipulate private
`$1FE9-$1FFF` worker state. The request/result contract must expose target
bank, target sector, staging buffer, flags, status, failure address, observed
byte, and expected byte.

The service verifies that the current bank is 3 before accepting the request.
Entry from Bank 0-2 returns `NOT_SUPERVISOR` without selecting a bank or
mutating flash.

The first operator-facing implementation is a loadable AP, not a large
resident STR8 command. It stages the original sector, overlays the validated
payload, reports the exact target and CRC, obtains full-word destructive
confirmation, calls the STR8 service, and prints results only after Bank 3 is
restored.

## Later Full-Bank Installer

Full 32K installation remains behind a separate approval gate. Its expected
shape is:

```text
INSTALL Bn LOW    $8000-$BFFF
INSTALL Bn MID    $C000-$EFFF
INSTALL Bn TOP    $F000-$FFFF
INSTALL Bn ALL    $8000-$FFFF
```

For a full or partial managed installation:

1. Validate the target bank, expected CRC, and expected reset vector.
2. Invalidate the target reset vector before changing other sectors unless a
   later Bank-3 manifest gate provides equivalent protection.
3. Program and verify through the RAM worker.
4. Verify the complete logical result.
5. Program `$FFFC/$FFFD` last.
6. Verify the final full-bank CRC.
7. Commit Bank-3-owned metadata last.

This is recoverable, not rollback-atomic. The old target image is lost after
its first sector erase. Bank 3, another bank, or a retained host image supplies
recovery.

## Implementation Slices

### Slice 0: Baseline

- build ASM-F2, HIMON, and STR8;
- run `make -C SRC asm-test`;
- record fixed entries, product ends, worker store/run ranges, worker length,
  and the STR8 resident/worker gap;
- preserve current bank CRC and vector evidence;
- rerun the string inventory.

### Slice 1: Common String Entry

- reserve `$C5/$C6`;
- add the candidate fixed jump and capability `$08`;
- implement and host-test both terminators, count/status, truncation, and X/Y
  preservation;
- keep old printers and the C backend during this isolated proof.

### Slice 2: Bank-3 Client Migration

- install/prove new STR8 before a dependent HIMON;
- point the HIMON HB service vector at the common entry when capability `$08`
  is present;
- keep a transitional fallback while old STR8 images remain supported;
- leave ASM-F2 on its existing HB service vector;
- preserve the C ABI name and service slot.

### Slice 3: NMI And C-Backend Gate

- prove the selected default-NMI policy;
- remove production debug-string dependency only after that proof;
- redirect the C compatibility entry to the common routine;
- remove the old backend from the production link without deleting test source
  prematurely.

### Slice 4: Prefix Measurement

- produce an exact savings worksheet;
- implement only if the final linked result is net-positive;
- rerun the complete sorted product string inventory.

### Slice 5: Supervisor Installer Service

- add capability `$10`;
- add `NOT_SUPERVISOR` and `BAD_HOME` without colliding with existing status
  values;
- publish safe stage/program operations;
- enforce current-bank 3 at entry;
- restore and verify Bank 3 on every returning path;
- make a restoration failure remain in RAM.

### Slice 6: Loadable Sector Installer

- replace direct private-worker-state use in the transient proof;
- retain exact bank, sector, range, CRC, confirmation, status, and failure
  evidence;
- perform the first destructive test only on a deliberately disposable,
  inventoried sector with physical-reset recovery ready.

### Slice 7: Full-Bank Specification

- settle transport and sector ordering;
- settle reset-vector-last and Bank-3 manifest policy;
- settle recovery and resume behavior;
- require separate approval before implementation or hardware mutation.

## Acceptance Gates

The first implementation is accepted only when:

- existing fixed STR8 entries remain valid;
- old clients continue to accept the additive capability header;
- all common-string edge cases pass;
- X/Y and A/carry behavior match the contract;
- the default-NMI decision has explicit proof;
- Bank-3 timeout, HIMON, ASM-F2, and `J0`-`J2` regressions pass;
- the installer rejects entry outside Bank 3;
- every returning worker path restores and verifies Bank 3;
- no restoration failure returns into ROM;
- guest qualification records bank/mutation command policy;
- one disposable Bank 0-2 sector passes stage/program/read-back verification;
- untouched sectors and banks retain their recorded CRCs;
- physical reset returns to Bank 3; and
- hardware evidence is appended rather than replacing prior transcripts.

Approval of this plan does not itself authorize a board flash operation, a
full 32K installer, Bank-3 mutation through the new installer, or a required
ABI inside unrelated opaque guests.
