# Expression Math Board Test

Purpose: prove the host-proven `+`/`-` expression-math slice on the board with
a pasteable ASM-native source file. This is not a new expression-feature test:
`|`, `&`, and `^` remain deferred.

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
paste DOC/GUIDES/ASM/SAMPLES/expr-math-7010.a
expect ASM RT PASTE OK
```

Assembly table sanity:

```text
OUT should be $7100
OUT1 should be $7101
OUT2 should be $7102
OUT3 should be $7103
BASE should be $0001
NEXT should be $0002
START_ADDR should be $7010
END_ADDR should be $701F
SIZE should be $000F
DATA should be $7025
final PC should be $7028
```

Emitted-byte oracle:

```text
>D 7010 7027
expect:
7010: A9 5A 8D 00 71 A9 02 8D | 01 71 A9 00 8D 02 71 A9
7020: 0F 8D 03 71 60 02 00 0F
```

Run it:

```text
>G 7010
expect HIMON return
```

Runtime oracle:

```text
>D 7100 7103
expect:
7100: 5A 02 00 0F
```

Accepted hardware proof:

```text
HIMON V 00.0615(2131)
ASM FLASH
source accepted through END at PC=$7028
SIZE table value: $000F
DATA table value: $7025
fixups: none
G 7010 returned A=$0F
D 7000 FF showed:
7010: A9 5A 8D 00 71 A9 02 8D | 01 71 A9 00 8D 02 71 A9
7020: 0F 8D 03 71 60 02 00 0F
D 7100 FF showed:
7100: 5A 02 00 0F 00 00 00 00 | 00 00 00 00 00 00 00 00
```

Accepted retest:

```text
HIMON V 00.0630(2008)
ASM FLASH
source accepted through END at PC=$7028
same table values and no fixups
G 7010 returned A=$0F
D 7000 71FF showed the emitted $7010-$7027 oracle and
7100: 5A 02 00 0F 00 00 00 00 | 00 00 00 00 00 00 00 00
```

The accepted transcript proves the assembly table values, generated code bytes,
selector bytes, normal return after executing the emitted program, and the
runtime oracle bytes at `$7100-$7103`.

What this proves:

```text
ORG expression:
  ORG $7000+16 starts the program at $7010

known-symbol math:
  OUT1/OUT2/OUT3 are derived from OUT with +1/+2/+3
  NEXT is derived from BASE+1

address deltas:
  SIZE is END_ADDR-START_ADDR = $000F

selector atoms:
  #<NEXT and #>NEXT emit $02 and $00
  DB <NEXT,>NEXT,SIZE emits 02 00 0F after the RTS
```

Hardware-proven negative check in a fresh paste session:

```text
        ORG $7000+16
        ORG $7000
```

Expected result:

```text
ERR=$06 BAD RANGE PC=$7010
```

Accepted hardware proof:

```text
HIMON V 00.0630(2008)
>ASM
ASM FLASH
ASM> ORG $7000+16
OK PC=$7010
ASM> ORG $7000
ERR=$06 BAD RANGE PC=$7010
```

The same cold-boot session also showed top-level `>ASM NEW` entering the flash
ASM wrapper and producing the same `ORG $7000+16` / backward-`ORG` result.

Notes:

```text
Do not use X EQU or Y EQU in this proof. A, X, and Y are reserved v1 register
words, not legal user symbols.

Do not rewrite this as STA OUT+1 yet. Mnemonic operand-tail math is still
future expression work; this proof deliberately stages address math through
EQU names.
```
