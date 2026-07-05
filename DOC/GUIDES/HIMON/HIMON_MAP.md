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

## Edge Map

### Boot, Vectors, And Main Loop

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

    LOOP --> PROMPT[HIM_WRITE_HBSTRING]
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

```mermaid
flowchart TD
    DISPATCH[CMD_DISPATCH_HASH] --> HELP[? CMD_HELP]
    DISPATCH --> HASHINFO[# CMD_HASH_INFO]
    DISPATCH --> D[D CMD_D]
    DISPATCH --> S[S CMD_SEARCH]
    DISPATCH --> M[M CMD_M]
    DISPATCH --> R[R CMD_R]
    DISPATCH --> X[X CMD_X]
    DISPATCH --> G[G CMD_G]
    DISPATCH --> L[L CMD_L]
    DISPATCH --> B[B CMD_B]
    DISPATCH --> N[N CMD_N]
    DISPATCH --> Q[Q CMD_Q]

    HASHINFO --> HASHFIND[CMD_HASH_FIND]
    HASHINFO --> HASHLIST[CMD_HASH_LIST]
    HASHLIST --> HASHROW[CMD_HASH_PRINT_ROW]

    D --> RANGE[CMD_PARSE_RANGE_REQUIRED]
    D --> MEMPRINT[MON_PRINT_MEM_RANGE]
    S --> SPARSE[SEARCH_PARSE_RANGE]
    S --> SPATTERN[SEARCH_PARSE_PATTERN]
    S --> SSCAN[SEARCH_SCAN_RANGE]
    M --> RANGE
    M --> MEMMOD[MON_MODIFY_RANGE]

    R --> CTXREQ[MON_CTX_REQUIRE_VALID]
    R --> CTXPARSE[MON_CTX_PARSE_ASSIGN_LIST]
    R --> STOPREGS[MON_PRINT_STOP_AND_REGS]
    X --> CTXREQ
    X --> CTXPARSE
    X --> RESUME[MON_CTX_RESUME_RTI]

    G --> HEXWORD[CMD_PARSE_HEX_WORD_TOKEN]
    G --> SAVEENTRY[CMD_SAVE_ENTRY]
    G --> GOINDIRECT[indirect JMP to target]

    L --> LOADMAP[S19 loader map]
    B --> DBGMAP[breakpoint map]
    N --> STEPMAP[step map]
    Q --> QUIESCE[SEI / WAI / MON_REENTER]
```

### Loader And Flash Write Edges

```mermaid
flowchart TD
    L[CMD_L] --> ARGS[L, L G, or L F args]
    L --> READY[print ready]
    L --> READ[HIM_READ_LINE_UPPER]
    READ --> PARSE[L_PARSE_RECORD]

    PARSE --> S0[L_PARSE_S0]
    PARSE --> S1[L_PARSE_S1]
    PARSE --> S9[L_PARSE_S9]
    S0 --> SKIP[S0 skipped after checksum]
    S9 --> GOSAVE[LOAD_GO saved]

    S1 --> NOTE[L_NOTE_S1_ADDR]
    S1 --> WRITE[L_WRITE_DATA_BYTE]
    WRITE --> RAM{LOAD_FLASH_MODE?}
    RAM -->|no and dst < $8000| RAMWRITE[store to RAM]
    RAM -->|no and dst >= $8000| NEEDF[LOAD_FAIL_NEED_FLASH]
    RAM -->|yes| FLASHGATE[flash write gate]

    FLASHGATE --> PROTECT[protect below $8000 and at/above $D000]
    FLASHGATE --> OLD[read old byte]
    OLD -->|same| MATCH[L_WRITE_DATA_BYTE_MATCH]
    OLD -->|not $FF| ERASE[LOAD_FAIL_ERASE]
    OLD -->|$FF| FLASHWRITE[FLASH_WRITE_BYTE_AXY]
    FLASHWRITE --> VERIFY[read-back verify]
    VERIFY -->|ok| WROTE[LOAD_WRITE_OK]
    VERIFY -->|bad| WFAIL[LOAD_FAIL_WRITE]

    S1 --> CHK[L_VERIFY_CHECKSUM_EOL]
    L --> DONE[done status]
    L --> AUTOGO[optional auto-go]
```

Future loader direction: `L F` may grow an auto-place relocatable mode. In that
mode HIMON would first validate and measure the S19 image, find an erased block
inside the HIMON flash-load guard, rebase S-record addresses to the chosen
block, write/verify the relocated bytes, and report the selected base plus go
address. This is not current behavior, and it is not STR8 backup/restore or
protected-window update.

Relocation is deliberately narrow: plain S19 can be address-rebased, but it
does not describe absolute operands embedded inside code. A future auto-place
payload must be position-safe, rely on RJOIN/fixed external contracts, or carry
explicit relocation metadata from ASM or host tooling.

### Trap, Breakpoint, And Step Edges

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

    BRK[MON_BRK_TRAP] --> BRKSAVE[NMI_CTX_* save]
    BRK --> HANDLE[DBG_HANDLE_BRK]
    HANDLE --> STEPHIT[step BRK hit]
    HANDLE --> BPHIT[user breakpoint hit]
    HANDLE --> NONE[normal BRK]
    STEPHIT --> RESTORE[restore original opcode]
    BPHIT --> RESTORE
    RESTORE --> REENTER
    NONE --> SIG[TRAP_BRK_SIG capture]
    SIG --> REENTER

    CMD_B[B command] --> SET[DBG_SET_BP]
    CMD_B --> CLR[DBG_CLEAR_BP]
    CMD_B --> LIST[DBG_LIST_BP]
    SET --> FINDFREE[DBG_FIND_BP_FREE]
    SET --> FINDADDR[DBG_FIND_BP_ADDR]
    CLR --> FINDADDR
    LIST --> PRINT[SYS_WRITE_HEX_BYTE]

    CMD_N[N command] --> CTX[MON_CTX_REQUIRE_VALID]
    CMD_N --> STEP[DBG_STEP_ONCE]
    STEP --> OPLEN[DBG_OPCODE_LEN]
    STEP --> STEPINFO[DBG_PRINT_STEP_INFO]
    STEP --> FINDADDR
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
| Line input | prompt and loaders | `HIM_READ_LINE_ECHO_UPPER`, `HIM_READ_LINE_UPPER` | Blocking FTDI read, uppercases input, supports backspace, Ctrl-C abort, and NUL termination. | `L` uses non-echo upper input for S-record streams. |
| Hi-bit string output | all command messages | `HIM_WRITE_HBSTRING` | Writes high-bit terminated strings through FTDI. | Current compact text format for monitor messages. |
| FNV-era command hashing | every command token | `CMD_HASH_TOKEN`, `FNV1A_*`, `MATH_*` | Computes the current HIMON command hash and saves it in command exec state. | FNV32 remains the public command/export identity hash; CRC16 is for compact local/scoped tables and checks. |
| Catalog scan/dispatch | command execution | `CMD_DISPATCH_HASH`, `CMD_HASH_SCAN_*`, `CMD_HASH_RECORD_*`, `CMD_EXEC_ADDR` | Scans `$8000` through vector boundary for `FN(V\|$80)` records, matches hash, requires executable kind, calls entry. | Current record entry is immediate after kind byte. Future records can grow an explicit entry pointer. |
| Catalog inspection | `#`, `# token` | `CMD_HASH_INFO`, `CMD_HASH_LIST`, `CMD_HASH_FIND`, `CMD_HASH_PRINT_*` | Lists catalog records or shows one token hash/entry/kind. | This is the master runtime catalog view. |
| Quoted hash | `"text"` | `CMD_QUOTE_HASH`, `FNV1A_*` | Prints FNV-1a32 for text through the closing quote and reports STR8 match on `#5F6A0F7A`. | Input is uppercased by HIMON and leading/trailing spaces are trimmed. |
| Help | `?` | `CMD_HELP` | Prints current command list. | Help text includes built-in commands: `# ? S D M R X G L B N Q " STR8`. |
| Memory dump | `D [start [end|+count]]` | `CMD_D`, `CMD_PARSE_RANGE_REQUIRED`, `MON_PRINT_MEM_RANGE` | Prints hex rows plus printable ASCII, abortable with Ctrl-C. | Bare `D` repeats the previous dump length from the next address. |
| Memory search | `S start end\|+count bb\|'TEXT' [...]` | `CMD_SEARCH`, `SEARCH_PARSE_RANGE`, `SEARCH_PARSE_PATTERN`, `SEARCH_SCAN_RANGE` | Built-in K=$05 HIMON command; searches memory for mixed hex/text byte patterns, skips named `$7Fxx` I/O slots, reports `S NF` or `S ABORT`. | Token hash is `$D60C1322`; display text is `S: SEARCH FROM RAM TO HASHED HIMON CMD`. |
| Memory modify | `M start [end|+count]` | `CMD_M`, `MON_MODIFY_RANGE` | Prompts each byte, writes only below monitor workspace, `.` aborts. | Protected ranges from `$7A00` upward report `M PROT=$hhhh`; this is stricter than the hard `$7EFF` RAM ceiling. Current short mutator remains under review; future bulk fill should be `FILL start end|+count bb`, not an `M` subform. |
| Register display/edit | `R [regs]` | `CMD_R`, `MON_CTX_REQUIRE_VALID`, `MON_CTX_PARSE_ASSIGN_LIST`, `MON_PRINT_STOP_AND_REGS` | Requires trapped context, optionally updates A/X/Y/P/S/PC, then prints context. | Context comes from NMI/BRK capture; the active POC NMI vector eats bounce during a short software debounce window. |
| Resume trapped context | `X [regs]` | `CMD_X`, `MON_CTX_RESUME_RTI` | Requires context, optionally edits regs, rebuilds stack frame, then `RTI`s. | This is why HIMON must be disciplined about the hardware stack. |
| Go to address | `G start` | `CMD_G` | Parses address, saves exec entry, prints go address, jumps indirectly. | Return reporting only happens if called through command record or loader-go path. |
| Enter STR8 | `STR8` | `CMD_STR8_FNV` | Hash-record alias for `$F000`; confirms, then jumps into the resident STR8 entry without typing `G F000`. | Token hash is `$A2AD0E18`; kind is `K03`; display text is `STR8: BOOTLOADER`. STR8's separate identity marker remains `#5F6A0F7A`. |
| S-record load to RAM | `L` | `CMD_L`, `L_PARSE_RECORD`, `L_PARSE_S1`, `L_WRITE_DATA_BYTE` | Accepts S0/S1/S9, writes S1 data below `$8000`, tracks count and go address. | Loading to flash without `F` fails with `HINT L F`. |
| S-record load and go | `L G` | `CMD_L` | Same as `L`, then jumps to S9 address or first data address fallback. | Sets exec kind to LOADGO before jump. |
| S-record flash load | `L F` | `L_WRITE_DATA_BYTE_FLASH`, `FLASH_WRITE_BYTE_AXY` | Writes only blank `$FF` bytes in `$8000-$CFFF`, verifies readback, skips after first flash failure. | Protects HIMON fixed-entry area at `$D000+`; no sector erase yet. |
| Future relocatable flash placement | future `L F` mode | future loader staging and flash-block scan | Would measure a relocatable S19 image, choose an erased block, rebase record addresses, write/verify, and report relocated entry. | Not current behavior; plain S19 cannot patch absolute operands inside code without relocation metadata. |
| Breakpoint set/clear/list | `B start`, `B C start`, `B L` | `CMD_B`, `DBG_SET_BP`, `DBG_CLEAR_BP`, `DBG_LIST_BP` | Replaces target byte with `BRK` and stores original opcode in monitor workspace. | Patch targets are limited to user program RAM below `$7A00`, so monitor RAM and `$7F00-$7FFF` I/O stay protected. |
| BRK handling | BRK trap | `MON_BRK_TRAP`, `DBG_HANDLE_BRK` | Detects step breakpoint or user breakpoint, restores original opcode, rewinds PC to trapped opcode. | Plain BRK captures signature byte and re-enters monitor. |
| Single step | `N` | `CMD_N`, `DBG_STEP_ONCE`, `DBG_OPCODE_LEN`, `MON_CTX_RESUME_RTI` | Computes next PC by packed opcode length, prints mnemonic-only step diagnostics, plants a temporary BRK, resumes with `RTI`. | Temporary trap targets use the same patchable-RAM guard as `B`; monitor RAM and I/O are not patched. |
| Flash ASM | `ASM` when the flash ASM image is present | flash-resident FNV record | Enters the ASM v1 source-line assembler loaded by `L F`. | The legacy HIMON `A` mini-assembler has been removed from the core. |
| Quiesce | `Q` | `CMD_Q` | Executes `SEI`, `WAI`, then re-enters HIMON. | IRQ wakes cleanly to monitor re-entry; NMI still follows the trap path through the debounce POC vector. |
| Loaded-language bridge I/O | map-patched call addresses | `BIO_FTDI_READ_BYTE_BLOCK`, `BIO_FTDI_WRITE_BYTE_BLOCK` | Local composite images may patch direct calls from the current HIMON map. | Not a stable fixed-address ABI; rebuild patches must track the map. |
| Loaded-language return | `$8000` handoff for current composites | `START` | Re-enters HIMON through its reset/monitor entry. | A cleaner app-return contract is future work. |

## Edge Evidence Rules

- Raw edge truth stays in `HIMON_EDGE_DUMP.md`.
- This map may collapse many repeated print edges into one package edge.
- Indirect targets such as `CMD_CALL_ADDR`, `G`, and `L G` are intentionally
  shown as indirect because the concrete target is runtime data.
- Relative branches and fallthrough are control-flow facts, but not direct call
  edges. They are described only when they explain capability behavior.
- Include files are part of the HIMON capability surface even when the raw
  source line lives outside `himon.asm`.
- Debug is a HIMON subsystem/include. A small build may omit it to save flash,
  but the related command records, help text, BRK hook behavior, and build docs
  must be omitted or revised together. NMI trap capture may remain without the
  breakpoint/`N` stepping subsystem.
