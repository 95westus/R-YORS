# R-YORS TODO

## Input Line Editor
- Add optional mode bits to the string-input editor so behavior is not all-or-none.
- Keep current wrapper compatibility, but extend mode flags for independent toggles:
  - `ECHO` on/off
  - `CASE_UPPER` / `CASE_LOWER`
  - `EDIT_KEYS` (BS/DEL in-line editing)
  - `ARROW_KEYS` (left/right movement)
  - `HISTORY_KEYS` (up/down routing hook)
- Ensure existing callers keep current behavior unless the new bits are explicitly enabled.
