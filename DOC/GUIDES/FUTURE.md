# R-YORS Future Notes

## Console Input Modes
- Move toward a unified, bitfield-driven input mode API for string reads.
- Treat editor capabilities as composable features instead of fixed routine variants.
- Suggested direction: keep per-call mode selection in register/input args (not global state), similar in spirit to terminal line-discipline configuration.

## Why
- Reduces routine proliferation.
- Lets apps choose only the behavior they need.
- Makes monitor/test tooling easier to evolve without breaking existing call sites.
