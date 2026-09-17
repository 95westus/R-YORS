# Safe RAM AP handoff — 2026-09-16

This slice adds a 322-byte, image-pinned transient at `$5000-$5141`. It turns
the accepted metadata-only RAM/banked AP uniqueness result into a guarded
load, link and execution transition. It does not add a monitor command or a
public ABI. SPI SRAM is not installed, so SPI support and WORK allocation stay
deferred.

Source: [fnv-ram-ap-handoff-5000.asm](../../../SRC/APPS/fnv-ram-ap-handoff-5000.asm).
Run `make -C SRC fnv-ram-ap-handoff-check HIMON_VISIBLE_STAMP='0915(2324)'`.
The check is also an `asm-test` prerequisite.

## Ownership and transition

The caller loads the matching `$2000` uniqueness inspector, this `$5000`
handoff, and the image-pinned AM02 overlay. It initializes the private request
card and stable canonical name exactly as the inspector requires, then calls
`$5000`.

| Range | Foreground owner |
| --- | --- |
| `$0A00-$19FF` | validated candidate stage; cleared before child entry or failure return |
| `$2000-$2FFF` | inspector initially, then linked child BODY at `$2000` |
| `$2F00-$2F1F` | stable name; cleared before child entry or failure return |
| `$3000-$3FFF` | optional RAM provider; read-only |
| `$5000-$5141` | handoff code, surviving the `$2000` child load |
| `$5400-$540F` | saved location, entry offset and BODY length; cleared before return/entry |
| `$7000-$7BFF` | freshly loaded AM02 overlay |
| `$7D40-$7D5F` | request/result card; cleared before return/entry |

The handoff clears the durable ASM resume flag on entry, including request
failures that return before discovery. It then performs the full uniqueness
search twice. It requires success, one match, the same
source/bank/window/address, the same entry offset and the same BODY length.
The second search leaves a newly validated envelope at
`$0A00`. A whole BODY must fit `$2000-$2FFF` so it cannot overwrite the RAM
provider at `$3000`.

The existing resident AP `LOAD` reparses that stage, verifies its BODY seal,
copies it to `$2000`, applies relocations and resolves typed imports. Any load
or link error returns the resident AP status and never enters the child. After
a successful load, the handoff reselects the canonical executable export,
rechecks its exact name and saved entry offset, and proves the final entry lies
inside the BODY.

Before entry it clears the card, stable name, complete staging tray and private
handoff state. It then tail-enters the linked child with a manufactured normal
subroutine return edge. Child `RTS` returns through the handoff to its caller.
The child's A and flags are preserved, including a clear carry; callers that
need to distinguish this from pre-entry failure must use their own child
protocol. Pre-entry failure always returns `C=0,A=status` after the same state
retirement.

Calls are foreground, non-reentrant, Bank 3 selected and decimal clear. Shared
zero page, AP parser/link scratch and A/X/Y are volatile. Provider modification
must not occur concurrently. The handoff never writes a provider or flash and
does not preserve an ASM session.

## Acceptance boundary

The linked host gate covers unique RAM and bank providers, a nonzero entry,
resident-import linking, duplicate and malformed refusal, invalid requests,
provider change between scans, staged BODY tampering, unresolved imports, and
child A/carry preservation. Execution guards reject provider/stage execution,
foreign-bank ROM fetch, provider writes and handoff-code writes. Every case
checks balanced return and complete retirement; successful cases check that
retirement is already complete at the first child instruction.

The board record is [RAM_AP_HANDOFF_2026-09-16.md](../LOGS/RAM_AP_HANDOFF_2026-09-16.md).
This closes the explicit-card ownership path through load, link and execution.
Integrating it with the resident-miss command path remains a separate slice;
resident-first command precedence and the installed HIMON/AM02 images remain
unchanged.
