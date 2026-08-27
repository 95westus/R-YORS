# R-YORS II In 63'ese

Status: concise technical summary recorded 2026-08-27 and accepted in
principle. This summarizes the formal
[R-YORS II self-building proposal](R_YORS_II_SELF_BUILDING_SYSTEM_PROPOSAL.md);
it does not independently freeze an ABI, command, format, or release.

```text
IMMEDIATE NEXT PROJECT = STOCK WDCMONV2 -> STR8-N -> R-YORS
BYTECODE / COMPILERS / VMS / REMOTE I/O = AGREED LATER DIRECTION
```

## $00 - The Call

```text
R-YORS II = EVOLUTION, NOT REWRITE

KEEP:
  STR8-N
  HIMON
  ASM-F2
  RJOIN/FNV32
  AP V2
  HARDWARE PROOF

CHANGE:
  HOST = TERMINAL + FILE DEVICE
  BOARD = PARSE + BUILD + TEST + INSTALL + RUN
```

R-YORS II is self-building when the host stores and transports source but does
not understand how to turn it into W65C02 code.

```text
HOST GET/PUT BYTES
BOARD #ISH/ASM/LINK/MAKE/FLASH
```

The host remains the archive, terminal, transcript recorder, comparison oracle,
and emergency bootstrap. It is not the required compiler, linker, image
composer, address allocator, or flash-policy owner.

## $01 - Reset And Banks

```text
RESET -> B3 STR8-N

B0  WDCMONv2/SPI retained stock guest
B1  generated or independent guest
B2  generated guest / test / recovery / managed objects
B3  STR8-N root + selected live payload
```

STR8-N is the narrow board BIOS:

```text
RESET
BANK SELECT
Jn HANDOFF
FLASH COPY/INSTALL/VERIFY
RECOVERY
```

STR8-N is not automatically the console, filesystem, character BIOS, compiler,
or application runtime. `#MAKE` selects those separately.

Bank 0 remains outside automatic catalog search and backup rotation while it
holds WDCMONv2. Under the proposed policy:

```text
$FFF2 = $A6
SEARCH B1/B2
SKIP B0
```

`J0`, BANKDUMP, CRC, explicit copy, and recovery still reach B0.

B0 is retained by role, not imprisoned forever:

```text
B0 ARCHIVE
  READ EXACT 32K
  EMIT BIN [+ S19]
  OPTIONAL GIBBERLINK TRANSPORT
  RECORD CRC/HASH + VECTORS + IMAGE ID
  ROUND-TRIP/COMPARE ARCHIVE

B0 RELEASE
  SHOW LOSS OF ONBOARD WDCMONv2 COPY
  REQUIRE EXPLICIT CONFIRM
  ERASE/VERIFY
  CHANGE BANK ROLE

B0 ENROLL
  BACKUP-ROTATION ROLE = SEPARATE CHOICE
  FNV/AP PROVIDER ROLE = SEPARATE CHOICE
  $FFF2=$A7 ONLY WHEN B0 IS A VALIDATED PROVIDER
```

BIN is the canonical exact-bank archive. S19 is a useful record form.
`GIBBERLINK` is a candidate transport; it still carries checked bytes and must
not become the only surviving representation.

## $02 - Stock Board Ramp

Candidate RAM application:

```text
wdcmonv2str8n.asm
```

Provisionally also called `wdcmonv2ryors.asm`, it runs under stock WDCMONv2:

```text
1  HOST: $0C IDENTIFY, $02 LOAD, $03 BYTE-COMPARE, $06 RUN
2  INVENTORY B0-B3, NO WRITE
3  EXPORT B0+B3; HOST CHECKS S19/FNV/RESET/SHA
4  REFUSE UNLESS B0 ERASED OR BYTE-IDENTICAL TO B3
5  COPY B3 WDCMONv2 -> B0 WHEN ERASED
6  WHOLE-BANK FNV PREFILTER + BYTE-COMPARE B0
7  INSTALL STR8-N ONLY IN B3:F; B1/B2 UNTOUCHED
8  WRITE/VERIFY B3:F/VECTORS FROM RAM
9  RESET -> STR8-N; INSTALL R-YORS B3:8-E
10 J0 + HOST $0C PROVES STOCK BINARY WDCMONv2
```

The standalone STR8-N result is publishable without HIMON, AP, ASM-F2, or
`#ISH`. Authoritative converter source/releases belong in the standalone STR8-N
repository.

The migration top is deliberately unconfigured:

```text
$FFF0=$FF  NO WORK CLAIM
$FFF1=$FF  NO TOP-BACKUP CLAIM
$FFF2=$FF  NO AUTOMATIC EXTERNAL FNV/AP SEARCH YET
B1/B2      UNTOUCHED UNTIL OPERATOR CHOOSES
```

Bank Maintenance later inventories media, qualifies and verifies a backup,
then assigns the requested role bytes through a complete B3:F transaction.
Role assignment does not initialize a directory/VTOC, enroll catalog search,
or start backup rotation. Those remain separate operator choices.

THE KIT CONTAINS NO WDCMONV2 BYTES. OWNER-EXTRACTED WDCMONV2 BIN/S19 STAYS
LOCAL UNLESS WDC EXPRESSLY GRANTS REDISTRIBUTION.

`SXB/EDU` MEANS W65C02SXB ALONE OR WITH THE W65C02EDU EXPANSION INSTALLED.
W65C02EDU IS NOT A STANDALONE CPU BOARD AND DOES NOT CHANGE THE `SXB2` HOST
IDENTITY. ITS OPTIONAL PERIPHERALS ARE NOT PART OF THE MIGRATION ACCEPTANCE.

## $03 - If There Is No Guest Image

Do not stop at `SUPPLY 32K ROM`.

```text
#MAKE GUEST LAB1 BANK 1
  CPU W65C02
  CONSOLE FTDI
  IRQ SAFE
  NMI SAFE
  PIA ENABLE
  VIA ENABLE
  SPI VIA
  MONITOR MIN
ENDMAKE
```

SYSGEN produces:

```text
START/STACK INIT
RAM/ZP MAP
NMI/RESET/IRQ VECTORS
SAFE DEFAULT HANDLERS
SELECTED PIN/BIO ROUTINES
CONSOLE OR APP ENTRY
BUILD ID + RECIPE + MAP
32K CANDIDATE
CRC/VECTOR/SECTOR CHECKS
QUALIFICATION CARD
```

Selection is not proof. Diagnostics report observed facts:

```text
IRQ   OK COUNT=0004 RETURN=YES
PIA   OK DDR=READBACK PORTA=INPUT
VIA   OK T1=PASS IFR=PASS
SPI   OK DEV=SRAM SIZE=128K PATTERN=PASS
```

Never drive unknown pins or write unknown storage during a friendly probe.

Starter recipe direction:

```text
MINCON   VECTORS + FTDI + MEMORY/GO
LABIO    TIMER + PIA/VIA + INPUT
CONTROL  BOUNDED LOOP + SAFE OUTPUT + WATCHDOG HOOK
STORAGE  SPI + SRAM/SD READ/TEST
DEV65    HIMON + ASM-F2 + #ISH + FSEDIT + AP [+DEBUG]
RETRO    SMALL SUPPORT BED FOR ADAPTED GUEST
```

Goal:

```text
MINUTES TO FIRST USEFUL SYSTEM
NOT MONTHS TO FIRST CUSTOM ROM
```

## $04 - `#MAKE` Is SYSGEN

The family ladder is available, not mandatory:

```text
PIN -> APP
PIN -> BIO -> APP
PIN -> BIO -> SYS -> APP
PIN -> BIO -> COR -> SYS -> APP
STR8-N ONLY
```

Meanings:

```text
PIN  HARDWARE REGISTER/PIN/FIFO/SPI
BIO  BUFFER/STREAM/DEVICE BEHAVIOR
COR  SHARED RUNTIME MECHANISM
SYS  STABLE APPLICATION SERVICE
APP  PROGRAM/OPERATOR APPLICATION
MEM  OPTIONAL MEMORY OWNERSHIP SERVICE
```

`#MAKE` computes dependency closure, rejects conflicts, reports what it chose,
and omits unused wrappers. Names describe contract ownership, not required call
depth.

## $05 - First Build Loop

Shortest R-YORS II proof:

```text
HOST SEND PIN1.ISH
      |
      v
#ISH/ASM-F2 -> RAM $xxxx
      |
      v
EXPORT:
  PIN_PUT_CHAR
  PIN_GET_CHAR
  PIN_CHECK_CHAR
      |
      v
HIMON TEST/CALL
      |
      v
RC A=aa X=xx Y=yy P=pp C=c
MEMORY EVIDENCE
```

Contract for every callable routine:

```text
FNV32 NAME
KIND/ABI
ENTRY
IN  A/X/Y/C/MEM
OUT A/X/Y/C/P
CLOBBERS
BLOCK/NONBLOCK/TIMEOUT
RAM/ZP/I/O OWNERSHIP
TEST + ACCEPTED RESULT
```

Displayed registers are evidence. Only declared results are ABI.

## $06 - `#ISH`

`#ISH` is a visible-machine language above ASM. It may emit RYVM bytecode for
immediate verified execution or lower to native W65C02:

```text
A = $41
X = <BUFFER
Y = >BUFFER
CALL PIN_PUT_CHAR
IF NC BUSY
BYTE[$0200] = A
INSPECT $0200 $023F
RETURN
```

No hidden heap, scheduler, exception runtime, or accidental CPU model.

Prefer:

```text
TEXT -> NORMALIZE + FULL FNV32
     -> EXPLICIT SCOPE + EXACT COLLISION CHECK
     -> CHECKED SESSION TOKEN
     -> RYVM BYTECODE OR CALLABLE ASM-F2 EMITTER
```

Avoid:

```text
#ISH -> PRINT ASM TEXT -> REPARSE ASM TEXT
```

Assembly may ingest source once and leave forward fixups. A later large build
may ask the host to resend source for logical pass 2. Host storage does not make
the host the compiler.

```text
SYS_GET_CSTRING
IFT C SYS_PUT_CSTRING

BYTECODE: CALL GET; BRANCH C_CLEAR SKIP; CALL PUT
NATIVE:   JSR GET; BCC SKIP; JSR PUT
```

HIMON and ASM-F2 enter scope only when requested. A compiler may use them while
building without leaving them as runtime dependencies.

## $07 - FSEDIT

FSEDIT is the intended small onboard full-screen editor, in the operator style
of the System/34 POP utility:

```text
GET -> EDIT -> BUILD -> TEST -> EDIT -> PUT
```

Two different windows:

```text
DISPLAY WINDOW  TERMINAL ROWS x COLUMNS
FILE WINDOW     SOURCE BYTES/LINES IN RAM
```

They resize independently.

FSEDIT may be an AP stored in:

```text
RAM
VISIBLE/BANKED FLASH
HOST FILE STORE
SPI SRAM
SPI SD
```

Non-visible flash/SPI/host bytes are storage. Code must be loaded/relocated to
RAM unless a visible-flash execute-in-place contract applies.

Resident nucleus:

```text
SCREEN/CURSOR
COMMAND KEYS
FILE WINDOW
DIRTY STATE
BACKEND READ/WRITE
OVERLAY LOAD/RETURN
```

Optional overlays:

```text
SEARCH/REPLACE
HELP
BLOCK COPY/MOVE
LARGE LINE INDEX
DISPLAY ASSIST
```

Backend shape:

```text
OPEN
READ offset,length
WRITE offset,length
SIZE/TRUNCATE
COMMIT
CLOSE/ABANDON
```

Dirty text is never silently evicted.

```text
FSEDIT-0  ONE HOST FILE FITS IN RAM
FSEDIT-1  BOUNDED FILE WINDOW, RANGE GET/PUT
FSEDIT-2  AP + CODE OVERLAYS + VARIABLE RAM WINDOW
FSEDIT-3  SPI SRAM/SD + MORE BUFFERS/INDEX/UNDO
```

## $08 - Object Kinds

Do not make one envelope do every job:

```text
RAM TRIAL    FAST BUILD/TEST, SESSION OWNED
FNV32 HREC   NAME -> VALIDATED RESIDENT ENTRY
RYVM         VERIFIED MOVABLE BYTECODE + IMPORT INDEXES
AP V2        MOVABLE BODY + IMPORT/EXPORT + RELOCATION
IMAGE        SELECTED FIXED BOOTABLE 32K COMPOSITION
WORK         DISCARDABLE BUILD JOURNAL/SPILL
```

FNV is identity. AP is movement/lifecycle. IMAGE is composition.

SYSGEN may consume full AP metadata and emit less into a fixed image:

```text
KEEP AP       LOAD/MOVE/LINK LATER
STRIP TEXT    DROP DEBUG/TEXT, KEEP AP RUNTIME FACTS
BAKE          RESOLVE NOW; EMIT BODY + REQUIRED HREC/ENTRY/ABI ONLY
```

`BAKE` output is an image component derived from AP, not a secretly damaged AP.
Keep the canonical AP and an external/image build manifest containing source
identity, version, body check, layout, and stripped-field report. Never strip a
fact still required for runtime lookup, call, recovery, or rebuild.

```text
FOLD16 = INDEX ONLY
FNV32  = PUBLIC IDENTITY
CRC    = BYTE/BODY INTEGRITY
```

Automatic execution requires exactly one validated full-FNV candidate.

## $09 - RAM, WORK, And SPI

B1:E WORK is not required for the first PIN loop or FSEDIT-0.

Later WORK may hold:

```text
SESSION HEADER
SYMBOL/FIXUP SPILL
SOURCE CURSOR
LAYOUT RECORDS
SECTOR RECEIPTS
COMMIT-LAST JOURNAL ROWS
```

WORK is discardable, never the sole source or sole authoritative image.

Optional SPI SRAM may enlarge:

```text
FSEDIT FILE WINDOW
SOURCE/TOKEN CACHE
SYMBOL/FIXUP TABLES
OVERLAY STORE
LINK/IMAGE TABLES
RPG WORK RECORDS
```

SPI memory is explicit external memory through `PIN/BIO/MEM`; it is not
pretended to be directly addressed W65C02 RAM.

A second SXB/816 may be an optional I/O processor:

```text
MAIN SYS/BIO -> VERSION/SEQ/SERVICE/LEN/PAYLOAD/CRC -> I/O BOARD
I/O BOARD    -> SD / SRAM / TERMINAL / PRINTER / NET / SENSOR / SPOOL
```

Discover with full FNV32, bind a checked short service index, then transact.
LOCAL STR8-N RECOVERY AND A LOCAL CONSOLE DO NOT DEPEND ON THE SECOND BOARD.

Flash sizes have two meanings:

```text
$0100  LOGICAL PAGE: ALLOCATE / MOVE / DISPLAY / DIRTY MAP
$1000  PHYSICAL SST39 ERASE SECTOR

F      FLASH INSPECT/PLAN
FL#    PROPOSED LOGICAL PAGE SELECTOR, #=$00-$7F IN A BANK
```

For each proposed byte:

```text
OLD = FF          SIMPLE BYTE-PROGRAM CANDIDATE
OLD != FF, CHANGE STAGE/ERASE/REWRITE WHOLE 4K
NEW & ~OLD != 0   0->1 EXPLAINS WHY ERASE IS UNAVOIDABLE
```

Display OLD, NEW, 1>0 mask, 0>1 mask, and the resulting action before asking
for mutation. Bit feasibility is explanation, not authority to reprogram a
non-FF cell. `F` does not bypass protected-role, directory/VTOC, AP Store,
retained-WDCMONv2, or RAM-worker rules.

## $0A - Image Build

Build inactive, never grow the executing B3 image a piece at a time:

```text
PASS 1
  SELECT COMPONENTS
  DEPENDENCY CLOSURE
  ASSIGN ADDRESSES
  RESOLVE IMPORTS/FIXUPS
  REJECT OVERLAP/VECTOR/RAM CONFLICT

PASS 2
  FILL 4K RAM BUFFER
  OVERLAY BYTES FOR TARGET SECTOR
  APPLY FIXUPS
  CRC
  ERASE/PROGRAM/READBACK
  RECORD RECEIPT

ORDER
  SECTORS 8-E
  VERIFY
  SECTOR F/VECTORS LAST
  WHOLE BANK VERIFY
  Jn QUALIFY
  PROMOTE ONLY AFTER PROOF
```

Fixed spine:

```text
STR8-N
MINIMAL LOADER/SERVICE ROOT
VECTORS
IMAGE IDENTITY
```

Selectable:

```text
HIMON SHELL
ASM-F2
#ISH
FSEDIT
AP/OIL
DEBUG
PIN/BIO/COR/SYS FAMILIES
APPLICATIONS
```

## $0B - Safety Invariants

```text
B0 WDCMONv2 IS PROVEN BEFORE B3 SOURCE IS ALTERED
B3:F/VECTORS COMMIT LAST
UNKNOWN HARDWARE = REFUSE DESTRUCTIVE AUTO ACTION
NO FIRST-MATCH HASH EXECUTION
NO DIRTY EDIT WINDOW EVICTION
NO FLASH STREAM WRITE BEFORE COMPLETE PLAN
NO $100 LOGICAL PAGE CLAIMS A $100 PHYSICAL ERASE
NO CALL THROUGH A BANK SWITCH THAT UNMAPS THE CALLER
NO OPTIONAL MODULE CLAIM WITHOUT ITS COMMAND/HELP/RAM CONTRACT
NO Jn GUEST CLAIM WITHOUT VECTOR/CRC/HANDOFF QUALIFICATION
```

Bank worker shape:

```text
B3 CALLER -> RAM WORKER
RAM WORKER -> SELECT TARGET -> COPY/ERASE/PROGRAM/VERIFY
RAM WORKER -> RESTORE B3
RAM WORKER -> RTS TO B3 CALLER
```

The worker, its LED code, data, stack, and return state remain accessible while
the target bank is selected.

EDU warning LEDs may improve the operator gate:

```text
PREFLIGHT       NORMAL/OFF
ERASE/PROGRAM   FLASHING: DO NOT POWER OFF
VERIFY/RESTORE  FLASHING UNTIL SAFE BANK IS RESTORED
DONE            OFF/NORMAL + TEXT RESULT
FAIL            DISTINCT WARNING + TEXT RESULT
```

LED ownership must be a configured board capability and must not disturb guest
PIA/VIA state outside the destructive session contract. The LED is a warning,
not evidence. Only timeout checks and read-back/CRC/compare prove flash.

## $0C - Short Rail

```text
0   ACCEPT R-YORS II BOUNDARY
0A  NEXT: WDCMONv2 -> STR8-N -> R-YORS, PROVE J0 + C
1   HASH/SCOPE + RYVM CONTROL + NATIVE PIN FAMILY IN RAM
2   PIN/BIO/SYS + CALLABLE ASM EMITTER + NATIVE IFT PROOF
2A  FSEDIT-0 HOST-BACKED EDIT/BUILD LOOP
3   PACKAGE ONE FAMILY AS AP V2
4   #MAKE + INACTIVE-BANK IMAGE CANDIDATE
5   GUEST RECIPES + DEVICE/RECORD SERVICES
6   RPG II LANGUAGE PROCESSOR
```

Do not block `$01` with `$09` machinery.

## $0D - Long Direction

R-YORS II does not require a System/34 or System/360 emulator. It first grows
toward their useful system character:

```text
OPERATOR CONSOLE
LIBRARIES
NAMED ROUTINES
LOAD MODULES
SYSGEN/JOB CONTROL
RECORD I/O
BUILD/INSTALL HISTORY
RECOVERABLE GENERATIONS
RPG II
```

```text
FIXED RPG II ----+
FREE-FORM RPG ---+-> SHARED RPG CORE -> RYVM OR NATIVE W65C02

VIRTUAL 65C02    OPTIONAL DEBUG/GUEST AP
SYSTEM/360 VM    OPTIONAL LATER COMPATIBILITY AP
```

An S/360 subset needs 16 x 32-bit registers, PSW/CC, 24-bit guest addresses,
big endian, EBCDIC, packed decimal, interruptions, and channel I/O. SPI SRAM,
an 816, or a second controller may help. RPG DOES NOT WAIT FOR IT.

It becomes a living machine by accumulating validated routine versions, build
identities, device capabilities, guest recipes, qualification records, and
recoverable images—not by uncontrolled self-modification.

Final measure:

```text
TIME FROM STOCK SXB/EDU BOARD
TO A SAFE, USEFUL, CHANGEABLE SYSTEM
```
