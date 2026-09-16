# HIMON/AP evidence retained in Git - 2026-09-16

The dated HIMON/AP and APMAN evidence directories retain their original
manifests, receipts, source snapshots, and logs. Their tracked files preserve
exact bytes through `.gitattributes`; the original manifests are unchanged.

Generated firmware, linker maps, and binary board readbacks remain local
under the repository's existing ignore policy. Their original lengths and
SHA-256 values remain in the qualification manifests. The
[local-artifact inventory](HIMON_AP_LOCAL_ARTIFACTS_2026-09-16.json) identifies
these files explicitly: a source checkout alone does not contain every
artifact referenced by those manifests. Published releases are unchanged.

Two original transcripts used a Windows-reserved `com4.jsonl` basename.
Their original local files remain intact, with identical portable copies
tracked at these paths:

| Original local path | Portable tracked copy |
| --- | --- |
| `HIMON_AP_BASELINE_2026-09-16/com4.jsonl` | [HIMON_AP_BASELINE_2026-09-16.jsonl](HIMON_AP_BASELINE_2026-09-16.jsonl) |
| `HIMON_AP_CHANGE_2026-09-16/com4.jsonl` | [HIMON_AP_CHANGE_2026-09-16.jsonl](HIMON_AP_CHANGE_2026-09-16.jsonl) |

Use the portable copy when checking either original transcript's manifest
hash on a fresh checkout. Later qualification cycles already use the
portable `serial-com4.jsonl` basename.
