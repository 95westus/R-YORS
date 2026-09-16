# HIMON/AP RAM contract for scoped-search development

Status: ownership frozen for the 2026-09-16
[banked AP integration candidate](HIMON_SCOPED_FNV_IMPLEMENTATION_2026-09-16.md).
This does not confer board acceptance or complete the persistent AP Store menu.
The historical interface audit retains its original observations; this contract
incorporates the subsequent corrections.

## Current boundaries

Ranges are inclusive. Calls are foreground and non-reentrant, with Bank 3
selected and decimal mode clear. Shared zero page and A/X/Y are volatile unless
the called interface explicitly specifies a result.

| Range | Owner and lifetime |
| --- | --- |
| `$0100-$01FF` | Hardware stack; preserve the caller return chain. |
| `$0200-$09FF` | ASM names outside manager use; selector at `$0200-$0226`, resident stage reader at `$0300-$0335`, or carried mutation worker at `$0200-$042A` during bank-tool use. These are alternative owners. |
| `$0A00-$19FF` | ASM fixup names or one staged sector. Every stage invalidates previous pointers into the tray. |
| `$1A00-$1AFF` | Command page shadow, copied before the manager replaces the monitor command buffer. |
| `$1B00-$1FFF` | Application workspace. Microchess owns `$1B00` for its saved caller stack pointer; do not use it for retained search state across child entry. |
| `$2000-$4FFF` | Ordinary AP BODY/source range. A whole source envelope must fit; LOAD rejects overlapping source/destination. |
| `$5000-$6D6D` | ASM UDATA outside TAKEOVER; retained counts do not preserve overwritten low-memory names. |
| `$2000-$6FFF` | Explicit TAKEOVER destination; successful validation invalidates ASM resume before copying, including when subsequent linking fails. |
| `$7000-$7BFF` | Manager/tool tray. Candidate AM02 BODY is `$7000-$7BF2`; its 13-byte margin is still part of this tray. Installed AM01 ends at `$7BD6`. |
| `$7A00-$7AFF` / `$7B00...` | Monitor command/decoding buffers outside manager execution; overlap the loaded manager and high-tool overlay. No nested monitor input/loader while the manager is live. |
| `$7C00-$7DBF` | Foreground high-tool overlay. APMAN card is `$7C60-$7C73`; AP Store chain-tool card is `$7C80-$7D3F`. Other tools own overlapping ranges, including BANKAUDIT/BANKDUMP. No state survives arbitrary child entry here. |
| `$7DC0-$7DC7` | Resident import-link scratch, retained across resolver calls. |
| `$7DE7-$7DFF` | STR8-owned state; exclude the whole allocation, including bytes preceding the worker fields at `$7DE9`. |
| `$7E00-$7EFF` | Published services and monitor workspace. `$7E6A` is the durable ASM resume flag; neighboring unused bytes are not sufficient for a search card. |
| `$7F00-$7FFF` | I/O, never a RAM search window. |

The resident PARSE source ranges remain `$0A00-$19FF`, `$2000-$4FFF`, and
visible Bank-3 `$8000-$FEFF`. INSTALL rejects unstable staging sources before
bootstrap. Ordinary LOAD also permits the separate tool tray; TAKEOVER does
not. A managed child must finish below `$7000`.

## Scoped proof card

Reserve `$7D40-$7D5F` only within the scoped-search foreground phase. It is
private scratch, not a new published service ABI. It does not coexist with a
live AP Store tool or arbitrary child-owned high overlay. Its placement is
above the chain-tool card and ASM's `$7CFF` emission ceiling, below import-link
scratch and STR8 state, and outside staging, command shadow and manager BODY.

| Offset | Meaning |
| --- | --- |
| `$00-$02` | Requested, allowed, effective bank masks |
| `$03` | Bank-sector window mask |
| `$04-$05` | RAM enable and RAM-window mask |
| `$06` | Explicit HREC/AP-export format |
| `$07-$0A` | Stable wanted FNV32, little endian |
| `$0B` | Match count saturated at two |
| `$0C-$10` | Found source, bank, window, address low/high |
| `$11-$12` | Traversal bank and sector/window cursor |
| `$13-$15` | Canonical-name pointer low/high and length |
| `$16-$17` | Live AM02 candidate-validator callback pointer |
| `$18-$1F` | Reserved; initialize, do not infer persistent results |

Initialize the entire card before every request. Copy wanted identity before
FNV helpers can overwrite zero page. A canonical-name pointer must refer to
caller-owned stable RAM (the command shadow for command dispatch), never to
the staged sector or overlaid monitor command page. A zero-length name must
not silently bypass the later automatic-dispatch identity check.

The shared 28-byte policy primitive takes a policy byte as input; firmware
reads STR8's `$FFF2` while Bank 3 is selected. Host tests cover every byte value
and request mask. In the bank-only candidate, source/address and bank-cursor
fields are reserved, not published results; active bank/sector use APMAN's
existing `$A7/$A8`, and `$12` holds the sector-mask cursor. The callback owns
`$AC/$AD` for the bounded entry row. Nonzero RAM-enable and HREC format are
rejected before staging.

The future initial RAM-provider proof is limited to `$3000-$3FFF`; it must not treat
the sector staging tray as another provider. RAM HREC and AP-export validation
remain separate paths and cannot execute on the strength of a hash alone.

The [initial RAM HREC inspector](RAM_HREC_PROOF_2026-09-16.md) now implements
that one-window metadata-only proof as a separate 333-byte transient. It uses
`$18-$1C` of the card for entry/extra/kind results within its own foreground
lifetime; those bytes remain reserved in the installed banked finder. It does
not combine RAM and flash candidates or add command dispatch. SPI SRAM is not
yet installed, and SPI WORK allocation stays deferred.

The next [RAM AP uniqueness inspector](RAM_AP_UNIQUENESS_2026-09-16.md) is an
alternative `$2000-$21DB` transient, with private state `$2E00-$2E0F` and stable
name `$2F00-$2F1E`. It copies bounded `$3000-$3FFF` AP envelopes into staging,
then combines RAM and banked AP counts without load/link/entry. It requires
matching private HIMON helpers and a fresh AM02 overlay. In this AP proof,
card `$18-$19` is an entry offset and `$1A-$1B` is BODY length, not the HREC
proof's entry/extra pointers. These phase-specific metadata meanings are not
a shared public execution ABI. Inspectors do not survive arbitrary child entry.

## Transitions and recovery

1. Resident hit returns through the existing resolver; no external stage occurs.
2. A scoped miss path takes foreground ownership, invalidates ASM continuation
   before manager staging, initializes its card and retains the name/hash.
3. Bootstrap and target scan must use the same decoded allow mask. Request
   masks cannot enroll banks. Staging invalidates all prior parsed pointers;
   retain locations and revalidate the chosen envelope before loading it.
4. Final child load consumes the selected metadata before entry. Tail-entry
   ends the search-card lifetime. A child RTS returns to the existing caller;
   it does not resume a persistent manager menu.
5. Failure returns only with Bank 3 restored. No resolver flash writes, implicit
   policy installation, mutation-worker entry, or recovery from an unsafe
   foreign-bank return is permitted. Interrupted read-only search has no media
   transaction to resume; reset discards its scratch. NMI safety during bank
   access remains a separate unresolved hardware gate.

A future persistent menu must reload/reinitialize its overlay after child
return and separately specify interrupted mutation recovery. This current
contract does not approve nesting the old transient tools.

## Baseline and remaining gates

The accepted parser-initialization reduction ends HIMON at `$EE3E` (450 bytes
free); APMAN BODY/package are `$0BD7`/`$0C05`. The banked integration candidate
ends HIMON at `$EFF8` (8 bytes free) and APMAN at `$7BF3` (13 bytes free), with
envelope `$0C21`. Measure linked growth for each further slice.

COM4 discovery on 2026-09-16 reports Microchess B1:$9000, envelope `$06A6`,
and APMAN B2:$8000, envelope `$0C05`. The
[follow-up record](../LOGS/AP_FNV_FOLLOWUP_2026-09-16.md) closes Microchess's
physical-reset gate. The operator observed LED activity but could not identify
the sequences; exact bank/sector display acceptance remains open. The earlier
Bank-2 setup placed APTEST at B2:9: the BANKDUMP B2:9 search example is a
fixture specification, not permission to replace that sector.

References: [contract correction](HIMON_AP_CONTRACT_CHANGE_2026-09-16.md),
[APMAN size qualification](APMAN_SIZE_REDUCTION_2026-09-16.md),
[scoped-search design](../PLANNING/HIMON_SCOPED_FNV_BANK_SEARCH.md).
