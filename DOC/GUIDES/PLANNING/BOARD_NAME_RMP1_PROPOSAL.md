# Persistent board name and RMP/1 integration proposal

Status: proposed 2026-09-16. This note records an integration boundary only;
it does not change the current STR8-N contract, R-YORS image, or board state.

Companion notes: [STR8-N storage and mutation](../../../../STR8-N/docs/BOARD_NAME_RMP1_PROPOSAL.md),
[R-YORS II integration](../../../../R-YORS-II/DOC/BOARD_NAME_RMP1_PROPOSAL.md),
and [RTERM wire extension](../../../../RTERM/docs/BOARD_NAME_EXTENSION_PROPOSAL.md).

STR8-N may assign Bank-3 `$FFF3-$FFF9` as a seven-byte physical-board label.
Seven `$FF` bytes mean unnamed. A valid configured value is uppercase ASCII
`A-Z`, `0-9`, hyphen, or space, with shorter labels right-padded to seven
bytes. The label is not a DNS hostname, proof of identity, authorization, or
permission to mutate flash.

R-YORS should consume the field only through a published STR8-N contract. Boot
or supervisory code reads and validates it while Bank 3 is selected and caches
it in RAM before a bank handoff. An application or future RMP/1 endpoint uses
that cache and must not select Bank 3 merely to obtain the name.

Changing the label is a guarded Bank-3 sector-F transaction, not a byte poke.
A structured maintenance command must preserve a verified original in the
configured top-backup sector, stage and rewrite all 4096 bytes from RAM, change
only `$FFF3-$FFF9`, verify the complete sector, and require reset. The current
canonical bytes remain erased until STR8-N accepts the assignment.

The companion RTERM proposal carries the name as an optional suffix after the
fixed 11-byte CONTROL ACCEPT payload. The wire extension remains proposed and
must preserve interoperability with an unnamed 11-byte ACCEPT and older RTERM.

Promotion requires coordinated component commits, public constants and
manifest fields, invalid/erased encoding tests, RAM-cache lifetime tests,
old/new RMP/1 interoperability tests, interrupted-rewrite recovery, exact B3:F
readback, reset proof, and final four-bank isolation.
