# STR8-N Integration Index

STR8-N v1.34 is maintained in the adjacent standalone `STR8-N` repository.
R-YORS owns no live STR8-N implementation source.

For current work:

- [Product Boundary](PRODUCT_BOUNDARIES.md) explains ownership and the checked
  artifact contract.
- [R-YORS Memory Map](../MEMORY/MEMORY_MAP.md) records the integrated address
  boundary.
- [R-YORS Operator's Guide](../OPERATORS_GUIDE.md) explains the different
  HIMON and STR8-N `L` behaviors and the current build/composition workflow.
- The standalone `STR8-N/docs/OPERATORS_GUIDE.md` is authoritative for flash
  installation, Bank Maintenance, top update, and directory refresh.
- The standalone `STR8-N/docs/TECHNICAL_GUIDE.md` is authoritative for the
  resident, worker, directory, ABI, and protected-sector layout.
- The [current release shelf](../../../RELEASE/README.md) provides the
  v1.34 ZIP with its BIN, migration kit, Bank Maintenance `.a`, operator
  and technical manuals, licensing, and verification tools. HIMON and ASM-F2
  are separate releases, each also containing the combined `8-E` S19.

The v1.22 hardware baseline accepted through 2026-08-18 includes the combined Bank
Maintenance menu, guarded `U` update with retained B1:F backup, full-bank
copy-plus-enrollment, metadata-only `D2` adoption followed by successful `J2`,
and physical-reset recovery. The observed non-R-YORS payload is called the
**factory onboard firmware** unless later artifact provenance identifies it
more specifically; operator directory labels beginning with `WDC` are not
identity proof. It is retained only as historical evidence.

The current lock pins the v1.34 top with resident `$F000-$FCF1`, 134 bytes
of growth margin, and worker `$FD78-$FFAF`. The standalone September 15
records accept guarded update, exact readback, physical/software reset,
console/BRK, HIMON/ASM, J3, power-cycle startup, NMI/IRQ, and worker
program/erase on the stated test sector. The complete factory migration also
passed: preserve stock B3 in B0, install the canonical top, publish
`D0 FF WDCV2`, prove selector `0` and `J0`, and return by physical RESET.
Those exact proof records are included in the STR8-N package. The integrated
HIMON loader calls the unchanged `$F009` `SR/02` record parser directly.

R-YORS subsequently installed and reset-tested HIMON `00.0915(2233)` and
ASM-F2 `00.0915(2243)` on that STR8-N baseline. Their current release stamp
is `00.0915(2324)`; host regression and timestamp-only equivalence qualify
the restamped images, which have not been reflashed. See the
[qualification record](../../../RELEASE/QUALIFICATION.json).

Files in this directory other than the boundary/index pages are retained
hardware proof and historical board procedures. Their artifact names,
addresses, and old R-YORS targets describe the exact image tested at that
time; they are intentionally not rewritten as current instructions.

The external ABI is imported from:

```text
STR8-N/BUILD/v1.34/include/str8n-public.inc
```

and locked by:

```text
R-YORS/SRC/INTEGRATION/str8n.lock.json
```
