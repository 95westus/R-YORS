# Ideas

## UTL_PACK_3X5 / UTL_UNPACK_3X5

Pack three already-normalized 5-bit character codes into two bytes.

Bit layout:

```text
X:Y = 0aaaaabb bbbccccc
```

```text
bits 14..10 = char 1
bits  9..5  = char 2
bits  4..0  = char 3
bit 15      = 0
```

`UTL_PACK_3X5`:

```text
IN:
  A = char 1 code, already normalized to 0..31
  X = char 2 code, already normalized to 0..31
  Y = char 3 code, already normalized to 0..31

OUT:
  X = packed high byte
  Y = packed low byte
  C = clear on success, set on invalid input
```

`UTL_UNPACK_3X5`:

```text
IN:
  X = packed high byte
  Y = packed low byte

OUT:
  A = char 1 code, 0..31
  X = char 2 code, 0..31
  Y = char 3 code, 0..31
  C = clear on success, set if packed bit 15 is invalid/set
```

Callers choose the alphabet. For example, uppercase mnemonics can subtract
`'A'` before packing and add `'A'` after unpacking; lowercase can do the same
with `'a'`.
