# DOC FLASH

DOC FLASH is the short alert stream for documentation-shape changes, edicts,
canonical-home moves, deprecated ideas, and QCC/decision changes that are easy
to miss if you remember yesterday's binder.

This is not a full changelog. Use it when a reader should stop and adjust
their mental map:

```text
an edict changed
a QCC topic was added, split, promoted, or deprecated
the canonical home for an idea moved
a proof lane was named as a kludge or seed path
a remembered artifact name or doc path is now stale
```

Command-surface behavior still belongs in [HASH_FLASH.md](./HASH_FLASH.md).
Settled calls still belong in [DECISIONS.md](./DECISIONS.md). QCC pages keep
unsettled design thinking. DOC FLASH is the visible flare that says where the
reader should look next.

Entries use CBI doc form:

```text
YYYY
         MM
                DD
                   HH:MMZ programmer comment
                               continuation line
```

Use UTC ISO 8601 time without seconds. Sort newest first at every level.

Each alert should answer:

```text
scope:      which docs/source/artifacts changed
change:     what moved or was reclassified
effect:     what old assumption is stale now
action:     where to look or what to do next
```

## REDOC: STR8 Flash-Manager QCC Expanded

```text
2026
         05
                17
                   02:03Z WLP2 Expanded QCC_STR8 with the boring
                               flash-manager direction: Bank 0 WDC HOLD,
                               STR8-owned HIMON/STR8 updates, identity
                               display, and future classified chunk moves.
```

scope: `QCC_STR8.md`.

change: STR8's future role is now recorded as flash manager/housekeeper rather
than only backup/restore guard. The notes also capture full-bank WDCMONv2
preservation and the compact `RYORS 0.0517 #hash B0 HOLD` identity line.

effect: Do not treat HIMON `L F` as the eventual owner of protected monitor or
STR8 updates. STR8 is the proposed authority for dangerous flash writes and any
future flash compaction.

action: Use [QCC_STR8.md](./QCC_STR8.md) for this unsettled direction until the
parts that prove out are promoted into decisions or implementation docs.

## REDOC: Hardware Test Log Added

```text
2026
         05
                16
                   02:59Z WLP2 Added HARDWARE_TEST_LOG as the home for
                               board transcript validations and bench
                               findings.
```

scope: `HARDWARE_TEST_LOG.md`, `INDEX.md`, `TOC.md`, `MAP.md`, `XREF.md`.

change: Hardware proof transcripts now have a single guide home instead of
living only inside design notes, how-to guides, or external terminal logs.

effect: Use the hardware test log for "what actually passed on the board" and
the individual proof guides for how to run or interpret each proof.

action: Add future bench passes to [HARDWARE_TEST_LOG.md](./HARDWARE_TEST_LOG.md).

## REDOC: HIMON Bit-Pattern ASM Decode Retired

```text
2026
         05
                16
                   01:41Z WLP2 Retired the old bit-code assembler/
                               disassembler direction for W65C02S. HIMON
                               keeps table-driven opcode decode as the V0
                               correctness model.
```

scope: `DECISIONS.md`, HIMON assembler/disassembler implementation.

change: `aaa bbb cc` remains a useful way to understand parts of the opcode
map, but it is no longer treated as the implementation plan for HIMON ASM/DIS.

effect: Do not carry the OSI-era bit-coded decoder sketch as current debt.
Future compression is allowed only after it proves table-equivalent behavior.

action: Use [DECISIONS.md](./DECISIONS.md) for the settled rule.

## REDOC: Catalog-Linking Bootstrap QCC Added

```text
2026
         05
                15
                   23:56Z WLP2 Added QCC notes that generation-wins needs
                               more than the current kind byte, and that
                               FN(V|$80) is a readable proof marker rather
                               than the compact future catalog shape.
                   22:13Z WLP2 Added duplicate ROM/flash record policy
                               to QCC_FLASH: current first-match duplicates
                               are shadowing; future candidate selection
                               enables staging, rollback, and condense.
                   22:09Z WLP2 Renamed legacy calc-flash to
                               calc-9a00-fnv-proof so its name says what
                               it proves. rom-append-calc remains the active
                               payload that must fit below $C000.
                   22:08Z WLP2 Classified calc-flash as the legacy CALC
                               proof and rom-append-calc as the active
                               ROM-append proof. Do not load both: they
                               publish the same CALC FNV command record.
                   22:05Z WLP2 Corrected HIMON_MAP scanner text to match
                               source: command FNV scan starts at $8000,
                               and the table now escapes FN(V|$80).
                   21:55Z WLP2 Documented the fig-Forth notice stance:
                               Forth ideas are not copied source; local
                               FIG-Forth source preserves its required notice.
                   21:51Z WLP2 Added the 30-40 service-discovery
                               explanation between the 17 and 62 models.
                   21:49Z WLP2 Published the 12/17/62 catalog-linking
                               explanations. The 62 shop-index analogy is
                               now marked as the preferred public model.
                   21:38Z WLP2 QCC_CATALOG_LINKING now names S(earch)
                               plus HREC join as the preferred first
                               bootstrap target; LIFE is later/heavier.
                   21:33Z WLP2 Added QCC_CATALOG_LINKING as the home for
                               the catalog/ASM chicken-and-egg question.
```

scope: `QCC_CATALOG_LINKING.md`, `LIFE_RCAT_MEMBER.md`, `CATALOG.md`,
`HASHED_ASM.md`, `QCC_ASM.md`

change: Catalog linking now has its own QCC home. The current `LIFE-2000`
load path is explicitly named as a useful static-link kludge and proof lane,
not the final catalog contract.

effect: Do not read `life-2000-load.bin` as "the catalog member." It is a
seed package that proves the body runs while still carrying private support
payload from static linking.

action: Use [QCC_CATALOG_LINKING.md](./QCC_CATALOG_LINKING.md) for the general
bootstrap rule and [LIFE_RCAT_MEMBER.md](./LIFE_RCAT_MEMBER.md) for the
LIFE-specific migration notes.

## REDOC: LIFE Load Artifact Names Now Carry Address

```text
2026
         05
                15
                   21:20Z WLP2 LIFE build output now names the load address:
                               life-2000.s19 and life-2000-load.bin.
```

scope: `SRC/Makefile`, `RTFM-himon.md`, `show_make_help.ps1`,
`SRC/BUILD/s19`, `SRC/BUILD/bin`

change: `make -C SRC life` now emits:

```text
SRC/BUILD/s19/life-2000.s19
SRC/BUILD/bin/life-2000-load.bin
```

effect: `SRC/BUILD/s19/life.s19` is a stale remembered artifact name. New
references should carry the load address.

action: Use `life-2000.s19` for HIMON S-record loading and
`life-2000-load.bin` when a raw loadable binary is needed.
