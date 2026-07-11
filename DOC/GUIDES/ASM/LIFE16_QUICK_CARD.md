# ASM-F2 Life16 Bank 2 Quick Card

Use this card at the board. The complete explanation is in
[LIFE16_BANK2_EXAMPLE.md](LIFE16_BANK2_EXAMPLE.md).

This procedure has one address path:

```text
PACKAGE buffer  $3200 RAM
banked envelope B2:$9000 flash
run destination $3000 RAM
```

Do not substitute the session reporter's `$8000` or `$4800` addresses.

## 1. Reach HIMON

Start only when the board shows the HIMON prompt:

```text
>
```

If the prompt is `STR8-N>`, finish or abort that STR8 operation and enter HIMON
before continuing. Do not paste ASM source at a `STR8-N>` prompt.

## 2. Assemble And Package Life

```text
>ASM NEW
```

Paste `DOC/GUIDES/ASM/SAMPLES/life16-column-2000.a`. After `END`:

```text
ASM OK
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$01DE
SEAL> .
ASM BYE
>D 3200 5
3200: 41 50 01 DE 01
```

Stop if the header is not `41 50`, the AP version is not `01`, or the current
Life package length bytes are not `DE 01` for printed length `$01DE`. From this
point until the bank writer finishes, `$3200` is the package buffer. Do not run
`AP`, `LOAD`, or another `PACKAGE`; any of them can invalidate the package that
the writer is about to copy.

## 3. Store It At B2:$9000

```text
>ASM NEW
```

Paste `DOC/GUIDES/ASM/SAMPLES/bankput-3000.a`. After `END`:

```text
ASM OK
SEAL> .
ASM BYE
>G 3000
RET A=AC ...
>D 1A00 1
1A00: AC
```

Stop if `G 3000` does not return `A=AC` or `$1A00` is not `$AC`. In particular,
`$E2` means the AP package at `$3200` was no longer valid.

## 4. Run Life

```text
>AP B2 $9000 $3000
```

Life prints generations `G0` through `G6`. Then verify:

```text
>D 5848 5849
5848: AC 06
```

`$AC` is the completion marker and `$06` is the last generation. On later
boots, while the banked package remains intact, rerun it with only:

```text
>AP B2 $9000 $3000
```
