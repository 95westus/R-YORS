# RAM AP and combined uniqueness proof — 2026-09-16

The existing-RAM AP validation/combined uniqueness slice is accepted as a
private, image-pinned metadata inspector. It does not add command dispatch,
link imports or execute providers. SPI SRAM and WORK allocation remain deferred.
See the [contract](../AP/RAM_AP_UNIQUENESS_2026-09-16.md).

The 476-byte transient occupies `$2000-$21DB`; binary SHA256:

`069fed2920c7f8a92193a6a6de8036458f36759690fff8cb35dc146da4971d5d`

Forty-three linked-byte host cases pass, covering envelope bounds, AP format,
BODY validation, identity/entry metadata, RAM/bank duplicates, masks and roles,
policy-independent RAM, B0 exclusion/enrollment, restore-error handling and RAM
revalidation failure. Read/write/execute guards enforce the declared boundaries.
The full `asm-test` regression includes this check and uses the installed
`HIMON_VISIBLE_STAMP='0915(2324)'` for reproducible firmware identities.

Eight drivers were rehearsed against the complete accepted board image before
COM4 use. Each board case loads and reads back its complete RAM image, reloads
the exact AM02 BODY after entering the driver, calls the inspector, compares
result bytes, then reads back the provider window unchanged. This avoids
retaining a manager overlay across monitor input, which owns overlapping RAM.

| Board case | Result |
| --- | --- |
| RAMTEST envelope ending exactly at `$4000` | unique RAM, `$AC` |
| RAM BANKDUMP plus installed B2:A BANKDUMP | duplicate `$D2`, count 2, no location |
| Corrupted RAM BANKDUMP BODY | unique B2:A, `$AC` |
| RAM disabled with matching RAM bytes present | unique B2:A, `$AC` |
| Sector mask excludes B2:A | unique RAM BANKDUMP, `$AC` |
| Two valid RAMTEST envelopes | duplicate `$D2`, count 2, no location |
| Forged RAM canonical name with BANKDUMP hash | unique B2:A, `$AC` |
| Unsupported RAM-window mask | `$D4`, no location |

No provider load/link/entry was performed. The banked result reports entry
offset zero and BODY length `$092C` for the real BANKDUMP carrier. Successful
RAM fixtures report their original envelope address and four-byte BODY length.
Failure clears all location/entry metadata. Every return is in Bank 3.

Complete before/final 128 KiB archives are identical to the preceding accepted
[RAM HREC board image](RAM_HREC_PROOF_2026-09-16.md):

`8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b`

Firmware, `$A6` policy, APTEST B2:9, BANKDUMP B2:A and both backups are unchanged.
No flash programming or new reset-dependent persistent change occurred.

The [evidence directory](RAM_AP_UNIQUENESS_2026-09-16/) retains source snapshots,
generated private addresses, linked artifacts, host/full-regression logs,
rehearsed RAM fixtures, raw serial, all board results and complete flash
archives. Its manifest hashes all retained evidence files. Export verification
checks the `.a`/`.s19`/`.bin` collection and records the proof's image pins.
An isolated stale-pin fixture also proves that export fails before writing any
private inspector artifact; the canonical build files were not modified.

Next gate: ownership and return paths across normal AP load/link and command
entry, including retirement/relocation of the `$2000` inspector. Resident-first
command behavior and the public request interface are not changed by this proof.
