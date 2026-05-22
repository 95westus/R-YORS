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

## REDOC: Self-Modifying Code Parked As QCC Boundary

```text
2026
         05
                22
                   05:04Z WLP2 Added the ASM-side self-modifying-code
                               boundary note.
```

scope: `QCC/ASM.md`, `QCC/INDEX.md`, and generated HTML.

change: The ASM QCC now records that self-modifying code is not a general
R-YORS style goal. The acceptable future shape is explicit loader/fixup work,
generated RAM bodies, or a very narrow RAM-worker size-pressure exception.

effect: Do not treat RAM execution, hash-based joining, or relocation fixups as
permission to hide normal control flow in patched instruction bytes.

action: Prefer zero-page indirection, tables, helper routines, and visible
fixup records. If code bytes must change, make that mutation part of a loader,
fixup table, or generated-RAM-body story.

## REDOC: STR8 Worker Packed Down From FFEF

```text
2026
         05
                22
                   04:54Z WLP2 Coalesced the STR8 top-sector slack by
                               packing the RAM worker down from $FFEF.
```

scope: `SRC/STR8/str8.asm`, `SRC/STR8/str8-worker.asm`,
`SRC/tools/build_himon_str8_rom_bin.ps1`, STR8/operator/memory guides, and
generated HTML.

change: The stored STR8 RAM worker moved from `$FC00-$FED1` to `$FD1E-$FFEF`.
STR8 now copies the exact worker length into `$0200-$04D1` instead of assuming
a page-aligned four-page source. The ROM builder recomputes the packed worker
address from the worker size and validates STR8's copy constants.

effect: The old two-hole top-sector picture is stale. STR8 code/data grows
upward from `$F000`, the worker grows downward from `$FFEF`, and the current
free top-sector hole is one contiguous `$FA83-$FD1D` range.

action: Use the current layout in `TECHNICAL_GUIDE.md`, `MEMORY_MAP.md`,
`OPERATORS_GUIDE.md`, and `STR8.md`.

## REDOC: Book Spine Names The Change-Mind Loop

```text
2026
         05
                22
                   04:44Z WLP2 Updated the book spine with the
                               want/need/answer/question/change/do/keep/no-more
                               motion of the project.
```

scope: `STORY/BOOK.md` and generated HTML.

change: The story spine now says chapters should show what the system wanted,
what the hardware or operator needed, what answer was tried, what questions
remained, what changed, what was proved, what survived, and what path was
retired.

effect: The book should not read as if every current answer was obvious from
the start. R-YORS changes its mind when the board, ROM size, flash physics, or
operator surface proves an older answer too large, unsafe, or stale.

action: Use [BOOK.md](STORY/BOOK.md) for the narrative structure and keep
settled technical calls in [DECISIONS.md](./DECISIONS.md).

## REDOC: ASM VM Question Parked In QCC

```text
2026
         05
                22
                   04:40Z WLP2 Captured the hash-first ASM and storage-bank
                               metadata question as QCC, explicitly parking
                               VM/bytecode ideas as later work.
```

scope: `QCC_ASM.md`, `QCC_CATALOG_LINKING.md`, and generated HTML.

change: `LABEL: MNEMONIC OPERAND` is now documented as a hash-first native
assembler path: hash labels, dispatch hashed mnemonics to W65C02S emitters or
directives, and record operand fixups. Storage banks are framed around
`provides`, `depends`, `fixups`, payload length, link/load address, and
checksum.

effect: The old mental shortcut "hashed ASM plus address traps means VM" is
too far ahead. Native emitted W65C02S cannot be trapped after the fact; trapping
requires deliberate watched forms such as HIMON service calls, BRK tokens, or
bytecode.

action: Keep VM talk in QCC. The near-term proof remains seed records,
explicit dependencies, fixups, and native load/join/run behavior.

## REDOC: Hash Policy Settled On FNV32 Public Identity

```text
2026
         05
                21
                   23:00Z WLP2 Settled the hash split: FNV-1a32 is public
                               name identity; CRC16 is compact local/scoped
                               hash/check; CRC32 is optional integrity/check,
                               not ordinary lookup identity.
```

scope: `DECISIONS.md`, `README.md`, `TECHNICAL_GUIDE.md`, `REF.md`,
`GLOSSARY.md`, `HASH.md`, `HASH_MAP.md`, `QCC_HASH.md`, `HASHED_ASM.md`,
`SYMBOL_XREF.md`, `CATALOG.md`, `HIMON_MAP.md`, `STR8.md`, and generated HTML.

change: The earlier "CRC16 replaces FNV32 as the intended runtime/catalog hash"
wording is retired. Public/exported/cross-bank names keep FNV32. CRC16 remains
valuable in bounded local record contexts. CRC32 belongs to integrity checking.

effect: Docs should no longer describe FNV-1a32 as mere transition debt or
describe CRC16 as the universal future catalog identity.

## REDOC: Hash Trash And K-Bit Contract

```text
2026
         05
                20
                   03:49Z WLP2 Added HASH_TRASH.md as the parking lot for
                               tempting hash/catalog ideas and refreshed the
                               current HIMON K-bit contract across reference
                               docs.
```

scope: `DOC/GUIDES/DECISIONS.md`, `DOC/GUIDES/HASH_FLASH.md`,
`DOC/GUIDES/REF.md`, `DOC/GUIDES/GLOSSARY.md`,
`DOC/GUIDES/HASH/HASH.md`, `DOC/GUIDES/HASH/HASH_MAP.md`,
`DOC/GUIDES/HASH/HASH_TRASH.md`, and
`DOC/GUIDES/QCC/CATALOG_LINKING.md`.

change: Current HIMON FNV `kind` is now documented as bit 0
executable/callable and bit 1 confirm-before-execute. K bits 2 and 3 are
reserved. The PIN/BIO/SYS selection model is documented as recursive
catalog-linking through explicit imports.

effect: The older assumption that K=$00 is the executable command shape and
K=$10 is the active pointer-record shape is stale for current HIMON. The idea
of using spare K bits as selectors or permissions is parked, not adopted.

action: Use [DECISIONS.md](./DECISIONS.md) for the current K contract,
[HASH_FLASH.md](./HASH_FLASH.md) for the behavior alert, and
[HASH_TRASH.md](HASH/HASH_TRASH.md) for parked hash/catalog ideas.

## REDOC: Operator And Technical Guides Are Canonical

```text
2026
         05
                19
                   00:40Z WLP2 Moved RTFM compatibility stubs under
                               DOC/GUIDES/META/COMPAT so they are reference
                               plumbing instead of a visible guide shelf.
                   00:30Z WLP2 Moved secondary guide material into shelf
                               folders under DOC/GUIDES so the top level holds
                               only entry points and stable cross-cutting refs.
                   00:11Z WLP2 Consolidated the scattered RTFM/operator
                               material into one operator guide and added one
                               technical guide for the current R-YORS/STR8/HIMON
                               architecture.
```

scope: `README.md`, `DOC/INDEX.md`, `DOC/GUIDES/INDEX.md`,
`DOC/GUIDES/TOC.md`, `DOC/GUIDES/MAP.md`, `DOC/GUIDES/META/XREF.md`,
`DOC/GUIDES/META/BIB.md`, `DOC/GUIDES/DECISIONS.md`,
`DOC/GUIDES/OPERATORS_GUIDE.md`, `DOC/GUIDES/TECHNICAL_GUIDE.md`, the
`STR8/`, `HIMON/`, `QCC/`, `STORY/`, `MEMORY/`, `CATALOG/`, `ASM/`, `HASH/`,
`LOGS/`, `META/`, and `PLANNING/` shelves, plus the `META/COMPAT/RTFM-*.md`
compatibility entry points.

change: `OPERATORS_GUIDE.md` is now the canonical board-facing guide.
`TECHNICAL_GUIDE.md` is now the canonical architecture guide. The old
`RTFM-R-YORS.md`, `RTFM-str8.md`, and `RTFM-himon.md` files now redirect to the
operator guide instead of duplicating procedures, and they are intentionally
kept out of the main README/index/TOC path under `META/COMPAT/`. Secondary
guides now live one level down by domain instead of crowding the top-level
`DOC/GUIDES` directory.

effect: The old assumption that a reader must hop between three RTFM files,
README status blocks, and design notes to operate the board is stale. The story
lane is explicitly separate from the main docs.

action: Start with [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) for board use and
[TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md) for architecture. Use
[BOOK.md](STORY/BOOK.md), [HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md),
and [../IDEAS.md](../IDEAS.md) for narrative material.

## REDOC: STR8-N Region Packing Direction

```text
2026
         05
                19
                   00:53Z WLP2 Captured the future STR8-N range-packing
                               direction and the near-term 5x12K backup arena
                               sketch for banks 0 and 1.
```

scope: `DECISIONS.md`, `TECHNICAL_GUIDE.md`, `STR8/STR8.md`,
`MEMORY/MEMORY_MAP.md`, `PLANNING/FUTURE.md`, and `QCC/STR8.md`.

change: STR8-N/STRAIGHTEN may become a range-aware boot recovery and flash
manager that packs named regions elsewhere, remembers where they came from,
and later restores them by metadata. Optional compression is way-future and
must be explicit and verifiable. The near-term planning sketch uses banks 0
and 1 as a 64K backup arena: five 12K backup slots plus one 4K metadata sector
for names, labels, origins, checks, and roles. Bank 2 becomes SYS/USR space.
Bank 3 remains the default boot bank with `$8000-$BFFF` user-available.

effect: The current whole-32K STR8 V0 backup/restore contract is unchanged,
but future STR8 planning should stop assuming that every useful backup source
must be a complete bank image.

action: Use [QCC/STR8.md](QCC/STR8.md) for open design concerns and
[STR8/STR8.md](STR8/STR8.md) plus [MEMORY/MEMORY_MAP.md](MEMORY/MEMORY_MAP.md)
for the current sketch before implementing any range-aware writer.

## REDOC: STR8 Milestone And CRC16 Hash Pivot

```text
2026
         05
                18
                   15:10Z WLP2 Promoted the STR8 three-image milestone across
                               the reader-facing manuals and reclassified
                               FNV-1a as transition history, with tableless
                               CRC16 as the intended compact hash.
```

scope: `README.md`, `DOC/INDEX.md`, and the reader-facing guide lane:
`INDEX.md`, `TOC.md`, `MAP.md`, `BOOK.md`, `BRINGUP.md`, `RTFM-*.md`,
`STR8.md`, `DECISIONS.md`, `GLOSSARY.md`, `REF.md`, `CATALOG.md`,
`HASH.md`, `HASH_MAP.md`, `HASHED_ASM.md`, `HIMON_MAP.md`, `QCC_ASM.md`,
`QCC_HASH.md`, `SYMBOL_XREF.md`, and `XREF.md`.

change: STR8 is now presented as hardware-proven rotating three bootable
images: HIMON, OSI BASIC, and fig-FORTH. The hash docs now distinguish
current FNV-era implementation records from the intended compact tableless
CRC16 catalog-hash direction.

effect: The old assumption that STR8 is only a sketch, and that FNV-1a is the
settled universal runtime spine, is stale. FNV-1a remains useful history and
current-ROM transition debt until the CRC16 record shape is written through.

action: Start with [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) and
[TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md) for the proven image manager
behavior. Use [DECISIONS.md](./DECISIONS.md), [HASH.md](HASH/HASH.md), and
[HASH_MAP.md](HASH/HASH_MAP.md) for the hash-policy pivot.

## PROOF: STR8 UPDATE HIMON Passed On Hardware

```text
2026
         05
                18
                   02:35Z WLP2 Logged the STR8 UPDATE HIMON U1->U2 hardware
                               proof and narrowed TODO/work-process wording to
                               the remaining acceptance gaps.
```

scope: `HARDWARE_TEST_LOG.md`, `STR8_WORK_PROCESS.md`, `TODO.md`.

change: The hardware log now records the successful STR8 `U` path: Bank 3
booted HIMON U1, `B` copied U1 into Bank 2, `U` received compact
`$C000-$EFFF` S19 and programmed HIMON U2, STR8 stayed reachable, and
high-flash Bank 2 -> Bank 3 restore brought HIMON U1 back.

effect: The first fixed-gate `UPDATE HIMON` proof is no longer theoretical.
The remaining STR8 V0 proof gaps are Bank 0 enrollment, lower-sector restore
over non-erased bytes, and deliberate high-flash failure behavior with a
sacrificial image.

action: Use [HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md) for the transcript
and [STR8_WORK_PROCESS.md](STR8/STR8_WORK_PROCESS.md) for the remaining bench
rail.

## REDOC: STR8 Work Process Added

```text
2026
         05
                18
                   00:33Z WLP2 Added the STR8 work-process rail, refreshed
                               bringup/TODO wording around the current ROM
                               proof, and simplified the future update
                               command shape with fixed S19 gates.
```

scope: `STR8_WORK_PROCESS.md`, `INDEX.md`, `TOC.md`, `MAP.md`, `XREF.md`,
`BIB.md`, `BRINGUP.md`, `TODO.md`, `STR8_FLASH_UPDATE_PROPOSAL.md`,
`STR8.md`, `QCC_STR8.md`.

change: STR8 now has a process guide that names the next step as a V0
acceptance/regression pass before new update commands or self-update. STR8's
recovery path is treated as already proven; the pass records that the current
build still behaves like the known-good recovery image. The update proposal
now treats `U T`, `U H`, and `U S` as design shorthand only; the compact
implemented HIMON path is `U`, equivalent to fixed `UPDATE HIMON`. The first
S19 gate is fixed: `U` accepts only `$C000-$EFFF`, while future `UPDATE STR8`
accepts only `$F000-$FFFF` after stronger confirmation. IVI is now the combined
image's stable vector-indirection mechanism, IVY is only its pronunciation, and
LEAF is the future friendly front door built on IVI. Payload use of future LEAF
patch routines is optional and has no flash authority. The bringup guide points
to the current
`$F000` resident shell, `$FD1E-$FFEF` worker
source, `$0200-$04D1` RAM tray, `$4000-$4FFF` copy buffer, and `$4000-$6FFF`
HIMON update staging area.

effect: Do not expose `U T`, `U H`, or `U S` as operator commands. Use `U` only
as the fixed HIMON S19 gate, and keep later generic/raw-range work behind a
guided update surface. The existing `? B E M U 0 1 2 G R` rescue/update surface
still needs a clean hardware transcript, especially for destructive `B`, `E`,
`U`, lower-sector restore, and high-flash failure behavior.

action: Use [STR8_WORK_PROCESS.md](STR8/STR8_WORK_PROCESS.md) before editing STR8
source or planning the next bench pass.

## REDOC: Product Boundaries Named

```text
2026
         05
                17
                   18:49Z WLP2 Added a product-boundary guide for R-YORS,
                               STR8, IVI/LEAF, HIMON, and peer payloads.
```

scope: `PRODUCT_BOUNDARIES.md`, `INDEX.md`, `TOC.md`, `MAP.md`, `BOOK.md`,
`GLOSSARY.md`.

change: STR8 is now documented as the board management product inside the
current repo. IVI is the interrupt-vector mechanism, and LEAF is the newer
front-door product name built on it. HIMON is the default monitor payload, while
WDCMONv2, BETTERMON, apps, tools, BASIC, and FORTH can be peer payload targets.

effect: Do not treat STR8 as only a HIMON helper, and do not treat HIMON as the
only possible thing STR8 can install or boot. The repo stays together for now;
the boundary is conceptual and documented before any source split.

action: Start with [PRODUCT_BOUNDARIES.md](STR8/PRODUCT_BOUNDARIES.md), then use
[STR8.md](STR8/STR8.md) for the board-management contract and
[QCC_STR8.md](QCC/STR8.md) for open STR8, IVI, and LEAF questions.

## REDOC: Onboard ASM Monitor Candidates Added

```text
2026
         05
                16
                   22:46Z WLP2 Added future wording for onboard ASM
                               producing monitor candidates instead of S19,
                               with a tiny winner-record commit.
```

scope: `HASHED_ASM.md`, `QCC_STR8.md`.

change: Future onboard update flow now distinguishes S19 as host transport from
native onboard products: RAM candidates, staged sector images, `ASM_STAGE`,
`ASM_FIX`, `CODE`, `RCAT/RREC`, and later `BOOT/XMON` candidate or winner
records. The atomic part is the final winner-record commit after verification,
not the whole monitor write.

effect: Do not assume onboard ASM must generate S19 to update the board. The
old monitor should remain the winner until a sealed, verified candidate is
published by a small commit record.

action: Use [HASHED_ASM.md](ASM/HASHED_ASM.md) for onboard ASM product shape and
[QCC_STR8.md](QCC/STR8.md) for future STR8 candidate/winner policy.

## REDOC: HIMON/STR8 Update Means Sector Rebuild

```text
2026
         05
                16
                   22:42Z WLP2 Clarified that V0 HIMON/STR8 replacement
                               means RAM-staged 4K sector rebuild, with S19
                               as transport only.
```

scope: `STR8.md`, `STR8_DECISION_REFERENCE.md`,
`STR8_FLASH_UPDATE_PROPOSAL.md`, `QCC_STR8.md`.

change: The monitor update path now says V0 should stage a full 4K sector in
RAM, merge incoming S19 bytes if S19 is used, confirm erase when the staged
sector differs, erase the destination sector, write the full staged sector, and
verify the whole sector. Direct 1->0 programming is demoted to later
optimization or deliberate one-way flags.

effect: Do not describe HIMON or STR8 replacement as a casual flash write,
byte patch, or live S19 stream into monitor flash. It is a sector rebuild.

action: Use the STR8 update notes before designing `UPDATE HIMON`,
`UPDATE STR8`, or any RAM updater that touches `$C000-$FFFF`.

## REDOC: STR8 Wear, Scratch, And Partition Notes Added

```text
2026
         05
                16
                   22:28Z WLP2 Added QCC and reference notes for WMAP wear
                               records, TMP/STAGE scratch sectors, ASM RAM
                               pressure, and a partitioned-bank thought
                               experiment.
```

scope: `QCC_STR8.md`, `STR8.md`, `STR8_DECISION_REFERENCE.md`,
`HASHED_ASM.md`.

change: Wear counts are now framed as append-only hash-shaped `WMAP` metadata,
not stolen bytes in image sectors or STR8 slack. Scratch flash is a future
lease selected from reclaimable sectors, with 4K erase transactions still
preserving or discarding neighboring policy windows explicitly. ASM now records
RAM-first work products and explicit flash-stage behavior under RAM pressure.
The partitioned-bank sketch is captured as a QCC thought experiment, not as a
change to the current whole 32K image rotation contract.

effect: Do not assume a hidden filesystem, silent ASM spill to flash, or
an approved partitioned-bank design. The current STR8 recovery contract still
uses whole 32K images unless a later decision explicitly promotes another map.

action: Use [QCC_STR8.md](QCC/STR8.md) for the unsettled STR8/STRAIGHTEN
policy, [STR8.md](STR8/STR8.md) for the current recovery narrative, and
[HASHED_ASM.md](ASM/HASHED_ASM.md) for ASM staging rules.

## REDOC: STR8 Flash-Manager QCC Expanded

```text
2026
         05
                17
                   02:03Z WLP2 Expanded QCC_STR8 with the boring
                               flash-manager direction: Bank 0 WDC HOLD,
                               STR8-owned HIMON/STR8 updates, identity
                               display, WDC RAM bridge, future yield
                               targets, STR8-as-product, and classified
                               chunk moves.
```

scope: `QCC_STR8.md`.

change: STR8's future role is now recorded as flash manager/housekeeper rather
than only backup/restore guard. The notes also capture full-bank WDCMONv2
preservation, a WDCMONv2-loaded RAM bridge, future boot targets, and the
STR8-as-product boundary, plus the compact `RYORS 0.0517 #hash B0 HOLD`
identity line.

effect: Do not treat HIMON `L F` as the eventual owner of protected monitor or
STR8 updates. STR8 is the proposed authority for dangerous flash writes and any
future flash compaction.

action: Use [QCC_STR8.md](QCC/STR8.md) for this unsettled direction until the
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

action: Add future bench passes to [HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md).

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

action: Use [QCC_CATALOG_LINKING.md](QCC/CATALOG_LINKING.md) for the general
bootstrap rule and [LIFE_RCAT_MEMBER.md](CATALOG/LIFE_RCAT_MEMBER.md) for the
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
