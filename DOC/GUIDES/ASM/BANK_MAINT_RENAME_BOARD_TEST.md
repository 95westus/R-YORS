# Bank Maintenance Directory Rename

Status: current v1.34 procedure; a fresh proof of this exact rename operation
is not implied by the 2026-09-15 firmware release. Preserve the selected
directory identity and use the current STR8 release's qualification limits.

Use this exact onboard source:

```text
C:\SRC\STR8-N\tools\bank-maint\str8n-v1.34-bank-maint-menu-2000.a
```

At HIMON:

```text
ASM NEW
```

Send the complete `.a`. At `SEAL>` enter:

```text
.
G 2000
M
```

Require the intended D0-D3 row to be COMPLETE and at least one fully erased
non-role scratch sector in B0-B2. To rename D1 to `BASIC`, enter exactly:

```text
N
1
BASIC
RENAME D1 BASIC
```

Require `B3F REWRITE`, a displayed `SCRATCH Bn:s`, `BACKUP VERIFIED`, and
`OK`. Do not reset, use NMI, remove power, or interrupt the terminal after the
exact confirmation. Run `M` again and require only the selected five-character
description to change; type, seal, entry, journal, other directory rows, and
the erased scratch state must be unchanged.
