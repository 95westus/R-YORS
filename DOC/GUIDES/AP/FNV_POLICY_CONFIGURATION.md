# FNV policy and configuration prerequisites

The authoritative byte-by-byte reference is maintained by STR8-N in
`docs/CONFIGURATION_BYTES.md` and included in its release and migration ZIPs
as `DOC/CONFIGURATION_BYTES.md`. It covers `$FFF0-$FFF9`, adjacent directory
records/journals, vectors, all policy values, and safe update prerequisites.

For this workbench, read these CPU addresses only with Bank 3 selected:

| Byte | Verified value | Prerequisite / consequence |
| --- | --- | --- |
| `$FFF0` | `$FF` | No flash WORK; does not allocate RAM or SPI storage |
| `$FFF1` | `$2F` | B2:F reserved for raw B3:F backup, not an AP carrier; verify the actual backup generation |
| `$FFF2` | `$A6` | B1/B2 eligible; B0 excluded; matching HIMON plus AM03 at B2:8 required |
| `$FFF3-$FFF9` | Erased | Unassigned; do not invent flags or use as scratch |

Decode `$FFF2` with `(byte & $F8) == $A0`; otherwise allow no banks.
For a valid byte, low bits 0/1/2 allow B0/B1/B2. `$A0` allows none;
`$A1/$A2/$A4` allow B0/B1/B2 respectively; `$A3/$A5/$A6` allow B0+B1,
B0+B2, B1+B2; `$A7` allows all three. `$FF` is disabled, not all enabled.
Effective target scope is requested mask AND allowed mask.

Manager bootstrap also obeys the allowed mask. With AM03 only at B2:8,
B1-only `$A2` cannot bootstrap it. Automatic resident misses need a nonzero
policy and compatible manager before AM03 considers RAM `$3000-$3FFF`;
there is no RAM-only policy encoding. Resident hits keep precedence.
The policy is not a security boundary or permission to write flash.

The current pair is HIMON `00.0916(1949)` plus AM03 loaded at `$6C00`.
Its BODY is 4017 bytes through `$7BB0`; the whole `$6C00-$7BFF` tray is owned
while active. Do not substitute old AM02 at `$7000`. Follow the
[RAM ownership contract](HIMON_AP_SCOPED_RAM_CONTRACT.md) and
[current integration record](AM03_RESIDENT_INTEGRATION_2026-09-16.md).
HREC metadata inspection and deferred SPI support are not enabled by policy.

Ordinary STR8 top update preserves the directory but installs candidate
configuration: the canonical candidate resets `$FFF2` to `$FF`. Recheck policy
after updates. The STR8-iN/65 `F` editor uses a verified temporary erased,
non-role scratch sector, changes only the live policy byte through a full
guarded B3:F rewrite, and erases scratch after success. Its blank value defaults
to A6; exact `FLAGS xx` confirmation is still required. It does not validate
the HIMON/manager pair. Never reuse an older frozen policy image over changed
STR8 firmware or patch these flash bytes with monitor memory commands.

Physical RESET, all three post-reset handoff checks and exact 32-sector
readback pass for the current pair; see the
[accepted correction and reset evidence](../LOGS/AM03_BOARD_2026-09-16/HANDOFF_CORRECTION.md).
Successful automatic handoff is silent, not a `GO` banner. No additional
board write is required merely to document these settings.
