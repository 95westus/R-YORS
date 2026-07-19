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
HIMON AP service vector   $7E2D-$7E2E
global symbols            $40 / 64
fixups                    $80 / 128
relocations               $10 / 16
exports                   $08 / 8
imports                   $08 / 8
report refs               $C0 / 192
locals per global scope   $10 / 16
local visible chars       15
```

## OIL Boundary

ASM creates the AP object. The **Overlay Integration Layer** takes over when
that object is stored, loaded, relocated, linked to resident imports, and run.

```mermaid
flowchart LR
    SOURCE[ASM Source] --> ASM[ASM]
    ASM --> SEAL[SEAL / PACKAGE]
    SEAL --> AP[AP Object]
    AP --> OIL[OIL]
    OIL --> HIMON[HIMON Loader]
    OIL --> STR8[STR8 Bank Services]
    OIL --> RJOIN[RJOIN Imports]
    OIL --> RUN[Body Execution]
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
    SEALCLEAR["ASM_SEAL_CLEAR"]
    SEALCAP["ASM_SEAL_CAPTURE_END_FACTS"]
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
    CLEAR --> SEALCLEAR
    ENDASM --> SEALCAP
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
    EXPORT["ASM_EXPORT_SYMBOL"]
    IMPORT["ASM_IMPORT_SYMBOL"]
    ENTRY["ASM_EXPORT_SYMBOL / entry flag"]
    ORG["ASM_SET_PC_FROM_VALUE"]
    DB["ASM_EMIT_DB"]
    DW["ASM_EMIT_DW"]
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
    IMPORTFIX["ASM_FIX_IMPORT_RELOC_X"]
    RELOCNOTE["ASM_RELOC_NOTE_*"]
    RESOLVE["ASM_RESOLVE_FIXUPS_CURRENT"]
    PATCH["ASM_PATCH_FIXUP_X"]

    DISP --> BIND
    DISP --> EQU
    DISP --> EXPORT
    DISP --> IMPORT
    DISP --> ENTRY
    DISP --> ORG
    DISP --> DB
    DISP --> DW
    DISP --> DS
    DISP --> EMIT

    EQU --> EXPR
    ORG --> EXPR
    DB --> EXPR
    DW --> EXPR
    DS --> EXPR

    EMIT --> CLASS
    EMIT --> FINDOP
    EMIT --> BYTE
    EMIT --> WORD
    EMIT --> FIXSTORE
    EMIT --> RELOCNOTE

    CLASS --> EXPR
    CLASS --> LOOKUP
    CLASS --> RESIDENT
    CLASS --> FIXPLAN

    FIXSTORE --> FIXNAME
    FIXSTORE --> IMPORTFIX
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

## Seal Package And AP Flow

```mermaid
flowchart TD
    ENDASM["ASM_END"] --> CAPTURE["ASM_SEAL_CAPTURE_END_FACTS"]

    SEALCMD["SEAL command"] --> FNV["ASM_SEAL_COMPUTE_FNV"]
    FNV --> VALIDATE["ASM_SEAL_VALIDATE"]
    FNV --> HASHBODY["ASM_FNV_SCAN_SEAL_LEN"]
    FNV --> EXPREC["ASM_EXPORT_BUILD_RECORD"]
    FNV --> IMPREC["ASM_IMPORT_BUILD_RECORD"]
    FNV --> RESIMP["ASM_SEAL_RESOLVE_IMPORTS"]

    PACKAGECMD["PACKAGE command"] --> PACKAGE["ASM_SEAL_PACKAGE"]
    PACKAGE --> FNV
    PACKAGE --> LAYOUT["ASM_PACKAGE_COMPUTE_LAYOUT"]
    PACKAGE --> WRITEPKG["ASM_PACKAGE_WRITE"]
    PACKAGE --> VERIFYPKG["ASM_PACKAGE_VERIFY_BODY"]

    LOADCMD["LOAD command"] --> LOADPKG["ASM_PACKAGE_LOAD"]
    LOADPKG --> PARSEPKG["ASM_PACKAGE_PARSE_MIN"]
    LOADPKG --> APVEC["HIMON AP service $7E2D-$7E2E"]
    APVEC --> HIMAP["HIM_AP_SERVICE"]
    HIMAP --> HIMLINK["HIM_AP_IMPORT_LINK"]
    F006["STR8 $F006 compatibility doorway"] --> APVEC

    INSTALLCMD["INSTALL command"] --> SUGGEST["ASM_PACKAGE_INSTALL_SUGGEST"]
    SUGGEST --> PARSEPKG
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
IMPORT forces a deferred import fixup even when the same name is resident and
RJOIN-callable; plain undeclared resident operands still bind immediately.
SEAL builds the seal, relocation, export, and import records. PACKAGE writes
the AP envelope. LOAD delegates package consumption and resident RJOIN import
linking to the resident HIMON AP service. STR8 `$F006` remains only as a stable
compatibility doorway into the same service.
Default flash ASM leaves detailed table reporting to the external
asm-session-report proof; locals remain intentionally outside global
report/export names.
```
