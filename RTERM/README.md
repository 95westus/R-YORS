# RTERM

> **Status: exploratory design draft.** Nothing in this directory is an
> implementation contract yet. Names, syntax, scope, and sequencing may change
> as the design is exercised against R-YORS and real hardware.

RTERM is a proposed GNU C serial terminal for R-YORS. Its baseline job is to
work as a normal interactive terminal, comparable to the serial-terminal use
of minicom, PuTTY, or Tera Term. Around that baseline it may add:

- faithful VT102 terminal identity and query replies;
- an 80-column by 24-row target display with a host-owned Operator Information
  Area (OIA) on row 25;
- field-oriented screen observation inspired by IBM 3270/5250 terminals and
  Screen Design Aid (SDA), without using the IBM wire protocols;
- optional field/form editing with validation, justification, padding, Field
  Exit, and AID-style submission;
- configurable, bounded actions based on what appears in named screen regions;
- later conversation macros that can wait for board output, capture received
  data, and send replies;
- distinct S19 and binary transfer actions;
- System Request, Attention, console, subconsole, and operator-message
  facilities; and
- a later DEC VT525 personality built on the same terminal engine.

The DEC VT525 and IBM 5250 names refer to unrelated terminal families. RTERM's
wire protocol is initially DEC VT102 over a serial connection. IBM 3270/5250
ideas influence the OIA, field model, and operator workflow only.

See [DESIGN.md](DESIGN.md) for the current working design and unresolved
questions.
