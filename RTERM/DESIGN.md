# RTERM Provisional Design

> **Draft, not set in stone.** This document records the current direction so
> it can be discussed, tested, and changed. It does not claim that RTERM has
> been implemented or that every described feature belongs in the first
> release.

## Purpose

RTERM is intended to be both:

1. a regular interactive serial terminal for R-YORS; and
2. an operator-aware terminal that can observe defined areas of its internal
   screen, recognize configured conditions, and invoke safe host actions.

The second role must not weaken the first. With screen rules disabled, RTERM
should behave like an ordinary VT102 serial terminal.

## Working Constraints

- Language: GNU C, initially targeting C17.
- Host: Ubuntu Linux, including Ubuntu under WSL.
- UI: ncurses is the current preferred implementation layer.
- Serial API: POSIX file descriptors and `termios`.
- Event handling: a small `poll()`-based event loop is preferred initially.
- Initial target geometry: 80 columns by 24 target-controlled rows.
- Host UI geometry: the target display plus one RTERM-owned OIA row.
- Initial terminal personality: DEC VT102.
- Future personality: DEC VT525/VT500-series, added without replacing the
  VT102 implementation.
- Initial transport: local serial devices such as `/dev/ttyUSB0`,
  `/dev/ttyACM0`, or `/dev/ttyS*`.

SSH, Telnet, TN3270, and TN5250 are not initial requirements. A future TCP or
pseudo-terminal transport should be possible without changing the screen and
terminal cores.

## Terminology

The following distinctions are important:

- **VT102** is the initial DEC escape-sequence terminal personality.
- **VT525** is a later DEC VT500-series personality and is mostly a superset
  direction for the parser and screen model.
- **IBM 3270/5250** are field-oriented block-terminal families. RTERM does not
  initially speak either IBM data stream.
- **OIA** is RTERM's host-owned Operator Information Area at the bottom of the
  UI.
- **DEC status line** is a target-controlled VT500-series display surface. It
  is not the RTERM OIA.
- **screen rule** is a host definition that observes cells or terminal state
  and can request a bounded action. No particular command spelling is built
  into this term.
- **console** is the primary human session that normally owns keyboard input.
- **subconsole** is an attached observer or operator session with explicitly
  granted capabilities.

## Operating Profiles

Three provisional profiles describe increasing amounts of host assistance:

| Profile | Behavior |
| --- | --- |
| `terminal` | Conventional serial terminal; screen actions disabled. |
| `assist` | Terminal plus configured screen rules and safe actions. |
| `console` | Assist mode plus messages, inquiries, SYSREQ, ATTN, and console/subconsole management. |

These are policy profiles, not different terminal parsers. VT102 versus VT525
is a separate terminal-personality choice.

Example command lines are illustrative only:

```text
rterm /dev/ttyUSB0
rterm -b 115200 /dev/ttyUSB0
rterm --profile ryors /dev/ttyUSB0
rterm --profile ryors-console /dev/ttyUSB0
```

## High-Level Architecture

```text
                         +-----------------------------+
serial RX -------------->| terminal parser             |
                         |   VT102 first                |
                         |   VT525 later                |
                         +--------------+--------------+
                                        |
                                        v
                         +-----------------------------+
                         | target screen model          |
                         | cells, attributes, modes,    |
                         | cursor, margins, charsets    |
                         +---+---------------------+---+
                             |                     |
                             v                     v
                    +----------------+     +----------------+
                    | ncurses UI     |     | screen rules   |
                    | main + OIA     |     | named regions  |
                    +-------+--------+     +-------+--------+
                            |                      |
keyboard -------------------+                      v
                                             +------------+
                                             | safe action|
                                             | dispatcher |
                                             +-----+------+
                                                   |
                                                   v
                         +-----------------------------+
serial TX <--------------| single serialized TX queue  |
                         | keys, replies, transfers     |
                         +-----------------------------+
```

Terminal replies, keyboard input, and file transfers must share one serialized
transmit path. Competing writers must never interleave bytes on the serial
connection.

The terminal display, field definitions, live form state, and screen rules are
separate layers:

```text
terminal screen       characters and attributes received from the target
layout/fields         named regions and their declared editing semantics
form instance         current local edits, field cursor, modified flags, errors
screen rules          observation and action policy
```

This separation permits an ordinary VT stream session, a field-assisted
session, and a locally buffered block-form session to share the same terminal
parser without teaching VT102 about IBM field semantics.

## Display and Operator Information Area

### VT102 UI

The baseline layout is:

```text
rows  1-24   target-controlled VT102 display
row      25  RTERM-controlled OIA
```

The OIA is outside the emulated target screen. It must not:

- be addressable by target cursor operations;
- be included in cursor position reports;
- be searched by target-screen rules;
- scroll with target output; or
- appear in a target screen capture unless explicitly requested as metadata.

An illustrative OIA is:

```text
C1  SA MW KS IM II KB   MAIN/CONSOLE   VT102  USB0 115200 8N1       12/37
```

Indicator positions should remain stable. Active indicators may be bright or
reverse video; inactive indicators may be blank or dim.

Provisional meanings are:

| Indicator | Meaning in RTERM |
| --- | --- |
| `SA` | System/session available according to the configured readiness policy. |
| `MW` | An unread operator or subconsole message is waiting. |
| `KS` | Keyboard-shift state, but only where the host input API can report it truthfully. |
| `IM` | Insert mode is active. |
| `II` | Input is inhibited by disconnection, transfer ownership, an error, or console policy. |
| `KB` | Keystrokes are buffered while input is inhibited. |
| `C1` | Main console/session identifier. |
| `S1` | Example subconsole identifier. |
| `rr/cc` | Target cursor row and column. |

Serial-open does not necessarily prove that the target is alive. Whether `SA`
means merely "port open," "recent target traffic," or a configured readiness
rule remains an open decision.

The center of the OIA can temporarily carry an operator message:

```text
C1  SA       II      SYSREQ> _
C1  SA MW            INQUIRY 0042 REPLY REQUIRED
C1  SA               ATTN SENT: BREAK
C1  SA       II      S19 117/384 RECORDS
C1                   SERIAL DISCONNECTED
```

### Future VT525 UI

A DEC VT525 can expose a target-controlled status line. That surface must not
be confused with or allowed to overwrite the RTERM OIA.

The full layout therefore requires one additional host row:

```text
rows  1-24   target-controlled main display
row      25  target-controlled DEC status line
row      26  RTERM-controlled OIA
```

When only 25 host rows are available, a compact mode may switch the last
physical row between the virtual DEC status line and the RTERM OIA. Both remain
separate internal surfaces.

## Regular Terminal Behavior

RTERM should be useful without any R-YORS-specific configuration. Baseline
serial-terminal behavior includes:

- configurable baud, data bits, parity, stop bits, and flow control;
- keyboard input, copy, paste, and configurable CR/LF handling;
- configurable local echo;
- raw and readable transcript logging;
- application and normal cursor-key modes;
- application and normal keypad modes;
- PF-key support appropriate to the selected personality;
- serial BREAK plus explicit DTR and RTS handling;
- clean terminal-state restoration after exit or failure; and
- reconnect behavior that does not silently retransmit an incomplete action.

Scrollback is a host UI facility. It must not alter the current 80-by-24 target
screen used for cursor reports and screen rules.

## VT102 Identity and Reports

RTERM should generate terminal replies itself rather than relying on the outer
WSL terminal to answer them.

The initial VT102 personality is expected to cover at least:

| Target request | RTERM behavior |
| --- | --- |
| ENQ (`$05`) | Transmit the configured answerback message without changing the screen. |
| Primary DA (`CSI c` or `CSI 0 c`) | Return the VT102 primary device-attributes identity. |
| DECID (`ESC Z`) in ANSI mode | Return the same identity as primary DA. |
| DSR (`CSI 5 n`) | Report terminal ready or a defined failure state. |
| CPR (`CSI 6 n`) | Report the current target row and column. |
| DECREQTPARM | Report communication parameters derived from configuration. |
| VT52 identify | Return the selected VT52-compatible identity while in VT52 mode. |

The proposed strict VT102 primary DA reply is `ESC [ ? 6 c`. A future
compatibility personality may deliberately report a different identity, such
as a VT100 with Advanced Video Option, but RTERM must not claim features that
the selected personality does not implement.

The answerback text is independently configurable. A value such as `RTERM` or
`RYORS` is not a substitute for the machine-readable DA reply.

The existing R-YORS samples provide useful board-driven acceptance exercises:

- `../DOC/GUIDES/ASM/SAMPLES/terminal-answerback-vt100-3000.a`
- `../DOC/GUIDES/ASM/SAMPLES/vt102-exerciser-7000.a`
- `../DOC/GUIDES/ASM/SAMPLES/vt525-exerciser-7000.a`

## VT525 Direction

The parser and cell model should be shaped so that VT525 support does not
require a rewrite. Nevertheless, the first release should identify as VT102.
The `vt525` personality should not be advertised until its supported query and
display surface is honest and testable.

Candidate later work includes:

- VT500 conformance-level selection;
- 7-bit and 8-bit C1 controls;
- G0-G3 and extended character-set handling;
- 80/132-column pages;
- color and default-color selection;
- left/right as well as top/bottom margins;
- rectangle fill, copy, erase, and attribute operations;
- protected cells and selective erase;
- the separate host-writable DEC status line;
- DCS macros;
- extended device, mode, setting, extent, and checksum reports; and
- VT500-series keyboard functions.

The existing VT525 exerciser covers much of this candidate surface and should
be treated as a staged acceptance fixture rather than evidence that RTERM is
already a VT525.

## Screen Model

The internal screen, not the outer terminal window, is authoritative. Each cell
will likely need:

- character or character-set index;
- foreground and background attributes;
- bold, underline, blink, reverse, and invisible flags;
- protected/unprotected state for later VT500 behavior; and
- dirty state for efficient repainting.

The terminal state also includes:

- cursor location and visibility;
- saved cursor state;
- current attributes;
- active character sets and shifts;
- origin, wrap, insert, newline, cursor-key, and keypad modes;
- top/bottom and later left/right margins;
- tab stops; and
- main versus DEC-status display selection.

Screen rules read stable snapshots of this model. They do not scrape pixels or
the ncurses output.

## Field-Oriented Design Aid

An eventual design aid should borrow the productive ideas of IBM SDA without
requiring an IBM terminal protocol. A screen definition may contain:

- fixed labels;
- boxes and lines;
- named display fields;
- input or output intent;
- watched regions;
- attributes and colors;
- rule bindings; and
- optional code-generation metadata for R-YORS.

One possible textual form is shown below only to make the concept concrete:

```text
SCREEN TRANSFER 80 24

TEXT  1 30 "R-YORS TRANSFER"
TEXT  5  3 "File:"
FIELD 5  9 32 NAME=filename TYPE=OUTPUT
WATCH 22 1 60 NAME=request

RULE transfer_request
    SOURCE request
    MATCH "LOAD {FORMAT} {ASSET}"
    WHEN CURSOR_LEAVES
    ACTION file_transfer
END
```

Neither this syntax nor the example word `LOAD` is selected. `$SEND` was also
only an example. RTERM should not hard-code a magic word into the terminal
parser.

Possible designer outputs include:

- the host-side screen/rule definition;
- a human-readable screen map;
- generated W65C02 assembly that paints the screen with VT sequences; and
- generated constants for field coordinates and lengths.

Generated target code should be considered a later phase. A useful first
designer can simply define and visualize host screen regions.

## Field and Form Semantics

Field Exit, zero fill, justification, padding, and character-class rules do
not belong in the VT102 parser or in the basic screen cell structure. They are
semantic attributes in a field definition. Mutable editing state belongs to a
form instance created from that definition.

The proposed responsibility split is:

| Component | Responsibility |
| --- | --- |
| terminal screen | The target-visible cells, attributes, cursor, and terminal modes. |
| field definition | Immutable geometry, data class, editing, formatting, validation, navigation, and submission metadata. |
| form instance | Current values, active field, local cursor, insert mode, modified-data flags, validation errors, and pending type-ahead. |
| renderer | Compose the target screen, any active local form edits, cursor, and OIA without confusing their ownership. |
| screen rules | Observe committed target cells by default and explicitly named form values when requested. |

A field definition may eventually describe:

- row, column, and length;
- input, output, protected, hidden, or watched usage;
- alphabetic, alphanumeric, digits-only, signed numeric, decimal, hexadecimal,
  or unrestricted input class;
- left or right justification;
- space, zero, or an explicitly selected padding character;
- trim or preserve behavior;
- automatic uppercase conversion;
- insert and overwrite permissions;
- required, mandatory-entry, and mandatory-fill rules;
- range, precision, sign, check-digit, or named validation rules;
- Field Exit behavior;
- next and previous field relationships;
- auto-advance behavior; and
- the action or record mapping used when the form is submitted.

Zero fill should be represented independently from right justification. A
right-justified field may be space padded, and a zero-filled field may have
additional sign or decimal policy. Combining them into one flag would make
numeric behavior ambiguous.

The design should distinguish at least these input policies:

| Policy | Behavior |
| --- | --- |
| `STREAM` | Conventional VT behavior. Accepted keys are transmitted immediately; field metadata may assist display or per-character validation but does not claim local block editing. |
| `FORM` | 3270/5250-style local editing. Keystrokes update the form instance, and an AID-like operation later submits field data. |

An illustrative definition is:

```text
SCREEN BANK_INSTALL 80 24
    SIGNATURE AT 1,30 "BANK INSTALL"

    FIELD BANK
        AT 5,12 LENGTH 1
        USAGE INPUT
        CLASS DIGITS
        RANGE 0..3
        FIELD_EXIT NEXT
    END

    FIELD IMAGE
        AT 6,12 LENGTH 24
        USAGE INPUT
        CLASS ALPHANUMERIC
        JUSTIFY LEFT
        PAD SPACE
        FIELD_EXIT FORMAT,NEXT
    END

    FIELD ADDRESS
        AT 7,12 LENGTH 4
        USAGE INPUT
        CLASS HEX
        JUSTIFY RIGHT
        PAD ZERO
        FIELD_EXIT VALIDATE,FORMAT,NEXT
    END
END
```

This grammar and every keyword remain provisional.

### Field Exit

In `FORM` policy, Field Exit is initially proposed as a local editing
operation:

1. validate the current field;
2. normalize and justify its contents;
3. apply the configured padding or zero fill;
4. set its modified-data flag when its logical value changed;
5. move to the next eligible input field; and
6. leave submission to Enter, a PF key, or another configured AID-like action.

A field may explicitly override this sequence, including remaining in place,
auto-advancing when full, or requesting submission. Such exceptions should be
visible in the design definition rather than hidden in action code.

### AID-Like Submission

Enter, PF keys, PA keys, or named R-YORS operations may act as Attention
Identifier (AID)-like submissions. The form engine produces a structured event
containing the AID name, screen/layout identity, cursor field, and either all
fields or only modified fields according to policy.

How that event reaches R-YORS is not yet selected. Candidate mappings include:

- a complete fixed-format record;
- modified fields with field identifiers;
- a configured sequence of conventional terminal input;
- a screen-specific action; or
- a future structured R-YORS messaging protocol.

The submission format needs its own documented target contract. RTERM should
not invent an implicit record format merely because a layout contains fields.

### Errors and OIA Interaction

A rejected character may be ignored with a bell or may enter a local field
error state. A validation failure on Field Exit or submission should normally:

- retain the cursor in the failing field;
- set `II` in the OIA;
- show a stable error identifier and message;
- permit SYSREQ and ATTN according to their separate policies; and
- require Error Reset or a defined corrective action before continuing.

For example:

```text
C1  SA       II      0009 NUMERIC DATA REQUIRED - PRESS RESET      07/15
```

Insert mode and queued type-ahead can drive `IM` and `KB` respectively. The OIA
may also show the active field name, class, justification, and fill policy when
space permits.

If new serial output changes a field while that field has unsubmitted local
edits, RTERM must not silently merge or discard the edit. The initial safe
policy should inhibit form input, report a conflict in the OIA, and require a
defined refresh, discard, or recovery choice.

Screen rules should observe the committed target screen by default. A rule that
needs unsubmitted local form data must explicitly name the form-value source;
otherwise ordinary typing could accidentally satisfy an automation rule.

## Screen Rules

A screen rule observes a named rectangle, field, or terminal state and emits a
request to the action dispatcher. Candidate match forms are:

- exact text;
- prefix plus captured fields;
- a bounded POSIX regular expression;
- several fields evaluated together;
- appearance, disappearance, or value change; and
- cursor or terminal-state conditions.

Activation must avoid firing on a partially painted value. Candidate commit
conditions include:

- cursor leaves the watched region;
- carriage return or line feed after writing the region;
- content remains unchanged for a configured interval;
- an exact fixed-width field becomes complete; or
- a separate screen state indicates completion.

Rules are edge-triggered by default. The same unchanged screen contents must
not repeatedly execute an action. Rules require an explicit rearm condition,
such as the field clearing or changing.

The action dispatcher should receive a structured event containing at least:

- rule name;
- screen or layout name, when known;
- captured values;
- cursor position;
- screen generation number;
- timestamp; and
- console/session identity.

## Actions and Safety Boundary

Initial actions should be named built-ins, not shell command strings. Possible
actions include:

```text
send_keys
capture_screen
write_transcript_mark
set_oia_message
transfer_s19
transfer_bin
post_operator_message
raise_attention
```

An unrestricted `system()`, shell, or arbitrary-program action should not be
part of the first design. If external programs are ever allowed, they require
a separate threat model, explicit allowlist, argument rules, timeouts, and
operator-visible logging.

File actions should initially use configured asset aliases or one or more
allowlisted roots. Target-displayed text must not supply an unrestricted host
path. File size limits, regular-file checks, symbolic-link policy, and optional
hash validation should be decided before automatic transfers are enabled.

## S19 and Binary Transfers

S19 and binary are distinct types. RTERM should not infer one from the other or
silently convert between them.

An S19 action should:

- open an explicitly permitted `.s19` asset;
- validate record types, lengths, hex digits, and checksums before sending;
- preserve or deliberately configure line termination;
- support record-level pacing; and
- report record and byte progress in the OIA.

A binary action should:

- open an explicitly permitted binary asset;
- send the exact bytes;
- support configured chunk size and pacing; and
- report byte progress in the OIA.

Serial is always a byte stream. "Block mode" may mean either host-side chunking
or a real acknowledged protocol. These must remain distinct:

| Mode | Meaning |
| --- | --- |
| raw | Continuously queue file bytes subject to flow control. |
| paced | Send configured chunks with a delay or readiness rule. |
| line | Send one validated text/S-record line at a time. |
| acknowledged block | Use sequence, length, checksum/CRC, ACK/NAK, timeout, and retry rules understood by target firmware. |

Raw, paced, and line modes can be implemented without inventing a target
protocol. An acknowledged block mode requires a separately documented R-YORS
wire contract and target implementation.

Keyboard input is normally inhibited or buffered while a transfer owns the TX
queue. The policy must be visible through `II` and `KB`.

## System Request and Attention

SYSREQ and ATTN are distinct logical keys.

### SYSREQ

The current proposal makes SYSREQ local to RTERM. It enters a management state
that remains available even when normal target input is inhibited. The target
screen remains intact while the OIA becomes a small request/command field.

Illustrative requests include:

```text
SYSREQ> STATUS
SYSREQ> IDENTITY
SYSREQ> CONSOLES
SYSREQ> SWITCH S1
SYSREQ> MESSAGES
SYSREQ> CANCEL TRANSFER
SYSREQ> RETURN
```

The grammar is undecided. A menu may prove better than a typed command line.

### ATTN

ATTN signals the target or a configured operator service. It does not enter
the SYSREQ management interface. Candidate serial mappings are:

- a serial BREAK condition;
- Ctrl-C (`$03`);
- a configured byte sequence;
- a future R-YORS attention/message request; or
- no target transmission, with a local event only.

No wire action should be assumed until a profile explicitly selects it. ATTN
must remain available when ordinary keyboard input is inhibited, subject to an
explicit safety policy.

Because Escape is needed by ordinary terminal applications, provisional local
bindings use a prefix rather than permanently stealing Escape:

```text
Ctrl-] S    System Request
Ctrl-] A    Attention
Ctrl-] R    Error Reset
Ctrl-] C    Console selection
```

These bindings are not final and must be configurable. Where the outer
terminal reports richer key events reliably, familiar mappings such as
Shift-Escape for SYSREQ may also be offered.

## Console, Subconsole, and Messages

RTERM owns the serial device. Consoles and subconsoles attach to the running
RTERM session rather than opening the serial device independently.

```text
                              +-- main console: display + keyboard owner
serial <--> RTERM core <-------+-- subconsole S1: operator messages
                              +-- subconsole S2: transfer/automation events
                              +-- subconsole S3: read-only trace
```

A local Unix-domain socket is the current candidate attachment mechanism.
The attachment protocol should carry structured events and screen snapshots or
deltas, not terminal escape sequences alone.

Provisional rules are:

- exactly one attachment owns ordinary keyboard transmission at a time;
- other attachments may be read-only or operator-enabled;
- a subconsole requests keyboard ownership and the current owner or policy
  grants it;
- attention and emergency capabilities are granted separately from ordinary
  keyboard ownership;
- unread messages set `MW` for the intended console;
- inquiries carry IDs and require correlated replies;
- cancellation is explicit;
- all control transfers, ATTN events, automated actions, and replies are
  logged; and
- disconnecting a console does not implicitly grant control to an arbitrary
  observer.

The repository already describes a future queue-shaped messaging service in
`../DOC/GUIDES/PLANNING/FUTURE.md`. RTERM can prototype its operator surface,
but host-side messages must not be presented as a completed target messaging
service. A later bridge may carry informational, attention, inquiry,
reply-required, reply, and cancellation events between R-YORS and RTERM.

## Configuration Sketch

This is an illustrative inventory, not a selected file grammar:

```ini
[terminal]
personality = vt102
columns = 80
rows = 24
answerback = RTERM

[serial]
device = /dev/ttyUSB0
baud = 115200
data_bits = 8
parity = none
stop_bits = 1
flow = none

[ui]
oia = true
scrollback_lines = 2000

[attention]
method = none

[automation]
enabled = false
layout = ryors.screen
asset_root = ../SRC/BUILD
```

Configuration precedence, per-user versus project configuration, secret
handling, and WSL device discovery remain open.

## Proposed Source Shape

The eventual source layout may resemble:

```text
RTERM/
|-- README.md
|-- DESIGN.md
|-- Makefile
|-- rterm.conf.example
|-- include/
|-- src/
|   |-- main.c
|   |-- serial.c
|   |-- vt_parser.c
|   |-- vt102.c
|   |-- vt525.c
|   |-- screen.c
|   |-- field.c
|   |-- form.c
|   |-- ui.c
|   |-- oia.c
|   |-- rules.c
|   |-- actions.c
|   |-- transfer.c
|   |-- console.c
|   `-- config.c
`-- tests/
    |-- test_vt102.c
    |-- test_fields.c
    |-- test_forms.c
    |-- test_rules.c
    |-- test_transfer.c
    |-- test_console.c
    `-- fixtures/
```

This is a responsibility map rather than a requirement for one source file per
listed name.

## Testing Direction

Host tests should include:

- byte-by-byte and split-buffer parser tests;
- golden screen images after escape-sequence scripts;
- exact answerback, DA, DSR, CPR, terminal-parameter, and VT52 replies;
- pseudo-terminal integration tests for keyboard and serial traffic;
- character-class, justification, padding, zero-fill, and field-navigation
  tests;
- Field Exit, modified-data, validation, Error Reset, and AID-event tests;
- stream-versus-form input-policy tests;
- serial-output-versus-local-edit conflict tests;
- S19 validation and pacing tests;
- exact binary transfer tests including embedded zeroes;
- partial screen-paint and duplicate-trigger tests;
- file allowlist and path-escape rejection tests;
- console ownership and disconnect tests;
- SYSREQ and ATTN routing tests; and
- terminal restoration after signals and failures.

The R-YORS VT102 and VT525 exercisers are hardware-facing fixtures. Passing
host tests does not replace an observed board run and retained transcript.

## Provisional Milestones

1. **Document and skeleton** -- agree on responsibilities, build shape, and
   test harness without committing the later protocol surface.
2. **Regular VT102 terminal** -- serial I/O, keyboard, screen, OIA, identity,
   reports, logging, and the existing VT102 exerciser.
3. **Screen snapshots and rules** -- named regions, stable activation,
   edge/rearm behavior, and dry-run logging.
4. **Field/form engine** -- field definitions, local form state, validation,
   Field Exit, Error Reset, modified flags, and dry-run AID events.
5. **Transfers** -- safe assets plus separately validated S19 and exact binary
   actions with pacing.
6. **SYSREQ and ATTN** -- local request state, configurable attention route,
   error reset, and audit events.
7. **Console/subconsole** -- structured local attachments, ownership, messages,
   inquiries, replies, and cancellation.
8. **Design aid** -- visual field/region authoring and saved layout definitions.
9. **VT525 personality** -- implement and test the advanced DEC surface in
   independently reviewable slices.

The order can change. In particular, a small screen-definition editor may be
useful before the complete console service.

## Open Decisions

- Exact OIA column layout and color/attribute conventions.
- The readiness policy that controls `SA`.
- Whether undetectable indicators such as physical keyboard shift should be
  omitted rather than approximated.
- Configuration and screen-definition file grammars.
- The exact field attribute vocabulary and which validation rules belong in
  the common engine rather than screen-specific actions.
- Default `STREAM` versus `FORM` policy and how a layout activates form mode.
- The target wire contract for AID-like form submission.
- Whether submission sends every field or only modified fields.
- Serial-output conflict handling while local form edits are pending.
- Screen-rule commit and rearm defaults.
- Initial built-in action set.
- Asset aliases versus root-relative filenames.
- Default S19 pacing for the current R-YORS loader.
- Whether normal keystrokes are rejected or buffered during transfers.
- The R-YORS target meaning of ATTN: BREAK, Ctrl-C, a dedicated sequence, or a
  future messaging-service event.
- SYSREQ command language versus menu UI.
- Console takeover and emergency-override policy.
- Authentication and authorization for local subconsole attachments.
- Compact presentation of the DEC status line and RTERM OIA in 25 host rows.
- Minimum VT525 feature set required before advertising the VT525 identity.
- Whether a later design aid should generate assembly, data tables, or both.
