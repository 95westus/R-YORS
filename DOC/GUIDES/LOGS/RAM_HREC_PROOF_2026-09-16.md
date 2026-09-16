# RAM HREC inspection proof — 2026-09-16

The first existing-RAM HREC inspection slice is accepted as a standalone,
metadata-only transient. It does not add command dispatch or execute providers.
SPI SRAM is not installed; no SPI operation or flash WORK allocation was made.
See the [private contract and limitations](../AP/RAM_HREC_PROOF_2026-09-16.md).

The 333-byte image occupies `$2000-$214C`, with SHA256
`dc0a54a873ef44ae1b304f29597a3fbb784472870b719b90f1131a6b43a6de58`.
The linked-byte host check passes 72 cases with enforced read/write/execute
boundaries. The full `asm-test` regression includes this check.
The earlier `host.json` receipt describes an unflashed 335-byte draft;
`final-host.json`, linked artifacts and all board fixtures use the final
333-byte image. The two-byte reduction removes a redundant branch only.
Full regression used the build's automatic display stamp. Firmware artifacts
were then regenerated with the installed `0915(2324)` stamp and compared
byte-for-byte with the accepted board archive. Neither build was flashed.

Seven RAM-only drivers were first rehearsed against the linked bytes and then
loaded, read back exactly and run on COM4 at 115200 baud. No driver enters a
flash worker or executes a discovered provider. Every provider window was
read back unchanged after inspection.

| Board case | Result |
| --- | --- |
| Inline record at `$3FF7`, entry `$3FFF` | unique, `$AC`, exact metadata |
| K=5 entry/text pointers | unique, `$AC`, exact metadata |
| K=3 entry/confirmation pointers | unique, `$AC`, kind retained |
| Two valid records | `$D2`, count 2, no published pointers |
| Entry points to I/O `$7F00` | `$D1`, no published pointers |
| RAM disabled | `$D4`, no published pointers |
| AP format requested of HREC inspector | `$D4`, no published pointers |

Complete four-bank readbacks before and after the tests match the accepted
[banked AP qualification](SCOPED_QUALIFICATION_2026-09-16.md) byte for byte:

`8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b`

Firmware, policy `$A6`, protected backup B2:F, BANKDUMP B2:A and APTEST B2:9
are unchanged. No flashing or reset-dependent persistent change was performed.
The earlier physical-reset qualification remains associated with that exact
unchanged flash image; these RAM fixtures are intentionally temporary.

The [evidence directory](RAM_HREC_PROOF_2026-09-16/) retains source snapshots,
linked artifacts, host/full-regression logs, seven fixtures and driver results,
raw serial, before/final archives, export verification and a SHA256 manifest.
The broader RAM-provider checkbox remains open for RAM AP validation,
combined-source uniqueness, load/link ownership and execution-policy integration.
