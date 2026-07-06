# ASM Call Map

This is the hand-maintained routine-flow map for `SRC/ASM/asm-v1-core.asm`.
It is meant to be useful in review: small enough to render, broad enough to
show where a change lands. For the design contract, read
[HASHED_ASM.md](HASHED_ASM.md). For test gates, read
[TEST_PLAN.md](TEST_PLAN.md).

Current proof shape:

```text
runtime paste entry       $2000
smoke output target       $7000
protected ASM/RJOIN seed  $7E00-$7E01
global symbols            32
fixups                    24
report refs               64
locals per global scope    8
local visible chars       15
```

## Primary Flow

```mermaid
flowchart TD
    START["START smoke runner"]
    REPL["ASM_REPL paste/console"]
    BEGIN["ASM_BEGIN"]
    ENDASM["ASM_END"]
    RJOIN["ASM_RJOIN_INIT"]
    RJIO["ASM_RJOIN_INIT_IO"]
    CLEAR["ASM_CLEAR_SESSION"]
    READ["ASM_RJ_READ_CSTRING"]
    WRITE["ASM_RJ_WRITE_*"]
    LINE["ASM_ASSEMBLE_LINE"]
    SAVE["ASM_LINE_SAVE"]
    ROLL["ASM_LINE_ROLLBACK"]
    LEX["ASM_LEX_LINE"]
    TOK["ASM_NEXT_TOKEN"]
    HEAD["ASM_PARSE_HEAD"]
    DISP["ASM_DISPATCH_STATEMENT"]
    REPORTFAIL["ASM_REPORT_PRINT_FAIL_IF_NEEDED"]
    REPORTEND["ASM_REPORT_PRINT_END_IF_NEEDED"]

    START --> RJOIN
    START --> BEGIN
    START --> LINE
    START --> ENDASM

    REPL --> RJIO
    REPL --> BEGIN
    REPL --> READ
    REPL --> LINE
    REPL --> WRITE

    BEGIN --> RJOIN
    BEGIN --> CLEAR
    ENDASM --> REPORTEND

    LINE --> SAVE
    LINE --> LEX
    LINE --> HEAD
    LINE --> DISP
    LINE --> ENDASM
    LINE --> ROLL
    LINE --> REPORTFAIL

    LEX --> TOK
    HEAD --> TOK
```

## Statement Flow

```mermaid
flowchart TD
    DISP["ASM_DISPATCH_STATEMENT"]
    BIND["ASM_BIND_LABEL"]
    EQU["ASM_DEFINE_EQU"]
    ORG["ASM_SET_PC_FROM_VALUE"]
    DB["ASM_EMIT_DB"]
    DS["ASM_EMIT_DS"]
    EXPR["ASM_PARSE_EXPR"]
    CLASS["ASM_CLASS_OPERAND"]
    EMIT["ASM_EMIT"]
    FINDOP["ASM_FIND_OPCODE"]
    BYTE["ASM_EMIT_BYTE"]
    WORD["ASM_EMIT_WORD_LE"]
    LOOKUP["ASM_LOOKUP_SYMBOL"]
    RESIDENT["ASM_RJ_RESIDENT_XY"]
    FIXPLAN["ASM_CAPTURE_FIX_PLAN_CURRENT"]
    FIXSTORE["ASM_STORE_FIXUP_CURRENT"]
    FIXNAME["ASM_STORE_FIXUP_NAME_X"]
    RESOLVE["ASM_RESOLVE_FIXUPS_CURRENT"]
    PATCH["ASM_PATCH_FIXUP_X"]

    DISP --> BIND
    DISP --> EQU
    DISP --> ORG
    DISP --> DB
    DISP --> DS
    DISP --> EMIT

    EQU --> EXPR
    ORG --> EXPR
    DB --> EXPR
    DS --> EXPR

    EMIT --> CLASS
    EMIT --> FINDOP
    EMIT --> BYTE
    EMIT --> WORD
    EMIT --> FIXSTORE

    CLASS --> EXPR
    CLASS --> LOOKUP
    CLASS --> RESIDENT
    CLASS --> FIXPLAN

    FIXSTORE --> FIXNAME
    BIND --> RESOLVE
    EQU --> RESOLVE
    RESOLVE --> PATCH
```

## Local Label And Fixup Flow

```mermaid
flowchart LR
    GLOBAL["nonlocal PC label"] --> CLOSE["ASM_CLOSE_LOCAL_SCOPE"]
    CLOSE -->|no pending local fixup| OPENSCOPE["open/reset local scope"]
    CLOSE -->|pending local fixup| BADFIX["BAD FIX"]

    LOCALDEF[".NAME or ?NAME label"] --> BINDLOCAL["ASM_BIND_LOCAL_LABEL"]
    BINDLOCAL --> LOCALROW["local row"]
    BINDLOCAL --> RESOLVE["ASM_RESOLVE_FIXUPS_CURRENT"]

    LOCALREF[".NAME or ?NAME operand"] --> LOOKLOCAL["ASM_LOOKUP_LOCAL_SYMBOL"]
    LOOKLOCAL -->|found| VALUE["use scoped PC value"]
    LOOKLOCAL -->|miss| LOCALFIX["local fixup row"]
    LOCALFIX --> CLOSE
    RESOLVE --> PATCH["ASM_PATCH_FIXUP_X"]
```

## Edges To Remember

```text
ASM_BEGIN requires the HIMON RJOIN seed before opening a session.
ASM_ASSEMBLE_LINE is the transactional spine; line failure rolls back PC,
symbol, fixup, local, ref, and report cursors.
ASM_DISPATCH_STATEMENT owns top-level policy; classifiers should not decide
whether a token is a label.
Local labels are label-only PC aliases under the most recent nonlocal label.
Unresolved local fixups cannot cross into the next nonlocal scope.
Default flash ASM leaves detailed table reporting to the external
asm-session-report proof; locals remain intentionally outside global
report/export names.
```
