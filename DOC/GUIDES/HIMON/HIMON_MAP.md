# HIMON Map

This is the human map for current HIMON. The raw edge list lives in
[HIMON_EDGE_DUMP.md](HIMON_EDGE_DUMP.md); this file groups those
edges into readable subsystems and capability surfaces.

Scope is the current HIMON build path:

```text
HIMON/himon.asm
HIMON/himon-debug.inc
HIMON/himon-disasm.inc
HIMON/himon-shared-eq.inc
```

Direct `JSR` and `JMP` edges are the hard evidence. Some package-to-package
arrows below are summaries so the map is readable.

## Top-Level Routine Guide

This first view describes the principal control routines in
`SRC/HIMON/himon.asm` and its active includes. Each node carries a real routine
label plus its top-level purpose. Arrows summarize the main control and service
routes; the smaller diagrams below and
[HIMON_EDGE_DUMP.md](HIMON_EDGE_DUMP.md) provide direct-edge detail.

```mermaid
flowchart TD
    RESET["START / HIMON_COLD_START / HIMON_WARM_START<br/>Choose cold or warm monitor entry and establish CPU/session state"] --> INIT["MON_START_INIT<br/>Initialize system services, vectors, boot state, and the monitor banner"]
    INIT --> LOOP["MAIN_LOOP<br/>Prompt, read one command line, normalize it, and start dispatch"]
    LOOP --> HASH["CMD_HASH_TOKEN<br/>Hash the command token with FNV-1a and preserve the lookup key"]
    HASH --> DISPATCH["CMD_DISPATCH_HASH<br/>Scan resident FNV records, resolve the command, and execute it"]

    DISPATCH --> LOAD["CMD_L<br/>Receive S19, enforce RAM/flash policy, verify records, and optionally run"]
    DISPATCH --> AP["CMD_AP<br/>Load an AP package from RAM or banked storage and transfer to its entry"]
    DISPATCH --> DEBUG["CMD_B / CMD_N<br/>Manage one-shot breakpoints and prepare one instruction step"]
    DISPATCH --> MEM["CMD_D / CMD_M / CMD_R / CMD_X / CMD_G<br/>Inspect memory/context, edit state, resume, or jump"]

    AP --> APSVC["HIM_AP_SERVICE<br/>Validate, parse, relocate, load, link, or suggest placement for an AP object"]
    APSVC --> LINK["HIM_AP_IMPORT_LINK<br/>Resolve AP imports through resident FNV records and patch relocation sites"]
    DEBUG --> CTX["MON_CTX_RESUME_RTI / DBG_HANDLE_BRK<br/>Restore saved context or capture a breakpoint/step stop"]

    JOIN["THE_JOIN_FIND / THE_JOIN_EXEC_XY<br/>Find or execute a resident callable FNV record by hash"] --> DISPATCH
    JOIN --> LINK
```

## OIL Subsystem Boundary

OIL means **Overlay Integration Layer**. This top-level view keeps the runtime
contract visible; the routine-level edge evidence remains below.

```mermaid
flowchart LR
    ASM[ASM] --> AP[AP Object]
    STORE[RAM / Visible Flash / Banked Flash] --> OIL[OIL]
    AP --> STORE
    HIMON[HIMON] --> OIL
    OIL --> LOAD[Load / Relocate]
    OIL --> STR8[STR8 Bank Services]
    OIL --> RJOIN[Resident Imports]
    LOAD --> RUN[Execution]
```

## Edge Map

### Boot, Vectors, And Main Loop

#### Reset And Service Initialization

```mermaid
flowchart TD
    START[START] --> COLD{reset signature valid?}
    COLD -->|no| CLEAR[MON_CLEAR_RAM]
    COLD -->|yes| INIT[MON_START_INIT]
    CLEAR --> INIT
    REENTER[MON_REENTER] --> INIT
    INIT --> SYSINIT[SYS_INIT]
    INIT --> FLUSH[SYS_FLUSH_RX]
    INIT --> VECNMI[SYS_VEC_SET_NMI_XY]
    INIT --> VECBRK[SYS_VEC_SET_IRQ_BRK_XY]
    INIT --> VECIRQ[SYS_VEC_SET_IRQ_NONBRK_XY]
    INIT --> BOOTLOG[MON_BOOTLOG_RESET]
    INIT --> BANNER[HIM_WRITE_HBSTRING]
    INIT --> STOPREGS[MON_PRINT_STOP_AND_REGS]
    INIT --> LOOP[MAIN_LOOP]
```

#### Prompt, Read, And Dispatch

```mermaid
flowchart TD
    LOOP[MAIN_LOOP] --> PROMPT[HIM_WRITE_HBSTRING]
    LOOP --> READ[HIM_READ_LINE_ECHO_UPPER]
    READ --> UPPER[HIM_CHAR_TO_UPPER]
    READ --> ADV[CMD_ADV_PTR]
    READ --> CRLF[SYS_WRITE_CRLF]
    LOOP --> HAVE[MAIN_HAVE_LINE]
    HAVE --> SKIP[CMD_SKIP_SPACES]
    HAVE --> PEEK[CMD_PEEK]
    HAVE --> HASH[CMD_HASH_TOKEN]
    HAVE --> DISPATCH[CMD_DISPATCH_HASH]
```

### FNV Catalog Dispatch

#### Token Hash And FNV Math

```mermaid
flowchart TD
    HASH[CMD_HASH_TOKEN] --> FNVINIT[FNV1A_INIT]
    HASH --> TOKENLOOP[CMD_HASH_TOKEN_LOOP]
    TOKENLOOP --> PEEK[CMD_PEEK]
    TOKENLOOP --> DELIM[CMD_IS_DELIM_OR_NUL]
    TOKENLOOP --> UPDATE[FNV1A_UPDATE_A]
    TOKENLOOP --> ADV[CMD_ADV_PTR]
    HASH --> SAVEHASH[CMD_SAVE_HASH]
    UPDATE --> MUL[FNV1A_MUL_PRIME]
    MUL --> COPY[MATH_COPY_HASH_TO_TERM]
    MUL --> SHLADD[MATH_SHLADD_TERM_N]
    SHLADD --> SHL[MATH_SHL_TERM_N]
    SHLADD --> ADD[MATH_ADD_TERM_TO_HASH]
    MUL --> ADD1[MATH_ADD_TERM1_TO_HASH3]
```

#### Catalog Scan And Execute

```mermaid
flowchart TD
    DISPATCH[CMD_DISPATCH_HASH] --> SCANINIT[CMD_HASH_SCAN_INIT]
    DISPATCH --> LOOP[CMD_DISPATCH_SCAN_LOOP]
    LOOP --> NEXTREC[CMD_HASH_SCAN_NEXT_RECORD]
    NEXTREC --> END[CMD_HASH_SCAN_END]
    NEXTREC --> ISREC[CMD_HASH_IS_RECORD]
    NEXTREC --> ADVREC[CMD_HASH_SCAN_ADV]
    LOOP --> MATCH[CMD_HASH_RECORD_MATCH]
    LOOP --> ISEXEC[CMD_HASH_RECORD_IS_EXEC]
    LOOP --> ENTRY[CMD_HASH_RECORD_ENTRY]
    LOOP --> SAVEENTRY[CMD_SAVE_ENTRY]
    LOOP --> EXEC[CMD_EXEC_ADDR]
    EXEC --> CALL[CMD_CALL_ADDR indirect JMP]
    EXEC --> RETPRINT[MON_PRINT_RET_AND_REGS]
    LOOP --> MISS[CMD_DISPATCH_SCAN_MISS]
    MISS --> PRHASH[MON_PRINT_HASH]
    MISS --> MAIN[MAIN_LOOP]
```

### Command Surface

#### Command Index

```mermaid
flowchart TD
    DISPATCH[CMD_DISPATCH_HASH] --> HELP[? CMD_HELP]
    DISPATCH --> HASHINFO[# CMD_HASH_INFO]
    DISPATCH --> D[D CMD_D]
    DISPATCH --> M[M CMD_M]
    DISPATCH --> R[R CMD_R]
    DISPATCH --> X[X CMD_X]
    DISPATCH --> G[G CMD_G]
    DISPATCH --> AP[AP CMD_AP]
    DISPATCH --> APS[APS CMD_APS]
    DISPATCH --> L[L CMD_L]
    DISPATCH --> B[B CMD_B]
    DISPATCH --> N[N CMD_N]
    DISPATCH --> Q[Q CMD_Q]
```

#### Hash And Memory Commands

```mermaid
flowchart TD
    HASHINFO[# CMD_HASH_INFO] --> HASHFIND[CMD_HASH_FIND]
    HASHINFO --> HASHLIST[CMD_HASH_LIST]
    HASHLIST --> HASHROW[CMD_HASH_PRINT_ROW]
    D[D CMD_D] --> DRANGE[CMD_D_PARSE_RANGE]
    D --> MEMPRINT[MON_PRINT_MEM_RANGE]
    M[M CMD_M] --> RANGE[CMD_PARSE_RANGE_REQUIRED]
    M --> MEMMOD[MON_MODIFY_RANGE]
```

#### Context And Go Commands

```mermaid
flowchart TD
    R[R CMD_R] --> CTXREQ[MON_CTX_REQUIRE_VALID]
    R --> CTXPARSE[MON_CTX_PARSE_ASSIGN_LIST]
    R --> STOPREGS[MON_PRINT_STOP_AND_REGS]
    X[X CMD_X] --> CTXREQ
    X --> CTXPARSE
    X --> RESUME[MON_CTX_RESUME_RTI]
    G[G CMD_G] --> HEXWORD[CMD_PARSE_HEX_WORD_TOKEN]
    G --> SAVEENTRY[CMD_SAVE_ENTRY]
    G --> GOINDIRECT[indirect JMP to target]
```

#### Loader, Debug, And Quit Commands

```mermaid
flowchart TD
    L[L CMD_L] --> LOADMAP[S19 loader map]
    B[B CMD_B] --> DBGMAP[breakpoint map]
    N[N CMD_N] --> STEPMAP[step map]
    Q[Q CMD_Q] --> QUIESCE[SEI / WAI / MON_REENTER]
```

### RAM Loader Edges

#### Receive And Record Types

```mermaid
flowchart TD
    L[CMD_L] --> ARGS[bare L only]
    L --> READY[print ready]
    L --> READ[HIM_READ_LINE_UPPER]
    READ -->|Ctrl-C| ABORT[return immediately to prompt]
    READ --> PARSE[L_PARSE_RECORD]
    PARSE --> S0[L_PARSE_RECORD_S0]
    PARSE --> S1[L_PARSE_RECORD_S1]
    PARSE --> S9[L_PARSE_RECORD_S9]
    S0 --> SKIP[S0 skipped after checksum]
    PARSE -->|fatal error| POISON[latch failure; suppress later S1 writes]
    POISON --> READ
    S9 --> END{failure latched?}
    END -->|no| ENTRYSAVE[entry saved and reported]
    END -->|yes| RETURN[return failure to HIMON prompt]
    ENTRYSAVE --> RETURN
```

#### Destination Policy

```mermaid
flowchart TD
    S1[L_PARSE_RECORD_S1] --> DECODE[decode complete record into FREE_BUF]
    DECODE --> CHECK[validate count, hex, checksum, and EOL]
    CHECK --> SPAN{nonempty span ends at or below $7A00?}
    SPAN -->|yes| NOTE[L_NOTE_S1_ADDR]
    NOTE --> RAMWRITE[copy validated bytes to RAM]
    SPAN -->|no| RAMPROTECT[LOAD_FAIL_PROTECT; quench through S9 or Ctrl-C]
```

#### Finish

```mermaid
flowchart TD
    S9[L_PARSE_RECORD_S9] --> CHECK[L_VERIFY_CHECKSUM_EOL]
    CHECK --> SAVE[save S9 entry]
    SAVE --> DONE[print L OK byte count and ENTRY]
    DONE --> PROMPT[return to prompt]
```

HIMON has no S19 flash-write or load-and-run form. Persistent installation and
flash policy belong to STR8-N; changes to that interface require a separate
review.

### Trap, Breakpoint, And Step Edges

#### NMI Paths

```mermaid
flowchart TD
    SETNMI[SYS_VEC_SET_NMI_XY] --> POC[MON_NMI_TRAP_DEBOUNCE]
    POC --> ACTIVE{debounce active?}
    ACTIVE -->|yes| RTI[ignore bounce / RTI]
    ACTIVE -->|no| NMISAVE[NMI_CTX_* save]
    NMISAVE --> DELAY[software debounce delay]
    DELAY --> REENTER[MON_REENTER]
    BASE[MON_NMI_TRAP baseline] --> BASESAVE[NMI_CTX_* save]
    BASESAVE --> REENTER
```

#### BRK Trap Path

```mermaid
flowchart TD
    BRK[MON_BRK_TRAP] --> BRKSAVE[NMI_CTX_* save]
    BRK --> HANDLE[DBG_HANDLE_BRK]
    HANDLE --> STEPHIT[step BRK hit]
    HANDLE --> BPHIT[user breakpoint hit]
    HANDLE --> NONE[normal BRK]
    STEPHIT --> RESTORE[restore original opcode]
    BPHIT --> RESTORE
    RESTORE --> REENTER[MON_REENTER]
    NONE --> SIG[TRAP_BRK_SIG capture]
    SIG --> REENTER
```

#### Breakpoint Command

```mermaid
flowchart TD
    CMD_B[B command] --> SET[DBG_SET_BP]
    CMD_B --> CLR[DBG_CLEAR_BP]
    CMD_B --> LIST[DBG_LIST_BP]
    SET --> FINDFREE[DBG_FIND_BP_FREE]
    SET --> FINDADDR[DBG_FIND_BP_ADDR]
    CLR --> FINDADDR
    LIST --> PRINT[SYS_WRITE_HEX_BYTE]
```

#### Single-Step Command

```mermaid
flowchart TD
    CMD_N[N command] --> CTX[MON_CTX_REQUIRE_VALID]
    CMD_N --> STEP[DBG_STEP_ONCE]
    STEP --> OPLEN[DBG_OPCODE_LEN]
    STEP --> STEPINFO[DBG_PRINT_STEP_INFO]
    STEP --> FINDADDR[DBG_FIND_BP_ADDR]
    STEP --> PATCH[patch temporary BRK]
    CMD_N --> RESUME[MON_CTX_RESUME_RTI]
```

### Debug Opcode Display Edges

```mermaid
flowchart TD
    CMD_N[N command] --> STEP[DBG_STEP_ONCE]
    STEP --> LEN[DBG_OPCODE_LEN]
    STEP --> INFO[DBG_PRINT_STEP_INFO]
    INFO --> MNEMID[ASM_OP_MNEM_ID]
    INFO --> PMNEM[DIS_PRINT_MNEM_ID]
```

The old resident `U` unassemble command has been removed. HIMON keeps the
compact opcode length and mnemonic data needed for `N` step diagnostics and
debug register dumps.

### External Boundary

```mermaid
flowchart TD
    HIMON[HIMON] --> SYS[SYS_INIT / SYS_FLUSH_RX / SYS_WRITE_* / SYS_VEC_SET_*]
    HIMON --> BIO[BIO_FTDI_*]
    HIMON --> FLASH[FLASH_WRITE_BYTE_AXY]
    HIMON --> DBGEXT[DBG_HANDLE_BRK in debug include]
    APP[loaded-language bridge] -.map-patched calls.-> BIO
    APP -.optional re-entry.-> START[START at $8000]
```

The old fixed HIMONIA entry slots at `$F00D`, `$FADE`, and `$FEED` have been
removed. Current local bridge builds may patch against `himon-rom-c000.map`, but
there is no promised fixed high-ROM ABI.

## Full Capability Map

Command-safety mandate: destructive commands require 4 or more characters.
Current short mutators are implementation debt until the command surface is
revised; new bulk mutation should use full words such as `COPY`, `FILL`,
`MOVE`, `FLASH`, `BACKUP`, `RESTORE`, and `ERASE`.

| Capability | User surface | Main labels | Current behavior | Notes |
| --- | --- | --- | --- | --- |
| Boot/re-enter monitor | reset, trap return, `$8000` handoff | `START`, `MON_REENTER`, `MON_START_INIT` | Owns hardware stack on entry, initializes system I/O, installs active vectors, enters prompt. | This is the normal HIMON path today. STR8 hands normal boot here. |
| Cold RAM clear | reset path | `MON_COLD_RESET`, `MON_CLEAR_RAM` | Clears RAM through `SYS_RAM_END` (`$7EFF`), then sets reset signature and starts monitor. | `SYS_IO_BASE` (`$7F00`) is the hard stop before memory-mapped I/O. |
| Vector/trap install | boot-time | `SYS_VEC_SET_NMI_XY`, `SYS_VEC_SET_IRQ_BRK_XY`, `SYS_VEC_SET_IRQ_NONBRK_XY` | Installs HIMON NMI, BRK, and IRQ handlers through system vector helpers. | STR8 should own physical vectors later, with HIMON installing active RAM vectors. |
| Line input | prompt, loaders, and ASM service vector | `HIM_READ_LINE_ECHO`, `HIM_READ_LINE_ECHO_UPPER`, `HIM_READ_LINE_UPPER` | Blocking FTDI read with exact-case echoed or uppercase modes, backspace, Ctrl-C abort, and NUL termination. | HIMON commands and `L` retain uppercase input; the ASM-facing vector uses exact-case echo so quoted source bytes survive. |
| Hi-bit string output | all command messages | `HIM_WRITE_HBSTRING` | Writes high-bit terminated strings through FTDI. | Current compact text format for monitor messages. |
| FNV-era command hashing | every command token | `CMD_HASH_TOKEN`, `FNV1A_*`, `MATH_*` | Computes the current HIMON command hash and saves it in command exec state. | FNV32 remains the public command/export identity hash; CRC16 is for compact local/scoped tables and checks. |
| Catalog scan/dispatch | command execution | `CMD_DISPATCH_HASH`, `CMD_HASH_SCAN_*`, `CMD_HASH_RECORD_*`, `CMD_EXEC_ADDR` | Scans `$8000` through vector boundary for `FN(V\|$80)` records, matches hash, requires executable kind, calls entry. | Current record entry is immediate after kind byte. Future records can grow an explicit entry pointer. |
| Catalog inspection | `#`, `# token` | `CMD_HASH_INFO`, `CMD_HASH_LIST`, `CMD_HASH_FIND`, `CMD_HASH_PRINT_*` | Lists catalog records or shows one token hash/entry/kind. | This is the master runtime catalog view. |
| PACK40 service | service vectors | `HIM_PACK40_ASCII_TO_CODE`, `HIM_PACK40_PACK3` | Converts ASCII to base-40 codes and packs three base-40 codes into the AP metadata word. | Published through `$7E1F-$7E22`; flash ASM calls this for IMPORT/EXPORT metadata so the encoder is not duplicated in low flash. |
| Help | `?` | `CMD_HELP` | Prints current command list. | Help text includes built-in commands: `# ? D M R X G AP APS L B N Q STR8`. |
| Memory dump | `D start [end]` | `CMD_D`, `CMD_D_PARSE_RANGE`, `MON_PRINT_MEM_RANGE` | Dumps one byte when `end` is omitted, or an inclusive absolute range when `end` is present. | Bare `D`, short relative end tokens, continuation, and byte/text search were removed in the resident-size pass. An explicit end must be greater than start; `$7F00-$7FFF` is still reported as I/O rather than read as ordinary RAM. |
| Memory modify | `M start [end|+count]` | `CMD_M`, `MON_MODIFY_RANGE` | Prompts each byte, writes only below monitor workspace, `.` aborts. | Protected ranges from `$7A00` upward report `M PROT=$hhhh`; this is stricter than the hard `$7EFF` RAM ceiling. Current short mutator remains under review; future bulk fill should be `FILL start end|+count bb`, not an `M` subform. |
| Register display/edit | `R [regs]` | `CMD_R`, `MON_CTX_REQUIRE_VALID`, `MON_CTX_PARSE_ASSIGN_LIST`, `MON_PRINT_STOP_AND_REGS` | Requires trapped context, optionally updates A/X/Y/P/S/PC, then prints context. | Context comes from NMI/BRK capture; the active POC NMI vector eats bounce during a short software debounce window. |
| Resume trapped context | `X [regs]` | `CMD_X`, `MON_CTX_RESUME_RTI` | Requires context, optionally edits regs, rebuilds stack frame, then `RTI`s. | This is why HIMON must be disciplined about the hardware stack. |
| Go to address | `G start` | `CMD_G` | Parses address, saves exec entry, prints go address, jumps indirectly. | Return reporting only happens if called through command record or loader-go path. |
| AP package run | `AP pkg dst` | `CMD_AP`, `HIM_AP_SERVICE` | Loads an AP v2 envelope from RAM, visible flash, or the supported banked-source path to `$2000-$4FFF`, applies internal/import relocations, then runs the executable `ENTRY` offset. | AP v2 validates typed exports/imports and supports 64 relocation rows. Installed lookup by package hash/name remains future catalog work. |
| AP Store inventory | provisional `APS` | `CMD_APS`, `HIM_APS_HEADER_READ_CODE`, `HIM_APS_CLASSIFY_HEADER` | Streams the 24 candidate headers in Banks 0-2, restoring Bank 3 before validating or printing each row. | Read-only host candidate. Uses `$0300-$032F` and `$7C00-$7C13`, never scans Bank 3, and does not infer that `HEADER-FF` means the full sector is erased. Final syntax awaits operator hardening. |
| Enter STR8 | `STR8` | `CMD_STR8_FNV` | Hash-record alias for `$F000`; confirms, then jumps into the resident STR8 entry without typing `G F000`. | Token hash is `$A2AD0E18`; kind is `K03`; display text is `STR8: BOOTLOADER`. STR8's separate identity marker remains `#5F6A0F7A`. |
| S-record load to RAM | `L` | `CMD_L`, `L_PARSE_RECORD`, `L_PARSE_RECORD_S1`, `L_VALIDATE_RAM_SPAN` | Accepts S0/S1/S9, validates each complete record before copying S1 data, tracks the byte count, and reports the S9 entry without executing it. A fatal error latches failure, suppresses later S1 writes, and quenches through S9 or Ctrl-C; earlier accepted records remain in RAM. | Every nonempty span touching `$7A00-$FFFF` reports `LERR=$02`; `L G` and `L F` are rejected by the bare-`L` grammar. |
| AP package service | service vector/request block | `HIM_AP_SERVICE`, `HIM_AP_PARSE_MIN`, `HIM_AP_LOAD_*`, `HIM_AP_IMPORT_LINK`, `HIM_AP_FIND_HOLE` | Parses AP v2 envelopes, loads BODY to `$2000-$4FFF`, resolves kind-matched RJOIN imports, applies internal/import relocation rows, derives the executable entry, and suggests erased flash holes. | Published through `$7E2D-$7E40`; flash ASM `LOAD`/`INSTALL` and HIMON `AP pkg dst` call this so AP package consumption and linking survive after ASM exits. AP v2 uses 16-bit section lengths and accepts 64 relocation/export/import rows. STR8 carries no AP/FNV linker code. |
| Breakpoint set/clear/list | `B start`, `B C start`, `B L` | `CMD_B`, `DBG_SET_BP`, `DBG_CLEAR_BP`, `DBG_LIST_BP` | Replaces target byte with `BRK` and stores original opcode in monitor workspace. | Patch targets are limited to user program RAM below `$7A00`, so monitor RAM and `$7F00-$7FFF` I/O stay protected. |
| BRK handling | BRK trap | `MON_BRK_TRAP`, `DBG_HANDLE_BRK` | Detects step breakpoint or user breakpoint, restores original opcode, rewinds PC to trapped opcode. | Plain BRK captures signature byte and re-enters monitor. |
| Single step | `N` | `CMD_N`, `DBG_STEP_ONCE`, `DBG_OPCODE_LEN`, `MON_CTX_RESUME_RTI` | Computes next PC by packed opcode length, prints mnemonic-only step diagnostics, plants a temporary BRK, resumes with `RTI`. | Temporary trap targets use the same patchable-RAM guard as `B`; monitor RAM and I/O are not patched. |
| Flash ASM | `ASM` when the flash ASM image is present | flash-resident FNV record | Enters the ASM v1 source-line assembler installed through the STR8-N persistent-image path. | HIMON `L` never writes flash. The legacy HIMON `A` mini-assembler has been removed from the core. |
| Quiesce | `Q` | `CMD_Q` | Executes `SEI`, `WAI`, then re-enters HIMON. | IRQ wakes cleanly to monitor re-entry; NMI still follows the trap path through the debounce POC vector. |
| Loaded-language bridge I/O | map-patched call addresses | `BIO_FTDI_READ_BYTE_BLOCK`, `BIO_FTDI_WRITE_BYTE_BLOCK` | Local composite images may patch direct calls from the current HIMON map. | Not a stable fixed-address ABI; rebuild patches must track the map. |
| Loaded-language return | `$8000` handoff for current composites | `START` | Re-enters HIMON through its reset/monitor entry. | A cleaner app-return contract is future work. |

## Size Evidence

2026-07-06 normal HIMON map after removing resident `S` and folding search into
`D`:

```text
CODE     $2192 /  8594
DATA     $05C4 /  1476
TOTAL    $2756 / 10070
_END_DATA = $E756
```

The previous resident-`S` map was about `$28A5` total, so this slice saves about
`$014F` / 335 bytes while adding D-local search, compacting I/O skip messages,
and adding a HIMON-local one-byte RX lookahead for abort polling.
`CMD_SEARCH_FNV`,
`CMD_SEARCH`, and `MSG_SEARCH_*` are absent from the normal HIMON map; `D`
search enters through `CMD_D_SEARCH_RANGE`.

2026-07-07 normal HIMON map after adding the resident AP package service:

```text
CODE     $27EB / 10219
DATA     $05C4 /  1476
TOTAL    $2DAF / 11695
_END_DATA = $EDAF
HIM_AP_SERVICE = $D6B2
AP service cells = $7E2D-$7E40
```

This consumes most of the previous HIMON-to-`$F000` gap, leaving `$0251` bytes
below the STR8 handoff line, but frees flash ASM by moving AP package
parse/load/suggest into resident monitor code.

2026-07-07 normal HIMON map after adding the resident hashed `AP pkg dst`
runner:

```text
CODE     $286E / 10350
DATA     $05D9 /  1497
TOTAL    $2E47 / 11847
_END_DATA = $EE47
CMD_AP = $C66D
HIM_AP_SERVICE = $D735
AP command hash = $3AD53794
AP service cells = $7E2D-$7E40
```

This leaves `$01B9` bytes below `$F000`. The command intentionally reuses the
resident AP `LOAD` service and does not add a package-name registry or ENTRY
export parser yet; v0 runs packages whose entry is at BODY offset zero.

2026-07-07 normal HIMON map after adding the resident PACK40 encode service
used by flash ASM:

```text
CODE     $2925 / 10533
DATA     $05D9 /  1497
TOTAL    $2EFE / 12030
_END_DATA = $EEFE
CMD_AP = $C681
HIM_PACK40_ASCII_TO_CODE = $D749
HIM_PACK40_PACK3 = $D789
HIM_AP_SERVICE = $D7EC
PACK40 service cells = $7E1F-$7E22
AP service cells = $7E2D-$7E40
```

This leaves `$0102` bytes below `$F000`. The PACK40 service only publishes the
two pure primitives flash ASM needs (`ASCII_TO_CODE` and `PACK3`); ASM still
owns symbol/name iteration and non-flash ASM builds keep their local PACK40
implementation.

2026-07-10 normal HIMON map after removing the resident `ASMREPORT` wrapped AP
runner and keeping the reporter AP out of Bank 3:

```text
CODE     $2A0B / 10763
DATA     $05D9 /  1497
TOTAL    $2FE4 / 12260
_END_DATA = $EFE4
CMD_AP = $C687
HIM_AP_SERVICE = $D88E
AP command hash = $3AD53794
AP service cells = $7E2D-$7E40
```

This leaves `$001C` bytes below `$F000`. The reporter AP is now a separate
Bank 0 package and Bank 3 keeps `$B969-$BFFF` as low-flash headroom after
ASM-F2.

2026-07-18 normal HIMON map after the resident-size pass and moving AP import
linking out of STR8-N:

```text
CODE     $2997 / 10647
DATA     $0596 /  1430
TOTAL    $2F2D / 12077
_END_DATA = $EF2D
CMD_AP = $C3B8
HIM_AP_SERVICE = $D5BF
HIM_AP_IMPORT_LINK = $DAEF
AP command hash = $3AD53794
AP service cells = $7E2D-$7E40
```

This leaves `$00D3` bytes below `$F000`. The size pass removed quoted hashing
and the resident `D` continuation/search forms, then used the released space
for HIMON-owned AP import linking. STR8 `$F006` remains stable but now contains
only a compatibility adapter into the resident AP service.

2026-08-14 accepted HIMON/AP v2 map used with ASM-F2 `00.0814(0654)`:

```text
CODE     $290A / 10506
DATA     $0527 /  1319
TOTAL    $2E31 / 11825
_END_DATA = $EE31
CMD_AP = $C3BF
HIM_PACK40_ASCII_TO_CODE = $D3A6
HIM_PACK40_PACK3 = $D3E6
HIM_AP_SERVICE = $D4AF
HIM_AP_IMPORT_LINK = $DC37
AP service cells = $7E2D-$7E40
```

This leaves `$01CF` bytes below `$F000`. The compiled host gate exercises all
64 AP v2 relocation rows and the second-page target lanes; installed-board
cards accept 64 exports, 64 imports, typed import matching, named package
identity, and relocated execution.

Current accepted HIMON/ASM-F2 `00.0814(1303)` map:

```text
CODE     $28A2 / 10402
DATA     $0512 /  1298
TOTAL    $2DB4 / 11700
_END_DATA = $EDB4
CMD_AP = $C387
HIM_PACK40_ASCII_TO_CODE = $D34E
HIM_PACK40_PACK3 = $D38D
HIM_AP_SERVICE = $D456
HIM_AP_IMPORT_LINK = $DBDB
AP service cells = $7E2D-$7E40
```

This leaves `$024C` bytes below `$F000`. The current board proof accepts the
same `1303` HIMON bytes in the standalone Bank-3 `8-E` payload and the final
STR8-N-composed image, including physical-reset persistence, the fixed `$C000`
head, ASM-F2 identity, and synthetic `J3` return.

Current 2026-08-19 case-preserving source-input host candidate:

```text
CODE     $28AA / 10410
DATA     $0529 /  1321
TOTAL    $2DD3 / 11731
_END_DATA = $EDD3
```

This leaves `$022D` bytes below `$F000`. The 31-byte growth supplies the
case-preserving echoed input entry and its resident `SYS_READ_CSTRING` record;
board acceptance is still pending.

## Edge Evidence Rules

- Raw edge truth stays in `HIMON_EDGE_DUMP.md`.
- This map may collapse many repeated print edges into one package edge.
- Indirect targets such as `CMD_CALL_ADDR` and `G` are intentionally
  shown as indirect because the concrete target is runtime data.
- Relative branches and fallthrough are control-flow facts, but not direct call
  edges. They are described only when they explain capability behavior.
- Include files are part of the HIMON capability surface even when the raw
  source line lives outside `himon.asm`.
- Debug is a HIMON subsystem/include. A small build may omit it to save flash,
  but the related command records, help text, BRK hook behavior, and build docs
  must be omitted or revised together. NMI trap capture may remain without the
  breakpoint/`N` stepping subsystem.
