![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer. Pronounced **are-yors**.

R-YORS is a recoverable runtime and onboard workbench for the WDC
W65C02SXB/W65C02EDU board. It boots through a flash-safe recovery guard into a
monitor, assembler, and AP object runtime.

STR8-N is the reset, recovery, and installation component. Its boundary is
payload-agnostic: it does not depend on HIMON, ASM-F2, OIL, or AP and can
supervise compatible non-R-YORS guest systems.

## System

```text
physical RESET -> Bank 3 STR8-N -- timeout --> Bank 3 HIMON/ASM
                       |                         |
                       |                         +--> ASM-F2 -> AP capsule
                       |                                        |
                       |                                   OIL / APMAN
                       |                                        |
                       |                                   running BODY
                       |
                       +-- J0/J1/J2 --> enrolled guest RESET vector
                       +-- J3 -------> Bank 3 RESET vector
                       +-- I / L ----> flash install / RAM recovery tool
```

| Part | Role |
| --- | --- |
| STR8-N | Bank-3 reset supervisor, recovery, installation, protected-top maintenance, and guest handoff |
| HIMON | Monitor, loader, debugger, catalog/RJOIN services, and command host |
| ASM-F2 | Flash-resident onboard W65C02 assembler and AP object producer |
| AP/APC | Packaged application metadata and BODY stored as a validated capsule |
| OIL | Runtime path for AP validation, loading, relocation, resident imports, and execution |
| APMAN | Banked carrier discovery, installation, status, and load/run manager |

The exact live release, commands, ownership, installation shapes, and accepted
evidence boundary are maintained in the
[Current Capability Matrix](DOC/GUIDES/CAPABILITIES.md). Dated cards and
transcripts may show commands belonging to older images.

## Start Here

- [Documentation Front Door](DOC/INDEX.md) — the single current reading path
- [Operator's Guide](DOC/GUIDES/OPERATORS_GUIDE.md) — safe board operation and recovery
- [Technical Guide](DOC/GUIDES/TECHNICAL_GUIDE.md) — architecture and build contract
- [ASM User Guide](DOC/GUIDES/ASM/ASM_USER_GUIDE.md) — onboard assembly and packaging
- [AP And OIL Guide](DOC/GUIDES/AP/AP_OIL_GUIDE.md) — AP/APC, OIL, APMAN, carriers, and AP Store
- [History And Evidence](DOC/GUIDES/HISTORY.md) — proof cards, transcripts, completed plans, and design lineage

## Build And Test

From the repository root:

```text
make all
make -C SRC asm-test
git diff --check
```

Use `make -C SRC help Q=term` to find narrower targets. Current build products
are under `SRC/BUILD/` and release artifacts under `RELEASE/`.

## Repository Shape

```text
DOC/             current guides, evidence, history, and generated maps
SRC/HIMON/       HIMON source
SRC/ASM/         onboard ASM-F2 source and includes
SRC/APPS/        current applications and carrier tools
SRC/PROOFS/      current proof scaffolds
SRC/TESTS/       host test harnesses
SRC/ARCHIVE/     retired sample, test, proof, demo, and one-off code/data
SRC/tools/       host bootstrap, checking, and documentation tools
RELEASE/         current release sources, images, and checksums
```

STR8-N is built and released from the adjacent standalone STR8-N repository.
R-YORS imports its checked public ABI and owns the HIMON/ASM payload plus the
integration proof. R-YORS II architecture and language planning live in the
sibling `R-YORS-II` repository.

## Safety Boundary

Treat the system as bench-proven rather than a finished field updater. Keep an
external programmer and a known-good image available. Every unrelated guest
system requires its own handoff, peripheral, vector, CRC, and recovery
qualification; a plausible RESET vector alone does not prove compatibility.

Hardware transcripts are evidence for their stated image. Use the current
operator guide before executing any historical flash or bank-maintenance card.

## AI Assistance And Verification

R-YORS development and documentation are AI-assisted. Codex and other AI tools
have helped organize ideas, draft and review source and documentation, build
tests, and analyze results. Walter remains the project author and decision
authority. AI output is not treated as hardware proof: behavior is accepted
only through the repository's host checks, artifact identity checks, and
recorded physical-board evidence.

Detailed contribution and evidence labels are defined in the
[provenance guide](DOC/GUIDES/META/PROVENANCE.md).
