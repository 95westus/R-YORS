# Scoped discovery: step-2 host gates

All requested host gates pass with build stamp `0915(2324)`. The rebuilt
HIMON/AM02 pair is byte-identical to the frozen step-1 recovery payloads.
The canonical top remains WORK=`$FF`, backup=`$2F`, policy=`$FF`.

| Gate | Result |
| --- | --- |
| Full `make -C SRC asm-test` | PASS |
| Board S19 payload identity | PASS, 9 targets |
| Policy/request combinations | PASS, 65,536 cases |
| Linked scoped integration | PASS, 59 cases |
| Maintenance role startup | PASS, 432 cases |
| Top updater backup and restore | PASS, 4 variants |
| Frozen step-1 recovery evidence | All 57 artifact hashes intact; prior 33 focused checks retained |
| RAM-transient export | 40 images; S19 checksums, BIN bytes, `.a` reconstruction, and manifest hashes agree |

HIMON occupies 12,280 bytes, ends at `$EFF8`, and has 8 bytes free. AM02 BODY
occupies 3,059 bytes, ends at `$7BF3`, and has 13 bytes free. No firmware source
change was needed for this validation pass. The build's incidental logo stamp
change was restored to the pre-build file.

Commands were `make -C SRC asm-test board-s19-check
HIMON_VISIBLE_STAMP='0915(2324)'`, STR8 `make bank-maint-role-check
top-backup-role-check`, and the RAM-transient exporter followed by exact
reconstruction/hash checks. See the [hashed evidence](SCOPED_HOST_GATES_2026-09-16/manifest.json)
for complete logs, linked maps, case reports, and frozen payloads.

This record covers host results only. The operator subsequently authorized
on-board smoke testing, including coordinated installation and `$A6`
provisioning. Board results must be recorded separately; these host results
do not close the broader malformed/duplicate or LED observation board gates.
