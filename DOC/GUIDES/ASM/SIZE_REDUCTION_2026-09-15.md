# ASM-F2 Size Reduction — 2026-09-15

The qualified image saves **530 ROM bytes** without removing commands, changing
the AP-v2 format, moving RAM allocations, or changing the published ABI.
It is installed and hardware-qualified on COM4 in Bank-3 sectors 8-B.

The installed identity below remains `00.0915(2243)`. The current release ZIP
uses `00.0915(2324)`, with unchanged code/data apart from the banner stamp.
See [release qualification](../../../RELEASE/QUALIFICATION.json) for the
combined HIMON/ASM comparison and the repeated full host checks.

| Measurement | Original | First stage | Final candidate |
| --- | ---: | ---: | ---: |
| ROM bytes | 15,765 | 15,589 | 15,235 |
| End, exclusive | `$BD95` | `$BCE5` | `$BB83` |
| Free below `$C000` | 619 | 795 | 1,149 |
| UDATA bytes | 7,534 | 7,534 | 7,534 |

Candidate identity: `ASM-F2 00.0915(2243)`, linked S19 SHA-256
`FE1484B10C0B40BA2CC2F1962A468309473E44898F370B015F65997FABDAF978`.
The visible stamp is held fixed across candidate builds. Comparison sizes
are linked address spans, independent of the characters in the version text.

## Changes

| Change | Net bytes saved |
| --- | ---: |
| Remove unreachable runtime service-cache checks | 35 |
| Clear existing contiguous statement/session fields with indexed loops | 104 |
| Remove AP-writer X reloads and a redundant slot save | 37 |
| Replace opcode dispatch with shared mode patterns | 354 |
| Total | 530 |

Runtime service initialization already forced a refresh on each entry. The
new conditional omits the unreachable cached-pointer path, retaining header,
version, count, checksum, and resident-address checks. Standalone diagnostic
builds retain their existing cache behavior.

The state-clearing loops cover exactly the previously cleared fields. They
leave unrelated scratch bytes, fixup sites, and package `REL_LEN_HI` intact.
They change private X/N/Z scratch results and take more initialization cycles;
their callers do not consume those results. They add no RAM and move no
fields. AP writers retain X across `ASM_PACKAGE_WRITE_A`; the remaining
reloads follow helpers that actually change it.

Opcode selection previously occupied 759 bytes (431 instructions and 328
inline table bytes). It now occupies 405 bytes: a 73-byte decoder, two 83-byte
tables indexed by the existing vocabulary IDs, and 166 bytes for 20 shared
patterns. Register/directive slots remain invalid. Modes use explicit opcode
offsets; ordinary branches, implied instructions, BRK signatures, accumulator
aliases, STA immediate rejection, and all four bit families retain their
accepted/rejected behavior. The existing D=0 arithmetic assumption remains.
Lookup time depends on the selected pattern; this is not a cycle-identical
change.

Moving the code also moves the compact diagnostic strings. Their existing
low-byte pointer scheme now derives the second page from `MSG_TITLE+$0100`
instead of a particular message label. This costs no bytes and lets the
same 256-byte-span constraint remain valid after code-size changes.

## Host checks

The first-stage image passed the existing diagnostic/source-workflow suite
at `$BCE5`. The final candidate and original image pass these independent
linked-code checks:

- 65,536 mnemonic-ID/mode combinations and 1,024 arbitrary bit-number bytes;
- six exact statement/session memory-clear cases seeded with nonzero RAM;
- 105 service-init cases covering valid headers, stale warm pointers,
  signatures, versions, counts, checksums, and invalid resident addresses;
- 78 exact export/import records and six complete AP-v2 packages, including
  maximum row counts, nonsequential symbol slots, base subtraction borrows,
  PACK40 length boundaries, zero/page-crossing bodies, and destination guards.

The opcode oracle uses pinned py65 instruction definitions plus explicit WDC
and ASM syntax rules. Package expectations use independent Python FNV and
PACK40 calculations. In-memory mutations of opcode selection, state clearing,
initialization, and export-offset arithmetic are rejected. The source table
audit checks 217 legal opcode rows, 70 mnemonics, and all pattern bounds; its
negative fixtures reject wrong bases, shifted IDs, incorrect pattern counts,
and an illegal STA immediate row.

Focused reproduction:

```text
make -C SRC asm-size-check "HIMON_VISIBLE_STAMP=0915(2243)"
make -C SRC asm-test "HIMON_VISIBLE_STAMP=0915(2243)"
```

The complete `asm-test` suite passed with the same stamp, including the
nonflash core/runtime profiles, generated session reporter, existing source
workflows, optional CHECK diagnostics, and HIMON regressions. All 352 checked
UDATA-address, mnemonic-ID, and addressing-mode symbols match the baseline.
Generated routine documents and session-report sources were refreshed from
the new source and linked addresses. `git diff --check` passed.

`board-s19-check` also passed all nine canonical payload comparisons:
ASM `$3B83` bytes and HIMON `$2DEA` bytes. This is a host artifact check,
not a board operation. The dense ASM-only component is
`SRC/BUILD/s19/ryors-v1.2-asm-bank3-8-b.s19`, covering exactly `$8000-$BFFF`,
with S9 `$FFFF`, SHA-256
`C665DED45ED09BDF2B205793488A70023CD664EE123C36C287019C3E338959D8`.
The original component used incompatible S9 `$8000`. Installation exposed
the mismatch; the Makefile/generator and identity check are now corrected.
The check also rejects a checksummed fixture with the old S9. See the board
record for the failed first transfer, successful recovery, and successful
corrected 8-B installation. Older packaged release copies were not republished.

## Hardware gate

ASM-F2 `00.0915(2243)` replaced WDCMONV2 in Bank-3 sectors 8-B as requested.
Full-bank readback verifies exact ASM bytes and padding, unchanged HIMON
`00.0915(2233)` and STR8-N 1.34, and only the expected directory journal change.
The board passed all 217 instruction forms, nine error/rollback cases,
NEW clearing, direct/AP execution, SEAL/RELOCATE/PACKAGE/LOAD, eight exports
and three imports with exact package bytes, and BRK/step/resume checks.
Physical RESET, fresh ASM entry and assembly/run, and a byte-identical final
32 KB flash readback also passed. The feature queue is accepted.
See the [board qualification record](../LOGS/ASMF2_SIZE_2026-09-15.md)
and its raw serial transcript for identities and scope. Bank 0-2 carriers
were not requalified. Earlier hardware transcripts remain unchanged.
