# HIMON/AP contract correction and source extraction - 2026-09-16

The functional correction follows the original Step-1 baseline and
[Step-2 audit](HIMON_AP_INTERFACE_RAM_AUDIT_2026-09-16.md). It is a separate
change from Step 3's source extraction. The frozen comparison stamp is
`00.0915(2324)`; hashes identify this workbench image. Previously published
release packages have not been replaced.

## Current contract

| Operation / transition | Behavior |
| --- | --- |
| PARSE `$00`, LOAD `$01`, SUGGEST `$02`, LINK `$03` | Existing operation values and results retained. Ordinary LOAD accepts a whole BODY within `$2000-$4FFF` or the separate `$7000-$7BFF` tool tray. ASM's `LOAD` continues to use `$01`. |
| TAKEOVER `$05` | New opt-in operation through the existing AP vector. Loads, links, and relocates a whole BODY within `$2000-$6FFF`; the tool tray is excluded. Successful result matches LOAD: C=1, A=0, X/Y=destination. Invalid spans, overflow, or overlap fail before copying. Import/relocation failure after copy can leave changed destination bytes. |
| HIMON `AP package destination` | Uses TAKEOVER, then runs the destination base. This command relinquishes the old ASM session. |
| APMAN `AP` / `AP L` | Uses TAKEOVER for children; BODY must end before `$7000`. Entry-export selection and tail-JMP/child-RTS behavior are unchanged. |
| Package source | Unchanged: complete envelope must fit within `$0A00-$19FF`, `$2000-$4FFF`, or visible Bank-3 `$8000-$FEFF`. Source, ordinary destination, and takeover destination limits have separate constants. |
| MANAGER INSTALL input | Before command shadow, selector copying, or staging, bootstrap rejects sources below `$2000` and parses the complete envelope. The parser rejects all other unstable regions/crossings. Invalid input returns C=0, A/AP status/APMAN status `$D4`. APMAN independently excludes the low staging region before parsing. |
| Absent/corrupt manager | Prints `APMAN NF`; returns C=0 and `$DA` in A, AP status, and APMAN status. |
| Named duplicate | Lookup returns its single `$D2` diagnostic/status; callers no longer overwrite it with NOT_FOUND `$D1`. No child executes. |
| ASM `INSTALL package Bn` | On return from MANAGER, begins a fresh ASM session at `$2000`, with cleared symbol/fixup counts. It does not resume the previous SEAL session. |

Manager status remains a separate result domain from normal AP parse/load
status. A manager's successful child can determine the eventual register
result. Generic AP success/failure documentation is not a replacement for
the APMAN card contract.

## RAM and size

`ASM_ABI_SESSION_RESUME` owns **one previously unused byte at `$7E6A`**.
ASM's SEAL flag moved there so loading arbitrary bytes into `$5000-$6FFF`
cannot recreate a stale flag. The old `$5003` slot remains reserved; following
UDATA offsets and its `$6D6E` exclusive end are unchanged. Current FNV scratch
is in zero page; the `$7E6A-$7E6D` FNV aliases occur only in retired archive
source. `$7E6B-$7E6D` remain unused in the current image.

HIMON initialization, manager bootstrap, and APMAN dispatch clear the flag.
TAKEOVER clears it after parse/range/overlap checks and before BODY copying;
a later link failure still invalidates the session. Early rejected takeover
leaves it unchanged. `ASM S` refuses an invalidated session; `ASM`/`ASM NEW`
initializes fresh state. Applications must preserve the high service workspace
and return through the documented caller chain. This is not protection from
arbitrary writes by a child application.

| Component | Functional bytes | Change from Step 1 | Remaining space |
| --- | ---: | ---: | ---: |
| HIMON | 11,868, end `$EE5C` | +114 | 420 before `$F000` |
| ASM-F2 | 15,235, end `$BB83` | 0 | 1,149 before `$C000` |
| APMAN BODY | 3,072, end `$7C00` | +4 | 0 in its overlay |
| APMAN envelope | 3,118 (`$0C2E`) | +4 | Fits its 4K carrier |

HIMON ownership is 3,077 AP bytes, 2,681 shared bytes, and 6,110 other bytes.
The carried mutation worker is unchanged. APMAN's duplicate-return cleanup and
shared size-error exit offset most of its source/flag checks. The full overlay
is an enforced ceiling, not permission to extend into the card at `$7C00`.

## Evidence and scope

The evidence directory is
[HIMON_AP_CHANGE_2026-09-16](../LOGS/HIMON_AP_CHANGE_2026-09-16/manifest.json).
The new linked-code regression has 53 cases covering both destination policies,
whole-span/overflow/source/overlap guards, typed imports and failure effects,
unstable INSTALL rejection before staging, missing/corrupt managers, duplicate
and not-found results, manager/child return, worker preparation, actual ASM
clients, fresh-session counts, and refusal of a forged old `$5003` resume byte.
Flash writes are forbidden in that emulator; INSTALL stops at worker entry.
The largest observed stack use is 18 bytes, including the synthetic two-byte
caller return. Terminal TX internals, interrupts and arbitrary child behavior
are outside this fixture bound; every completed emulated call balances its stack.

The full `asm-test` suite and focused HIMON gates passed before extraction.
The board-S19 identity gate initially rejected the changed HIMON byte count;
its pinned expected count was updated from `$2DEA` to the measured `$2E5C`,
and its nine payload comparisons passed. No identity comparison was removed.

COM4 installed the exact dense Bank-3 `8-E` payload through STR8-N 1.34.
Full readback matched every payload byte. Above `$EFFF`, only the expected
D3 journal byte changed (`$FFED: FF -> FC`); STR8 code, vectors, roles, and
other directory fields stayed exact.

Thirteen board checks covered direct takeover at `$5000` and `$6FFF`, upper
boundary rejection with unchanged surrounding bytes, ordinary LOAD protection,
ASM resume refusal/fresh entry, unsafe resident/manager INSTALL rejection,
new APMAN inventory, and a linked BANKAUDIT child executing at `$5000` and
restoring Bank 3. Actual ASM INSTALL with no installed manager returned `$DA`
and zeroed the old name counts. STR8 software warm/cold entries and service
reinitialization passed. The first automation run expected a generic `RET`
line for rejected `ASM S`; HIMON correctly printed `EXEC ERR=$03`. The harness
expectation was corrected and the checks rerun; the raw transcript retains both.

The new APMAN was loaded into RAM for these checks. **Bank 2 has not been
erased or provisioned**, and there is currently no installed APMAN carrier.
Persistent Bank-2 setup remains the next board phase. Physical RESET/NMI,
visual LED acceptance, and a new destructive INSTALL cycle were not repeated;
the unchanged selector/mutation worker is not newly qualified by these tests.
Historical acceptance and the remaining LED/reset checklist stay intact.

The subsequent [persistent Bank-2 board cycle](../LOGS/HIMON_AP_BANK2_2026-09-16.md)
supersedes that pending deployment state: it installs this exact APMAN,
qualifies the real ASM INSTALL path, and records complete flash isolation.
The extraction evidence below remains unchanged.

## Step 3 ownership and verification

Six includes are expanded at their original assembly positions:

- `AP/ap-contract.inc`: resident AP constants and scratch aliases.
- `AP/ap-manager.inc`: manager bootstrap and bank staging.
- `AP/ap-core.inc`: service dispatch, parsing, copying and internal relocation.
- `AP/ap-link.inc`: typed import linking.
- `AP/ap-space.inc`: hole search and AP result exits.
- `HIMON/himon-ap-adapter.inc`: monitor AP/APS grammar and execution policy.

Shared console/FNV/PACK40/resolver routines, public ABI aliases, initialization,
and strings keep their existing owners. ASM and the external APMAN build path
remain separate. No new wrapper, registry, or R-YORS II design was introduced.

Both HIMON object targets depend on every new include. Eight structural
checkers expand the actual moved source through `read_himon_source.ps1`;
the inventory checker retains its current-manager branch. Expanded nonblank
source exactly matches the frozen functional source. Deliberately corrupting
a moved range declaration fails the existing check; a cyclic AP include also
fails. Generated routine/command/stack maps include the AP owner files and
exclude literal disabled `IF 0` branches. Stack maps remain source estimates,
not interrupt/indirect-call bounds.

The final extraction identity report and full regression receipt are retained
in the evidence directory. All 15 compared S19/BIN/AP/map artifacts match the
frozen functional baseline byte for byte, with every linked symbol unchanged
and no timestamp exclusions. The full regression and all 53 contract cases
pass after extraction. Both documentation generators follow the extracted
owners; future source-reference release bundles include those files too.

## Reproduction

From the repository root:

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin
python -B SRC/tools/check_himon_ap_contracts.py --output LOCAL/himon-ap-contracts.json
powershell -NoProfile -ExecutionPolicy Bypass -File SRC/tools/gen_docs.ps1 -Src SRC -OutDir DOC/GENERATED
```

Frozen artifacts and source are also kept locally under
`LOCAL/himon-ap-change-20260916/{functional,functional-source,extracted}`.
The initial audit script/evidence remains reproducible against its original
Step-1 snapshot; its intentionally failing contracts are not the new acceptance
oracle. No commit or release publication is implied by this workbench evidence.
