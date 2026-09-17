# HIMON Message Page And Explicit Routine Calls — 2026-09-17

Status: implemented, full host checks pass, and the Bank-3 C-E installation,
primary `# !` smoke, AP/APMAN regression, debugger regression, ASM handoff,
software re-entry, and physical-reset recovery pass on the board.

> [!NOTE]
> A later register-chaining and conditional-call syntax is recorded as a
> [proposal](../PLANNING/HIMON_HASH_CHAIN_PROPOSAL.md). It is not current HIMON
> behavior and does not supersede the qualified contract documented here.

## Explicit Call

At HIMON, use the callable's FNV name, without the source-label `_FNV` suffix:

```text
> # !+ BIO_FTDI_READ_BYTE_BLOCK
```

The routine waits for a character. Type `A` without Enter. When it returns,
HIMON prints its hash, entry address, and one `RET A=41 ...` register report,
then returns to the prompt. This behavior is verified in host emulation and on
the board.

`# ! NAME` accepts exactly one name, separated from `!` by spaces or a tab.
Lookup uses resident executable FNV records, including the existing inline
and pointer-entry forms. A record requiring confirmation still asks for Y/N.
There is no APMAN/package fallback for a diagnostic miss or wrong record kind.

By default the explicit call reports only the returned registers:

```text
> # ! BIO_FTDI_READ_BYTE_BLOCK
RET A=41 X=E7 Y=07 P=35 S=F9 Nv-BdIzC
```

Use `# !+ NAME` to include the `#hash# ENTRY=address` identity line before
the returned-register line.

| Condition | Output/behavior |
| --- | --- |
| Returning executable | One A/X/Y/P/S report; no hash/entry line |
| Returning executable via `# !+ NAME` | One hash/entry and A/X/Y/P/S report |
| Missing name, joined `!NAME`/`!+NAME`, or extra argument | `# ![+] NAME` |
| Missing or non-executable record | `# ! NF/EXEC` |
| Live saved NMI/BRK context | `# ! LIVE CTX`; target is not called |
| Confirmation declined | No target call or return report |

Bare names retain their current quiet-return policy. `#`, `# NAME`, and the
`K=`, `K<`, and `K>` listing filters retain their previous behavior. The outer
`#` command does not overwrite the target's snapshot or print a second report.
`C=0` with nonzero A is a routine return to report, not an APMAN error.

This is a direct routine call, not a sandbox or a parameter-setting command.
The routine must obey its normal input and stack contract and return with RTS
for a return report to appear. No argument registers or pointer parameters are
initialized for it. Routines that block or transfer control retain that behavior.
An active stopped context is never silently discarded; use the existing
debugger resume/restart workflow before requesting another diagnostic call.

The report records P before clearing decimal mode for the monitor's ADC-based
hex formatter. The reported D bit therefore remains the target's returned bit.
The existing first `N/n` display convention (entry carry) is unchanged.

## Measured Storage

The final split-report build is stamped `00.0917(1534)` and is installed on
the board.

| Stage | Occupied ROM bytes | Available bytes |
| --- | ---: | ---: |
| After the preceding 258-byte reduction | 12,022 | 266 |
| Fixed message page, before `# !` | 11,918 | 370 |
| Message page plus `# !` | 12,082 | 206 |
| Final `# !` / `# !+` split | 12,107 | 181 |

The message change saves 104 bytes: 57 call sites save two bytes each, minus
two five-byte wrappers. The selected existing text occupies exactly 256 bytes;
shared aliases and the NMI/PC suffix remain shared. The broader I/O-name-table
optimization was not applied.

The explicit-call addition costs 164 bytes: 149 for its routine and local
messages, seven for dispatch, one for decimal-mode cleanup after capture,
and seven for updated `#` usage text. Net growth from the preceding compact
build is 60 bytes. There is no added fixed RAM or zero-page allocation; the
existing snapshot is reused. The nested explicit-call path has four additional
return-address bytes on the stack at target entry compared with a bare call.
Selecting RET-only output by default and full identity output with `+` adds 25
bytes to that first implementation.

Final linked layout:

| Range | Contents |
| --- | --- |
| `$C000-$EAAD` | CODE: 10,926 bytes, including inline tables/records |
| `$EAAE-$EE4A` | Core DATA: 925 bytes |
| `$EE4B-$EEFF` | Explicit `$FF` padding: 181 reusable bytes |
| `$EF00-$EFFF` | Fixed message page: 256 bytes |

The WDC `HIMMSGPAGE` section fixes the text page independently of CODE/DATA.
`HIM_CORE_END` and `_END_DATA` retain the real core endpoint, `$EE4B`.
The post-link finalizer rejects missing used bytes, overlaps, non-FF padding,
page overflow, and bytes outside HIMON. It emits every address in
`$C000-$EFFF` and normalizes S9 to `$C000`. The transferred image remains
12,288 bytes, not sparse; free space is padding that future code can replace.
STR8-N at `$F000` and above is outside this component.

Local dense component: `SRC/BUILD/s19/himon-rom-c000.s19`.
Its 12,288 payload bytes match the finalized linked image exactly, including
the FF reserve, and its S9 is `$C000`. Payload SHA-256:
`49C0A779F58BAC0FC5D4EC601096863C0C00D56B25823A6EBFA26C94D308EEDB`.
This component was installed to Bank 3 sectors C-E through STR8-N 1.35. It has
not been published as a release.

## Verification And Remaining Board Proof

Focused tests cover all 53 relocated message labels and all 256 message bytes,
shared suffixes, boot/stop output, exact padding and unchanged RAM/ZP symbols;
real BIO character-read code with simulated `A`; exact returned registers and
single reporting; returned decimal mode using the real hex formatter; malformed,
missing and non-executable names; Y/y/N confirmation; live-context protection;
quiet bare calls; and unchanged `#` listings, lookup and filters. Existing flag,
hex, opcode, FNV, AP, launch and resume tests also pass.

Layout tests cover dense serialization and idempotence, split core/page-tail
padding, 12 rejected invalid layouts and six rejected invalid start records.
The optional baseline comparisons use ignored local S19/map snapshots captured
before the two reductions; they are not release artifacts.

```text
make -C SRC himon-size-check HIMON_VISIBLE_STAMP="0917(1534)"
python -B SRC/tools/check_himon_size.py --baseline SRC/BUILD/tmp/himon-compact-before/himon-rom-c000.s19 --page-baseline SRC/BUILD/tmp/himon-page-before/himon-rom-c000.s19
make -C SRC asm-test himon-banked-ap-check himon-io-led-check himon-rom-bin HIMON_VISIBLE_STAMP="0917(1534)"
```

The full ASM smoke suite, banked-AP checks and I/O LED checks passed. The
32K ROM BIN was built, and its `$C000-$EFFF` payload matches both the finalized
linked S19 and the dense component byte for byte, including all 181 FF bytes.

STR8-N's guarded installer erased, programmed, and verified Bank 3 sectors C-E,
then returned `OK`. Cold entry showed HIMON `00.0916(1949)`, and the real
`# ! BIO_FTDI_READ_BYTE_BLOCK` test returned `A=41` after receiving `A`.
See the [board record](../LOGS/HIMON_HASH_CALL_BOARD_2026-09-17.md).

The final split-report follow-up installed stamp `00.0917(1534)` through the
same guarded Bank-3 C-E path. Exact `$C000-$EFFF` readback matches the candidate,
the STR8-N top changed only at the expected Bank-3 journal pair, `# ! FNV1A_INIT`
printed one RET line without `ENTRY=`, and `# !+ FNV1A_INIT` printed hash
`4B9AEE1E`, its entry, and one RET line. See the
[split-report board record](../LOGS/HIMON_HASH_CALL_PLUS_BOARD_2026-09-17/README.md).

Follow-up board checks also pass for quiet bare AP dispatch, all-carrier APS,
AP detail/load/run/refusal paths, BANKAUDIT imports and Bank-3 restoration,
RAM S19 load, G return reporting, BRK context preservation, `# !` live-context
refusal, breakpoint/single-step/resume, warm/cold software re-entry, fresh ASM,
and physical-reset AP recovery. BANKAUDIT's Bank-3 C/D/E CRCs exactly match the
built candidate. A subsequent independent 32K Bank-3 monitor readback matches
the `$C000-$EFFF` candidate byte for byte.
