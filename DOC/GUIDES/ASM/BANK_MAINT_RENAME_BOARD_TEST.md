# Bank Maintenance Directory Rename

Status: host-built; board proof pending.

Use this exact onboard source:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\str8n-v1.23-bank-maint-menu-2000.a
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

