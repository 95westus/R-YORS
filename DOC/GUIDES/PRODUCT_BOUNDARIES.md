# R-YORS Product Boundaries

This page names the product boundary inside the current R-YORS repo. It does
not split the source tree, create a branch, or fork the project. It gives future
work a clean place to stand.

## Summary

```text
PROJECT / SYSTEM:      R-YORS
BOARD MANAGEMENT:      STR8
INTERRUPT MECHANISM:   IVI, pronounced IVY
INTERRUPT FRONT DOOR:  LEAF
DEFAULT PAYLOAD:       HIMON
OTHER PAYLOADS:        BETTERMON, WDCMONv2 image, BASIC/FORTH, apps, tools
```

HIMON is the default bundled monitor payload. From STR8's point of view, it is
one bootable target, not the reason STR8 exists.

## Ownership Table

| Product lane | Owns | Must not own |
| --- | --- | --- |
| R-YORS | Whole project direction, vocabulary, book, hash/catalog/runtime arc | Every product detail as one undifferentiated blob |
| STR8 | Board management: boot, map, backup, restore, install, verify, recovery prompts | Rich monitor behavior, assembler UI, normal user interrupt meanings |
| IVI | Interrupt Vector Indirection: stable stubs and patchable interrupt/trap targets | Product story, recovery policy, or permanent NMI/IRQ/BRK semantics |
| LEAF | Latched Entry Address Frontdoor: the product-shaped front door built on IVI | Flash authority or payload interrupt meanings after handoff |
| HIMON | Default monitor payload: commands, debug, load, inspect, hash/catalog workbench | Board survival, backup rotation, protected top-sector mutation |
| Payload target | Its own runtime, entry contract, RAM use, interrupt meanings after handoff | STR8 recovery policy or hardware vector reflashing assumptions |
| THE | Future hash/catalog environment and resolver policy | Board boot safety or flash transaction authority |

## Repo Boundary

Keep STR8 in this repo for now. A branch is for temporary experimental surgery.
A fork is for an independent product/release life. STR8 is not ready for a fork
until it can install/use/verify targets cleanly and has its own release story.

Current source homes stay as they are:

```text
SRC/TEST/apps/str8/    STR8 proof and resident recovery source
SRC/TEST/apps/himon/   HIMON monitor payload source
DOC/GUIDES/STR8.md     STR8 product and design contract
DOC/GUIDES/QCC_STR8.md live STR8, IVI, and LEAF questions
```

The boundary is conceptual and documented first. Code movement can wait until
the code itself asks for it.

## V0 Rule

The V0 installer should be target/range-shaped inside the implementation, not
HIMON-shaped. The ordinary operator surface should still be named and guided,
not raw-range driven.

```text
first:  STR8 installs target code/ranges below the protected top sector
proof:  HIMON is the default target used to prove the path
later:  STR8 self-update handles the protected top sector as a special case
future: LEAF packages the IVI mechanism into a friendlier front door
```

The low-level operation is:

```text
install this target image/range
stage full 4K sectors in RAM
merge incoming bytes
erase/write/verify selected sectors
preserve STR8 recovery sector unless explicit STR8 update is requested
```

That keeps V0 small while avoiding a HIMON-only installer.

The first S19 update gates are deliberately fixed:

```text
UPDATE HIMON  accepts only $C000-$EFFF
UPDATE STR8   accepts only $F000-$FFFF, after stronger confirmation
```

Anything outside the selected gate is rejected before erase. A later advanced
target/range updater can reuse the same primitive after the named profiles are
boring.

## Handoff Contract

The reference boot shape is:

```text
RESET -> STR8
STR8 validates/selects target
STR8 hands off to target entry
payload owns normal runtime behavior after handoff
```

In the current combined STR8 image, hardware vectors enter stable STR8 IVI
stubs, then dispatch through patchable RAM targets. That is a mechanism, not a
claim that STR8 dictates every interrupt forever. LEAF is the newer product name
for making this front door easier to explain and use.

```text
STR8 time:    safe defaults, recovery, inert NMI unless a safe request window is open
handoff:      payload may install NMI/IRQ/BRK targets
payload time: payload owns meanings
reset:        STR8 can regain control
```

Payloads can use future LEAF routines to patch IVI targets: install this NMI
target, install this IRQ target, install this BRK target, and return with either
the old target still intact or the new target fully installed. Those routines
change runtime/vector state. They do not erase flash, do not update STR8, and do
not make LEAF mandatory for payloads that already own their own interrupt
policy.

## Classification Rule

When adding a feature, ask which product lane would be embarrassed if it failed:

```text
board will not boot or recover      -> STR8
hardware vectors need safe stubs    -> IVI mechanism, later LEAF surface
monitor command/debug behavior      -> HIMON
hash/catalog naming and resolver    -> THE
application/game/tool runtime       -> payload target
chapter/story/reader path           -> R-YORS book/docs
```

If a feature crosses lanes, split it into mechanism and policy. STR8 may provide
the mechanism that keeps the board recoverable. The payload owns the policy it
uses after handoff.

## Product Story

STR8 can be useful even when a user does not care about HIMON, THE, or the full
R-YORS runtime direction:

```text
install STR8 once
map the flash
save a base image
install a target
verify it
boot it
recover if it breaks
```

IVI is the interrupt-vector indirection pattern from BSO2. IVY is just how IVI
is pronounced. LEAF is the friendly STR8 front door built from it: a stable
place where reset, interrupts, traps, and recovery can enter without reflashing
hardware vectors for every experiment.

HIMON remains the bundled workbench. It should be excellent, but STR8 should be
valuable before HIMON is even considered.
