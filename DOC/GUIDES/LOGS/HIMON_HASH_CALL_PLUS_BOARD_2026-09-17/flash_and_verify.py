"""Guarded COM4 install and exact verification for HIMON # ! / # !+."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import serial
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BUILD = ROOT / "SRC/BUILD"
IMAGE = BUILD / "s19/himon-apv2-bank3-c-e.s19"
ROM = BUILD / "bin/himon-rom-c000.bin"
LOG = HERE / "serial-com4.jsonl"


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


class Board:
    def __enter__(self):
        self.log = LOG.open("a", encoding="utf-8")
        self.serial = serial.Serial(port=None, baudrate=115200, timeout=0.05,
                                    write_timeout=5)
        self.serial.dtr = False
        self.serial.rts = False
        self.serial.port = "COM4"
        self.serial.open()
        return self

    def record(self, direction, data):
        self.log.write(json.dumps({"time": datetime.now().astimezone().isoformat(),
                                   "direction": direction, "hex": data.hex()}) + "\n")
        self.log.flush()

    def send(self, data):
        self.record("TX", data)
        self.serial.write(data)
        self.serial.flush()

    def read(self, seconds=3, until=None):
        end = time.monotonic() + seconds
        result = bytearray()
        while time.monotonic() < end:
            part = self.serial.read(self.serial.in_waiting or 1)
            if part:
                self.record("RX", part)
                result.extend(part)
                if until and re.search(until, result.decode("ascii", "replace")):
                    return bytes(result)
        if until:
            raise AssertionError(f"missing {until!r}; got {result[-1600:]!r}")
        return bytes(result)

    def command(self, text, until=r"\r\n>$", seconds=10):
        self.send(text.encode("ascii") + b"\r")
        result = self.read(seconds, until)
        print(result[-2000:].decode("ascii", "replace"), flush=True)
        return result

    def transfer(self, path, seconds=60, until=None):
        result = bytearray()
        lines = path.read_text().splitlines()
        for line in lines:
            self.send(line.encode("ascii") + b"\r")
            time.sleep(0.015)
            if self.serial.in_waiting:
                data = self.serial.read(self.serial.in_waiting)
                self.record("RX", data)
                result.extend(data)
        if not until or not re.search(until, result.decode("ascii", "replace")):
            result.extend(self.read(seconds, until))
        print(f"Sent {len(lines)} S19 records; tail: " +
              result[-2000:].decode("ascii", "replace"), flush=True)
        return bytes(result)

    def __exit__(self, *args):
        self.serial.close()
        self.log.close()


def dump_bytes(reply, start, end):
    found = {}
    text = reply.decode("ascii", "replace")
    rows = re.finditer(r"(?m)^([0-9A-F]{4}): "
                       r"((?:[0-9A-F]{2} ){8})\| "
                       r"((?:[0-9A-F]{2} ){8})\|", text)
    for match in rows:
        base = int(match.group(1), 16)
        for offset, value in enumerate(bytes.fromhex(match.group(2) + match.group(3))):
            found[base + offset] = value
    missing = [address for address in range(start, end + 1) if address not in found]
    assert not missing, f"dump missing {missing[0]:04X} and {len(missing)-1} more"
    return bytes(found[address] for address in range(start, end + 1))


def dump(board, start, end):
    return dump_bytes(board.command(f"D {start:04X} {end:04X}", seconds=45), start, end)


def next_journal(top, bank):
    start = 0xFBC + 16 * bank
    for pair in range(16):
        at, shift = start + pair // 4, (pair % 4) * 2
        if (top[at] >> shift) & 3 == 3:
            top[at] &= ~(3 << shift)
            return at, shift
    raise AssertionError(f"no journal pair for bank {bank}")


himon = ROM.read_bytes()[0x4000:0x7000]
assert len(himon) == 0x3000

with Board() as board:
    board.send(b"\r")
    preflight = board.read(4)
    print(preflight.decode("ascii", "replace"), flush=True)
    before_top = bytearray(dump(board, 0xF000, 0xFFFF))
    expected_top = bytearray(before_top)
    journal_at, journal_shift = next_journal(expected_top, 3)

    board.command("STR8", until=r"K=03 \? ")
    board.send(b"Y")
    board.read(15, r"0-2 C W S: ")
    board.send(b"S")
    board.read(10, r"STR8-N>")
    board.command("I", until=r"B0-3: ")
    board.command("3", until=r"RANGE: ")
    board.command("C-E", until=r"I B3 .*WRITE\? Y: ")
    board.command("Y", until=r"S19[\r\n]+")
    reply = board.transfer(IMAGE, until=r"(?:COMMIT\? Y: |FAIL)")
    assert b"COMMIT? Y:" in reply and b"FAIL" not in reply
    reply = board.command("Y", until=r"STR8-N>", seconds=60)
    assert b"OK" in reply and b"FAIL" not in reply

    reply = board.command("C", seconds=20)
    assert b"HIMON V 00.0917(1534)" in reply
    actual_himon = dump(board, 0xC000, 0xEFFF)
    actual_top = dump(board, 0xF000, 0xFFFF)
    assert actual_himon == himon
    assert actual_top == expected_top

    quiet = board.command("# ! FNV1A_INIT")
    assert b"RET A=" in quiet and b"ENTRY=" not in quiet and quiet.count(b"RET A=") == 1
    full = board.command("# !+ FNV1A_INIT")
    assert b"#4B9AEE1E# ENTRY=" in full and full.count(b"RET A=") == 1

result = {
    "result": "PASS",
    "stamp": "0917(1534)",
    "port": "COM4",
    "baud": 115200,
    "range": "Bank 3 C-E",
    "records": len(IMAGE.read_text().splitlines()),
    "himon_payload_sha256": sha(himon),
    "install_s19_sha256": sha(IMAGE.read_bytes()),
    "top_before_sha256": sha(before_top),
    "top_after_sha256": sha(expected_top),
    "journal_byte_offset": f"{journal_at:03X}",
    "journal_shift": journal_shift,
    "checks": ["exact C000-EFFF readback", "exact F000-FFFF journal-only change",
               "# ! RET-only", "# !+ identity plus RET"],
}
(HERE / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="ascii")
print("PASS HIMON # ! / # !+ flash and exact verification")
