# QCC Memory

This page keeps memory and bit-helper questions in QCC form.

## Q: What are the current broad memory regions?

Comment:

```text
$0000-$7EFF  RAM
$7F00-$7FFF  IO
$8000-$FFFF  flash
```

Concern: A scanner must not treat all address ranges alike. RAM can be
temporary. IO can have side effects. Flash can be scanned safely but can only
be rewritten under erase/write rules.

## Q: Should HIMON have an extended flash address form?

Comment: Bare 16-bit addresses remain CPU-address-space addresses. `0000-FFFF`
is valid and means the currently visible 64K map. A future extended address
form could name physical flash directly with a bank prefix:

```text
01:0000
01:0000-01:FFFF
02:0000
03:FFFF
```

Depending on the final flash map, the valid extended range might stop at
`02:FFFF` or `03:FFFF`.

Good: A bank-prefixed form directly names physical flash and avoids confusion
about whichever bank is currently selected.

Bad: It adds parser size and forces every command to decide whether it accepts
CPU-visible addresses, physical flash addresses, or both.

Ugly: Direct physical flash syntax can make dangerous operations feel easy.
Any destructive command using this form must still obey the four-character
command mandate and should preserve or restore bank state.

Concern: Treat this as a grammar candidate, not a committed TODO. It probably
belongs first in read-only flash-aware commands, then only later in destructive
full-word commands after the bank numbering is settled.

## Q: Are 4K selectors useful?

Comment: Yes. A selector `0` through `F` can describe a full 4K sector:

```text
0 = $0000-$0FFF
1 = $1000-$1FFF
...
F = $F000-$FFFF
```

Concern: The high nibble of a selector is tempting for flags, but the cleanest
first meaning is address selection. Extra meanings should be carefully scoped
so scans stay obvious.

## Q: What zero page is user-stable?

Comment: The current policy leaves `$00-$AF` user/free while user code is
running. `$B0-$CC` is reserved for future R-YORS/HIMON/THE/ASM zero-page
workspace, especially active pointers needed for W65C02 addressing modes.

Concern: `$B0-$CC` may look free today because current live HIMON scratch starts
at `$CD`, but treating it as user-owned would make future pointer-lane work
harder to add safely.

## Q: Where does dynamic allocation belong?

Comment: For now, keep dynamic allocation conceptual. Future app/session heaps
can exist, but STR8 should stay fixed-buffer-oriented until a real reservation
is made.

Concern: A heap without a memory-map reservation becomes invisible ownership.
That is exactly the kind of thing recovery code should avoid.

## Q: Should there be a bit engine?

Comment: `TBE`, The Bit Engine, is a plausible convenience/helper family for
setting, resetting, testing, and branching on bits.

Concern: RAM bit helpers and flash bit helpers need different contracts.
W65C02S RAM helpers can use instructions such as `TSB`, `TRB`, `SMB`, `RMB`,
`BBS`, and `BBR`. Flash helpers must respect `1 -> 0` commit behavior and
sector erase rules.
