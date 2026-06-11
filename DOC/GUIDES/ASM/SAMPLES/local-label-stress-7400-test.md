# Local Label Stress Board Test

Purpose: prove local-label scope behavior with a compact pasteable program.
This is a local-label stress sample, not a resident/RJOIN sample.

Host preflight:

```text
make -C SRC asm-test
```

Load the current ASM runtime paste image:

```text
>L G
L S19
L @2000
send SRC/BUILD/s19/asm-v1-runtime-paste-2000.s19
expect ASM RT PASTE
```

Paste the program:

```text
paste DOC/GUIDES/ASM/SAMPLES/local-label-stress-7400.asm
expect ASM RT PASTE OK
```

Assembly table sanity:

```text
MAIN should be $7400
ONE should be $744D
TWO should be $7462
ALT should be $7477
final PC should be $7489
local labels should not appear in the global symbol table
fixups should be rows 00-0D, below the $18 table ceiling
```

Run it:

```text
>G 7400
expect HIMON return
```

Oracle:

```text
>D 7100 710C
expect:
7100: A1 B2 C3 D4 E5 F6 07 8F | 03 00 2A 03 5C
```

Hardware proof:

```text
The 2026-06-10 board proof accepted the source through ASM RT PASTE OK,
showed only MAIN, ONE, TWO, and ALT in the global symbol table, reported fixup
rows 00-0D, ran G 7400, and dumped the expected oracle bytes at $7100-$710C.
```

What this proves:

```text
MAIN scope:
  exactly eight local labels
  forward local branches through .A-.G and .ABCDEFGHIJKLMN
  .ABCDEFGHIJKLMN is 15 visible characters including the prefix

ONE/TWO scopes:
  .LOOP and .DONE names reused in separate global scopes
  backward local branches resolve inside each scope
  forward .DONE fixups resolve before the next global scope opens

ALT scope:
  ?NAME alternate local prefix
  forward ?FWD and backward ?LOOP references

Runtime oracle:
  $7100-$7107 prove the eight MAIN locals executed in order
  $7108=$03 proves ONE/.LOOP
  $7109=$00 and $710A=$2A prove TWO/.LOOP and TWO/.DONE
  $710B=$03 proves ALT/?LOOP
  $710C=$5C proves all subroutines returned to MAIN
```

Optional negative checks, each in a separate fresh paste session:

```text
; no active nonlocal scope
        ORG $7480
        BRA .MISS
expect BAD SYM

; unresolved local cannot cross into the next global scope
        ORG $7480
MAIN    BRA .MISS
NEXT    NOP
expect BAD FIX on NEXT
```
