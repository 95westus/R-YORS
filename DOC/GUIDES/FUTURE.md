# R-YORS Future Notes

Generated from current source scan on 2026-04-13 22:06:00 -05:00.

## Architecture Direction
- Preserve the layer ladder (PIN -> BIO -> COR -> SYS -> APP) as symbols and apps grow.
- Continue converging shared monitor/command behavior into reusable library exports where duplication is intentional and stable.
- Keep dual string-path support (CSTR and HBSTR) explicit at API boundaries to avoid ambiguity in app-level calls.

## Workflow Direction
- Keep STASH as the top-shelf lane for validated app entrypoints and use TEST as the proving lane before promotion.
- Keep SESH for rapid iteration, then promote through TEST into top-shelf (STASH) only after behavior is confirmed.
- Regenerate GUIDE docs automatically as part of build/doc workflows so cross-reference drift stays low.

## Scale Considerations
- Track growth of library exports (current unique count: 114) to avoid unbounded public surface area.
- Track routine duplication hotspots (current duplicate names: 17) as candidates for factorization or explicit variant naming.
- Track unresolved import debt (current count: 2) and keep STASH/TEST link surfaces explicit.
