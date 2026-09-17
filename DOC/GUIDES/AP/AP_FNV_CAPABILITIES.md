# AP/FNV: current capabilities, limits, and future work

Status as of 2026-09-16. Current installed pair: HIMON `00.0916(1949)` and
AM03 at B2:8, running with STR8-N 1.35 and live policy `$FFF2=$A6`.
Installed ASM-F2 remains `00.0915(2324)`. Historical AM02 and standalone
proof transcripts describe their own images, not additional current features.

## What the recent work enables

We can now type the name of a suitable external AP command at HIMON and have
the system discover, validate, load, link, and enter it automatically. We do
not need a resident launcher for every such application or need to know its
carrier address. This is bounded command discovery, not a general dynamic
linker, operating system, or filesystem.

The command path is:

```text
HIMON command name
  -> resident executable FNV record found? Run the resident command.
  -> otherwise: policy-enabled bootstrap of compatible AM03
  -> search RAM $3000-$3FFF plus eligible bank AP carriers
  -> require exactly one validated matching provider
  -> repeat discovery and revalidate the selected provider
  -> load/link BODY at $2000, retire discovery state, enter child
  -> child RTS returns through the caller's return edge
```

FNV provides a compact identity lookup; the external path also compares the
exact canonical name. A matching hash alone is not permission to execute.

| Capability | What works now | Evidence boundary |
| --- | --- | --- |
| Resident-first command resolution | Existing resident executable records retain priority; external providers do not replace them | Linked host tests; earlier banked board qualification |
| Policy-limited flash discovery | Requested banks intersect the persistent allowed-bank mask; role sectors are excluded | Exhaustive 65,536 policy/request tests, linked traversal, earlier banked board proof |
| RAM AP discovery | A complete valid AP v2 provider in existing `$3000-$3FFF` can supply a command without installing that provider in flash | Current AM03 RAMTEST execution-marker proof |
| Combined uniqueness | RAM and eligible flash matches are counted together; ambiguity is rejected instead of choosing the first match | Current linked host cases; earlier standalone/banked board cases apply to their tested images |
| Validated handoff | Revalidate, relocate/load/link, clear transition state and enter the chosen child | Current AM03 host cases and focused board checks |
| Import linking during load | Applications such as BANKDUMP use the existing AP import/link service | Current board BANKDUMP menu, map and return |
| Provider preservation | RAM provider bytes remain unchanged; discovery itself performs no flash writes | Current marker/provider checks and exact four-bank readback |
| Reset persistence | Installed manager and flash carriers remain available after physical RESET | Current post-reset checks and all 32 sectors matching expected bytes |

### Concrete examples and prerequisites

- Bare `BANKDUMP` enters the installed application's real menu; `M` exercises
  its map and returns with `BANKDUMP MAP OK; B3 RESTORED`.
- Bare `APTEST` discovers the B2:9 carrier and loads its exact short BODY.
  The separate RAMTEST marker is the stronger explicit child-execution proof.
- `RAMTEST` is a test provider, not a permanently installed command. It works
  only while its complete validated envelope is present in the RAM window.
  Physical reset does not make volatile RAM providers persistent.
- Existing explicit AP inspection/load/run, carrier inventory and installation
  paths remain distinct operations. Automatic name lookup does not install
  anything or silently authorize a flash write.

The current policy `$A6` allows B1/B2 and excludes B0. It must allow the
**manager's bank**, not just the application's bank: B1-only `$A2` cannot
bootstrap the installed B2:8 manager. `$FF`, `$A0`, and invalid signatures
disable the automatic fallback; they do not provide RAM-only automatic lookup.
The canonical STR8 image defaults to `$FF`, and a normal top update can restore
that default even while preserving directory records.

Use the [policy/configuration reference](FNV_POLICY_CONFIGURATION.md) before
changing any byte, and the [RAM ownership contract](HIMON_AP_SCOPED_RAM_CONTRACT.md)
before preparing a provider. Matching HIMON and AM03 are required: AM03 uses
`$6C00`, whereas the older AM02 overlay used `$7000`.

Successful AM03 automatic handoff is silent. Test actual application behavior,
memory effects and return, not an expected `GO` or `AP LOAD` banner.

## What we cannot do today

### Not implemented or not a supported interface

- Search arbitrary RAM, I/O, SPI SRAM, or every same-named routine in a foreign
  ROM. The current automatic provider formats are validated AP exports in the
  fixed RAM window and selected one-sector flash carriers. RAM HREC inspection
  is a separate metadata-only proof, not integrated arbitrary HREC execution.
- Treat an opaque guest bank as AP Store media or let a request override bank
  policy. Policy is also not a security sandbox: explicit access has separate
  rules, and a loaded child is ordinary machine code.
- Pick the newest/best of duplicate providers, solve dependency versions,
  recursively locate and install missing imported modules, or hot-replace
  resident routines. Current uniqueness rejects ambiguity; existing import
  linking is not a provider registry or dependency manager.
- Use a supported nested named-AP parent/child ABI, preserve an arbitrary
  parent's workspace, or return to a persistent AM03 menu. Discovery overlays
  shared RAM and invalidates ASM continuation before manager staging. A child
  returning with RTS does not make nested calls safe.
- Select an arbitrary automatic load address or exceed the current handoff
  contract: destination is `$2000`, BODY length is 1 through `$1000`, and each
  flash carrier's entire AP envelope must fit one 4 KiB sector. Other explicit
  load modes have separate contracts; they do not enlarge this one.
- Use `MODULE` syntax for non-runnable libraries, a general allocator, or
  automatic multi-window RAM discovery. SPI SRAM is not installed, and no SPI
  allocation is implied by the unassigned flash WORK byte.
- Treat AP carrier discovery as the consolidated AP Store product. AP Store's
  earlier transient tools and media proofs do not provide a current persistent
  menu, compaction, garbage collection, wear leveling or cross-bank objects.

### Not yet proven, rather than necessarily impossible

- Current AM03 board proof is focused: bank APTEST loading, RAM child marker,
  provider/state checks, BANKDUMP linking/menu/map/return, physical reset and
  full-flash isolation. It is not a repeat of every host rejection case on the
  final board image, nor qualification of every installed application.
- NMI safety while accessing a foreign bank remains a separate hardware gate.
  Reset after a completed test does not prove interruption is safe mid-operation.
- Read-only discovery acceptance does not qualify interrupted flash mutations,
  loss-of-power recovery, or STR8 1.35 factory migration. Those have separate
  owners and acceptance requirements.

## What we should be able to do next

These are proposed directions, not available commands or promises of completion.
The [feature queue](../PLANNING/TODO.md) owns scheduling and completion gates.

| Future capability | User benefit | Prerequisites before claiming it works |
| --- | --- | --- |
| Broader final-image board qualification | Confidence in malformed/duplicate refusal and more real applications on the installed AM03 pair | Freeze exact binaries; extend board matrix; preserve transcripts and complete readbacks; separately test interruption behavior |
| Deliberate additional RAM/HREC provider support | Discover more kinds of bounded providers without resident launchers | Freeze format-specific identity/entry rules, lifetime and memory map; integrate only accepted formats; prove host and board behavior |
| Stable parent/child AP call contract | Applications can invoke other applications and resume safely | Specify saved context, scratch ownership, non-overlap, errors, return, bank restoration and reset semantics |
| Consolidated persistent AP Store manager | One operator interface for inventory/install/delete and return after an application | Freeze overlay/shared-core ownership, reload/reinitialize after child return, mutation confirmations and recovery; retain V1 compatibility |
| Generation-aware provider registry | Test a new provider before activation; deliberately activate, retire or roll back versions | Freeze a host oracle for typed identity, global generation, inactive installation, exact-generation tests, commit-last activation, equal-generation ambiguity and corrupt-newest refusal |
| Registry-backed imports and live routine replacement | Reusable modules and controlled upgrades | Qualify command-provider registry first; then import binding; live slots additionally need quiescence and lifetime contracts |
| Non-runnable library packages | Publish typed exports without inventing an executable command | Define package identity and lifecycle for no-ENTRY bodies; add assembler/linker syntax and acceptance tests |
| SPI-backed workspace or expanded allocation | More working memory without consuming flash sectors | Confirm actual hardware installation; define driver, map, allocation and recovery; no assumed SPI support today |
| Managed compaction and wear policy | Recover stale space and sustain repeated updates | Define atomic recovery and media ownership; validate destructive operations and power/interruption cases independently |

The registry direction is recorded in the queue as a future bridge to the
sibling R-YORS-II proposal. Its generation semantics are not part of AM03.
Command providers come before registry-backed imports; live routine replacement
and physical compaction are later, separate stages.

Size remains a design constraint: current AM03 has 79 bytes free in its runtime
tray and 33 bytes left in its carrier; the matching resident HIMON integration
has very little ROM margin. New features need size measurements and may require
factoring or a new layout, not simply more code in the existing overlay.

## Agreed execution direction

The operator selected this sequence after reviewing the current AP/FNV work:

1. **Load and link dependencies into RAM first.** Discover an application's
   dependencies stored in eligible B0-B2 carriers, allocate non-overlapping
   RAM for their bodies, relocate them and bind imports to their RAM exports
   or existing Bank-3 services. Execute with Bank 3 selected. Storage banks
   need provider code and metadata, not resident bank-switching support code.
   This extends today's single-AP load plus Bank-3 import linking; it is not
   implemented yet. Before implementation, freeze module identity, dependency
   closure/cycle handling, ambiguity rules, RAM allocation/lifetime, shared
   dependencies and failure cleanup, then qualify host and board behavior.
2. **Possibly add RAM call gates later.** For providers that need to execute
   in banked ROM, a shared-RAM gate could select the target bank, call it and
   restore the caller's bank before returning. No replicated support code in
   B0-B2 is intended, but participating routines must follow the call-gate ABI.
   This is an optional enhancement, not a prerequisite for step 1. Freeze
   nested-call state, registers/results, return edges, interrupt/NMI behavior
   and recovery before implementation or hardware acceptance.

This execution strategy does not itself approve generation-aware activation,
hot replacement or persistent parent/child menus; those retain their separate
contracts and gates. It records a future goal, not authorization to implement
or flash either mechanism now.

## Evidence and maintenance

- [Current AM03 integration and sizes](AM03_RESIDENT_INTEGRATION_2026-09-16.md)
- [Corrected board verdict and physical-reset acceptance](../LOGS/AM03_BOARD_2026-09-16/HANDOFF_CORRECTION.md)
- [Earlier banked AP qualification](../LOGS/SCOPED_QUALIFICATION_2026-09-16.md)
- [Standalone handoff proof](RAM_AP_HANDOFF_2026-09-16.md)
- [Separate RAM HREC proof](RAM_HREC_PROOF_2026-09-16.md)
- [Test plan](../ASM/TEST_PLAN.md)

Promote a future item only when implementation, measured size, host tests,
documentation and required board proof agree. Preserve older transcripts and
label their scope; do not relabel old-image proof as a new-image hardware run.
