# STR8-N Integration Index

STR8-N v1.29 is maintained in the adjacent standalone `STR8-N` repository.
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

The v1.22 hardware baseline accepted through 2026-08-18 includes the combined Bank
Maintenance menu, guarded `U` update with retained B1:F backup, full-bank
copy-plus-enrollment, metadata-only `D2` adoption followed by successful `J2`,
and physical-reset recovery. The observed non-R-YORS payload is called the
**factory onboard firmware** unless later artifact provenance identifies it
more specifically; operator directory labels beginning with `WDC` are not
identity proof. It is retained only as historical evidence. Version 1.29 is
the current host-qualified and factory-migration/quiet-start board-accepted
release. The integrated HIMON `00.0902(1707)` loader calls its `$F009`
`SR/02` record parser directly.

Files in this directory other than the boundary/index pages are retained
hardware proof and historical board procedures. Their artifact names,
addresses, and old R-YORS targets describe the exact image tested at that
time; they are intentionally not rewritten as current instructions.

The external ABI is imported from:

```text
STR8-N/BUILD/v1.29/include/str8n-public.inc
```

and locked by:

```text
R-YORS/SRC/INTEGRATION/str8n.lock.json
```
