# B3 Directory Reclaim

This compacts the Bank-3 directory journal in protected sector B3:F. It does
not erase B3:8-E. The guarded maintenance program requires a completely erased
scratch sector in B0-B2, verifies the temporary backup, rewrites and verifies
B3:F, and erases the scratch afterward.

## Exact source

```text
C:\SRC\STR8-N\tools\bank-maint\str8n-v1.32-bank-maint-menu-2000.a
```

## Load and run

At HIMON:

```text
ASM NEW
```

Send the exact `.a` above. At `SEAL>` enter:

```text
.
G 2000
```

At the bank-maintenance menu enter:

```text
M
```

Require Bank 3 and D3 to be reported correctly, and require at least one fully
erased sector (`E`) somewhere in B0-B2. Stop on any `ERR=` or unexpected map.

Then enter exactly:

```text
R
3
RESET J3
```

During `B3F REWRITE`, do not reset, use NMI, remove power, or interrupt the
terminal. Require:

```text
B3F REWRITE
SCRATCH Bn:s
TYPE RESET J3> RESET J3
BACKUP VERIFIED
 OK
```

Back at the menu, enter:

```text
M
```

Require D3's identity and entry address to be unchanged, its journal to be
`FCFFFFFF`, and the displayed scratch sector to be erased again. Then use the
menu's displayed quit key or Enter.
