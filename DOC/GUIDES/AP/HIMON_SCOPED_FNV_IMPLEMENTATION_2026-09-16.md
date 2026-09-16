# Scoped FNV/AP lookup integration candidate - 2026-09-16

This candidate implements banked AP discovery after a resident command miss.
The pair is now installed on COM4 with policy `$A6`. The later
[step-2 board smoke](../LOGS/SCOPED_SMOKE_BOARD_2026-09-16.md) proves installation,
disabled/enabled smoke, physical reset and isolation. The [broader banked AP qualification](../LOGS/SCOPED_QUALIFICATION_2026-09-16.md) now passes.
RAM-provider/HREC lookup remains open. The original implementation evidence below
was host-only and describes its own exact earlier fixture configuration.

The subsequent [sector-role and transient-collection change](SECTOR_ROLES_AND_RAM_TRANSIENTS_2026-09-16.md)
sets WORK to unassigned and moves the backup to B2:F. The exact evidence below
retains the preceding top-image hash and role fixtures; use the follow-up for
the current candidate configuration and deployment sequence.

## Behavior

Resident executable HRECs remain authoritative. `THE_JOIN_FIND`, typed imports,
and `THE_JOIN_EXEC_XY` keep their resident-only result contracts. Only the
monitor command-miss path attempts external AP execution.

With B3 `$FFF2=$A6`, a bare `BANKDUMP` searches valid carriers in B2 then B1,
sector `$8` through `$F`, excluding configured WORK and B3:F-backup locations.
It requires exactly one matching entry export, restages and revalidates that
carrier, then uses the existing takeover/load/link/entry path. The manager and
target searches both honor persistent bank eligibility. `$FF`, `$A0`, and
invalid signatures disable automatic discovery. `$A1-$A7` explicitly enroll
their low-three-bit bank sets; request masks can only remove banks.

The existing `AP Bn name` and named `APS Bn name` paths use the same finder,
with one requested bank. A disabled named bank is never passed to the bank
selector. `APS` physical inventory, explicit sector selectors, and INSTALL
retain their distinct physical-operation contracts after an eligible manager
has been loaded. Direct visible-RAM `AP package destination` remains independent
of manager discovery and the policy byte.

Every external candidate must pass the resident AP-v2 parser, bounds and seal
checks, BODY FNV, one EXEC+ENTRY export, and entry-offset bounds. Named lookup
also compares the stored hash, canonical name length and exact PACK40 encoding,
including zero padding. Hash equality alone cannot select a differently named
provider. Loose HREC bytes in a bank are not AP envelopes.

Malformed candidates do not contribute a match. No valid match returns `$D1`;
multiple valid matches return one `$D2` diagnostic without execution. The count
saturates at two and retains the first match location. It does not print every
duplicate location. Load/link failure cannot reach child entry.

The first integrated format is **banked AP_EXPORT only**. RAM-provider search
and HREC-format requests return `$D4` before staging. They remain separate
future work; this implementation never broadens a request into an all-RAM scan.
Bare names may have leading/trailing spaces, but arguments after the name are
rejected. `AP Bn name [destination]` retains its existing destination grammar.

## Shared routines and compatibility

HIMON's resident AP layer owns policy decode, traversal, duplicate handling and
canonical comparison. APMAN installs a private callback that excludes protected
locations, stages a sector, parses it and locates its bounded entry row. The
old dedicated named scan was replaced by this shared finder, avoiding a second
scanner in the small manager overlay.

The manager BODY identity is now **AM02**. New HIMON rejects AM01 during
bootstrap; otherwise an older manager could bypass the new named-bank policy.
Deploy HIMON and APMAN as a coordinated pair. A well-sealed short BODY cannot
be identified as a manager by reading beyond its end. Manager identity checking
is shared between bootstrap and the manager's self-execution guard.

Private operations through the existing AP vector:

| Operation | Contract |
| --- | --- |
| `$06` FIND | Live AM02 callback and initialized private request card; Bank 3, foreground, non-reentrant. C=1 leaves the unique carrier staged and parsed; C=0 returns an APMAN-domain failure in A. A/X/Y and parser scratch are volatile; this is not a callable-address resolver. |
| `$07` MANAGER_ID | A successfully parsed BODY; C=1 identifies AM02, C=0 otherwise. May overwrite monitor parser scratch. |
| APMAN mode `$04` | Bare-command adapter: name from the stable command shadow, exact end-of-line check, FIND, then the ordinary guarded child load/entry path. |

AP operation `$06` invalidates ASM resume before any staging. The existing
manager bootstrap and TAKEOVER invalidations remain. No persistent menu is
introduced; child entry ends the manager/card lifetime and RTS follows the
original caller chain.

The callback runs from RAM. APMAN now retries a failed Bank-3 restoration from
RAM before returning `$D9`; it cannot return into foreign-bank ROM. A permanent
restore failure remains in that RAM retry loop. NMI qualification is unchanged.

## RAM and measured limits

The [RAM contract](HIMON_AP_SCOPED_RAM_CONTRACT.md) remains the ownership basis.
`$7D40-$7D5F` is private foreground state, with callback pointer `$7D56-$7D57`.
The implemented finder uses request/allowed/effective masks, sector mask,
format/RAM-enable guards, stable wanted hash/name, match count and found
bank/sector. The reserved source/address/cursor fields are not published results
in this bank-only version. APMAN's `$A7/$A8` hold the active cursor and `$AC/$AD`
the validated entry row; its existing card holds legacy package facts. No new
high-RAM allocation or service-vector slot was added.

| Image | Before | Candidate | Remaining |
| --- | ---: | ---: | ---: |
| HIMON | 11,838 bytes, end `$EE3E` | 12,280 bytes, end `$EFF8` | 8 bytes before `$F000` |
| APMAN BODY | 3,031 bytes | 3,059 bytes, end `$7BF3` | 13 bytes before `$7C00` |
| APMAN envelope | `$0C05` | `$0C21` | Fits one 4K carrier |
| ASM-F2 | 15,235 bytes | Unchanged | 1,149 bytes before `$C000` |

The small margins are enforced ceilings. Further features need measured space
recovery or a separately approved placement change. The carried mutation worker
is unchanged. Two equivalent byte-saving changes in APMAN remove redundant
negative-digit checks and simplify PACK40 digit-to-ASCII arithmetic.

## STR8 ownership and deployment gate

STR8-N now exports `STR8_CONFIG_FNV_POLICY=$FFF2` and default `$FF`; its manifest
and the R-YORS integration lock assign remaining reserved bytes `$FFF3-$FFF9`.
The public-contract hash changes; the canonical 4K top-sector hash stays
`9538D97854BA9D5D76143CBA0FEDB3B2E7CE18F977CE89557406E63404026CB7`.
No consumer guesses the configuration address independently.

Do not deploy only new HIMON over an AM01 manager and expect existing named AP
commands to work. Board acceptance requires preserved four-bank backups,
coordinated AM02/HIMON installation/readback, a guarded B3:F policy update,
`$FF` failure and `$A6` success, duplicate/malformed refusal, B0 omission,
physical reset and final flash isolation. The current B2:9 APTEST carrier must
be preserved; choose and record an erased sector for BANKDUMP.

Host checks use explicit synthetic enrollment in emulated Bank 3. This is not
evidence that `$A6` is installed on COM4. See the retained
[host evidence](../LOGS/SCOPED_FNV_2026-09-16/manifest.json) for exact inputs,
linked sizes, test results and validation logs.

## Host qualification

`make -C SRC asm-test HIMON_VISIBLE_STAMP='0915(2324)'` passes, including
65,536 policy/request combinations and 54 linked integration cases. The latter
execute the real HIMON, AM02 and STR8 selector bytes, intercept terminal TX,
reject every flash write and check that foreign-bank instruction fetch never
occurs. Coverage includes disabled/excluded banks, sector masks, protected
roles, duplicates, malformed carriers, canonical names, resident precedence,
AM01 refusal, failed linking and a transient Bank-3 restoration failure.

The BANKDUMP case wraps the existing 2,348-byte BODY (FNV `$CEF1F837`) in its
`$09AD` AP envelope, resolves its three imports through the resident resolver,
and checks the patched addresses before entry at `$2000`. It stops there;
this test does not operate BANKDUMP's interactive menu. Its approximately
5.9 million instructions require an eight-million-instruction test budget.
The fixture uses the AP format's columnar relocation table.

Byte comparisons also confirm unchanged ASM firmware and the same 555-byte
carried mutation worker. `make -C SRC board-s19-check` passes all nine target
identity checks. This is a host packaging gate, not evidence of installation
on the board.
