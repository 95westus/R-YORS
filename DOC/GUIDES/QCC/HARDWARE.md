# QCC Hardware

This page keeps board-level electrical concerns that software can observe or
reduce but cannot settle by itself.

> [!WARNING]
> Do not assume that FTDI enumeration checks make simultaneous board-side and
> USB power electrically safe. Power-domain safety depends on the actual
> schematic, module jumpers, supply connections, and interface protection.

## Q: Can STR8 make ACIA-side and USB FTDI power coexist safely?

Comment: STR8 can keep the FTDI FIFO bus idle when USB is not configured or is
suspended. The FTDI `PWE#` signal is visible at bit 5 of the VIA control port
`$7FE0`; active-low means USB is configured and not suspended. STR8 can use
that state to avoid asserting `RD#` or `WR#`, leave the eight-bit data port as
input, and bound console waits.

Concern: This is traffic control, not power isolation. If the board is powered
through an ACIA-side or other board supply while the FTDI remains powered from
USB, either side may source an unpowered device through supply connections,
pull-ups, level translators, or input-protection paths. Two nominal 5 V
supplies may also be tied together unintentionally. Firmware cannot prevent
back-powering while the CPU/VIA is unpowered because no firmware is executing.

Laptop sleep is a particularly important case. USB VBUS may remain present
while the host suspends the FTDI interface and `PWE#` becomes inactive. A
`PWE#` check therefore means "configured and not suspended," not "USB power is
absent" and not "a terminal application is open."

The repository does not currently contain enough schematic detail to declare
the mixed-power topology safe or unsafe. Before simultaneous power is treated
as supported, record:

- the exact FTDI device or module and its jumper configuration;
- whether USB VBUS is connected to board 5 V;
- the source of FTDI VCC and VCCIO;
- how the ACIA-side or board supply reaches the system;
- the common-ground arrangement;
- any series resistance, buffer, level translator, power switch, diode, or
  power mux between the domains.

With all sources initially disconnected, establish the topology before
energizing both sides. Then use a current-limited and measured preflight to
check:

1. Board power off, USB connected: the CPU/VIA rail is not phantom-powered.
2. Board powered, USB disconnected: the board does not backfeed FTDI VCC,
   VCCIO, or USB VBUS.
3. Laptop awake, asleep, and awake again: `PWE#`, `RD#`, `WR#`, data-bus
   direction, rail voltage, and unexpected current remain consistent with the
   intended design.
4. Both supplies present, only after the unpowered checks pass: the supplies
   do not fight or raise unexpected current.

Do not connect both supplies merely to discover whether directly tied rails
will tolerate it. Resolve the wiring first.

Useful manufacturer references:

- [FT245R USB FIFO IC datasheet](https://ftdichip.com/wp-content/uploads/2020/08/DS_FT245R.pdf)
- [FTDI enumeration and PWREN# FAQ](https://ftdichip.com/faqs/)
- [FTDI mixed-power guidance](https://www.ftdichip.com/Support/Knowledgebase/canftdidevicesbepoweredin.htm)

This concern is recorded here and parked. It is not part of the current STR8
selector implementation unless hardware power-domain work is explicitly
reopened.
