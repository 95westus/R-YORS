"""Exercise size-sensitive linked HIMON code with py65 1.2.0 (no board I/O).

Install: python -m pip install --target BUILD/tmp/asm-error-deps py65==1.2.0
Run from SRC: python tools/check_himon_size.py
Only terminal output is intercepted; disassembly, service initialization, FNV,
and AP parsing/loading execute from the supplied S19 image and matching map.
"""

import argparse
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "BUILD/tmp/asm-error-deps"))
try:
    from py65.devices.mpu65c02 import MPU
except ImportError as exc:
    raise SystemExit(__doc__) from exc


class Image:
    def __init__(self, path):
        self.symbols = {name: int(address, 16) for address, name in re.findall(
            r"^\s*([0-9a-fA-F]{8})\s+(\w+)\s*$",
            path.with_suffix(".map").read_text(), re.M)}
        self.memory = [0] * 65536
        for line in path.read_text().splitlines():
            if line.startswith("S1"):
                row = bytes.fromhex(line[2:])
                assert len(row) == row[0] + 1 and sum(row) & 255 == 255
                address = int.from_bytes(row[1:3], "big")
                self.memory[address:address + len(row) - 4] = row[3:-1]


class Machine:
    def __init__(self, image):
        self.s = image.symbols
        self.m = image.memory.copy()
        self.cpu = MPU(memory=self.m)
        self.output = ""
        self.hooks = {
            self.s["BIO_FTDI_WRITE_BYTE_BLOCK"]: lambda: self.emit(chr(self.cpu.a)),
            self.s["SYS_WRITE_HEX_BYTE"]: lambda: self.emit(f"{self.cpu.a:02X}"),
            self.s["SYS_WRITE_CRLF"]: lambda: self.emit("\r\n"),
        }

    def byte(self, name, value=None):
        address = self.s[name]
        if value is None:
            return self.m[address]
        self.m[address] = value

    def word(self, name, value=None):
        address = self.s[name]
        if value is None:
            return self.m[address] | self.m[address + 1] << 8
        self.m[address:address + 2] = [value & 255, value >> 8]

    def emit(self, text):
        self.output += text
        # Match the actual terminal primitives' A/X/Y preservation and success C.
        self.cpu.p |= 1
        self.cpu.sp = (self.cpu.sp + 1) & 255
        lo = self.m[0x100 + self.cpu.sp]
        self.cpu.sp = (self.cpu.sp + 1) & 255
        hi = self.m[0x100 + self.cpu.sp]
        self.cpu.pc = ((hi << 8) + lo + 1) & 65535

    def run(self, entry, a=0):
        c = self.cpu
        c.pc = self.s[entry] if isinstance(entry, str) else entry
        c.a, c.x, c.y, c.sp, c.p = a, 0xA5, 0x5A, 0xFD, 0x20
        self.m[0x1FE:0x200] = [0xEF, 0x1F]  # RTS to $1FF0.
        for _ in range(2_000_000):
            if c.pc == 0x1FF0:
                assert c.sp == 0xFF, f"unbalanced stack in {entry}"
                return c.a, bool(c.p & 1), c.x | c.y << 8
            if c.pc in self.hooks:
                self.hooks[c.pc]()
            else:
                assert self.m[c.pc] != 0, f"unexpected BRK at ${c.pc:04X} in {entry}"
                c.step()
        raise AssertionError(f"instruction limit in {entry} at ${c.pc:04X}")


def expected_mnemonic(opcode):
    # Independent CPU opcode definitions; py65 1.2.0 lacks BBR/BBS and STP.
    if opcode & 15 == 15:
        return ("BBS" if opcode & 128 else "BBR") + str((opcode >> 4) & 7)
    if opcode == 0xDB:
        return "STP"
    name = MPU.disassemble[opcode][0]
    return "" if name == "???" else name


def test_mnemonics(image):
    for opcode in range(256):
        t = Machine(image)
        t.word("NMI_CTX_PCL", 0x2345)
        t.word("DBG_STEP_LO", 0x3456)
        t.byte("DBG_TMP_OPCODE", opcode)
        t.byte("DBG_TMP_LEN", 2)
        t.m[0x2346] = 0x5A
        t.run("DBG_PRINT_STEP_INFO")
        name = expected_mnemonic(opcode)
        expected = f"STEP PC=2345 OP={opcode:02X}"
        if name:
            expected += " " + name
        if opcode == 0:
            expected += " SIG=5A"
        expected += " LEN=02 NEXT=3456\r\n"
        assert t.output == expected, (f"opcode ${opcode:02X}", t.output, expected)
        assert t.word("CMDP_ADDR_LO") == 0x3456
    print("PASS all 256 opcode step displays, including bit suffixes and unknown opcodes")


def fnv1a(data):
    value = 0x811C9DC5
    for byte in data:
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return value


def test_fnv(image):
    known = {b"": 0x811C9DC5, b"a": 0xE40C292C,
             b"foobar": 0xBF9CF968, b"hello": 0x4F9F2CAB}
    vectors = list(known) + [bytes([byte]) for byte in range(256)]
    vectors += [bytes(range(256)), bytes(range(255, -1, -1)) * 2]
    t = Machine(image)
    t.run("MON_INIT_SERVICE_VECTORS")
    init = t.word("HIM_SVC_FNV_INIT_LO")
    update = t.word("HIM_SVC_FNV_UPDATE_LO")
    assert init == t.s["FNV1A_INIT"] and update == t.s["FNV1A_UPDATE_A_FAST"]
    for data in vectors:
        t.run(init)
        for byte in data:
            t.run(update, a=byte)
        address = t.s["FNV_HASH0"]
        actual = int.from_bytes(bytes(t.m[address:address + 4]), "little")
        expected = known[data] if data in known else fnv1a(data)
        assert actual == expected, (data, hex(actual), hex(expected))
    print(f"PASS {len(vectors)} FNV vectors through initialized resident service pointers")


def word_bytes(value):
    return value.to_bytes(2, "little")


def package(body):
    # Minimal AP v2: seal, zero relocations/exports/imports, then nonempty body.
    base = 0x2800
    seal = (b"\x01" + word_bytes(base) + word_bytes(base + len(body))
            + word_bytes(len(body)) + fnv1a(body).to_bytes(4, "little"))
    records = b"S" + word_bytes(len(seal)) + seal
    for tag in b"REI":
        records += bytes([tag, 1, 0, 0])
    records += b"B" + word_bytes(len(body)) + body
    return bytearray(b"AP\x02" + word_bytes(5 + len(records)) + records)


def run_ap(image, data, source, body, load=False, status=0):
    t = Machine(image)
    destination = 0x4000
    t.m[source - 1:source + len(data) + 1] = [0x55, *data, 0xAA]
    t.m[destination - 1:destination + len(body) + 1] = [0xCC] * (len(body) + 2)
    t.word("HIM_AP_SRC_LO", source)
    t.word("HIM_AP_DST_LO", destination)
    t.byte("HIM_AP_OP", int(load))
    # Poison the scratch values whose setup is being consolidated.
    t.word("CMDP_PTR_LO", 0x5555)
    t.word("CMDP_ADDR_LO", 0x6666)
    t.word("LOAD_LEN_LO", 0x7777)
    result, carry, xy = t.run("HIM_AP_SERVICE")
    assert carry == (status == 0) and t.byte("HIM_AP_STATUS") == status, (
        hex(source), len(body), load, status, result, carry, t.byte("HIM_AP_STATUS"))
    assert t.m[source - 1:source + len(data) + 1] == [0x55, *data, 0xAA]
    if status == 0:
        assert xy == (destination if load else source)
        assert t.word("HIM_AP_BODY_LO") == source + 34
        assert t.word("HIM_AP_BODY_LEN_LO") == len(body)
        if not load:
            assert t.word("CMDP_PTR_LO") == source + 34
            assert t.word("LOAD_LEN_LO") == 0
        expected = list(body) if load else [0xCC] * len(body)
    else:
        expected = [0xCC] * len(body)
    assert t.m[destination - 1:destination + len(body) + 1] == [0xCC, *expected, 0xCC]


def test_ap(image):
    count = 0
    # $20DC puts BODY at $20FE; $20DE puts it on a page boundary;
    # $37F8 makes the source+8 seal pointer carry into the next page.
    for source in (0x20DC, 0x20DE, 0x37F8):
        for size in (1, 255, 256, 257):
            body = bytes((index * 37 + 11) & 255 for index in range(size))
            for load in (False, True):
                run_ap(image, package(body), source, body, load)
                count += 1

    body = bytes(range(256)) + b"\xA5"
    valid = package(body)
    failures = []
    for offset in (0, 1, 2, 5, 6, 8, 15, 16, 17, 18, 31, 32, 34, len(valid) - 1):
        bad = valid.copy()
        bad[offset] ^= 1
        failures.append((bad, 7))
    bad = valid.copy()
    # Keep seal base+length=end consistent, but disagree with the BODY length.
    bad[11:13] = word_bytes(0x2800 + len(body) - 1)
    bad[13:15] = word_bytes(len(body) - 1)
    failures.append((bad, 7))
    # Missing record room reports BAD_RANGE; complete headers with inconsistent
    # flags/body lengths report BAD_LINE. Preserve this existing distinction.
    for end, status in ((5, 6), (7, 6), (8, 7), (18, 6), (20, 6), (23, 6),
                        (26, 6), (30, 6), (33, 6), (34, 7), (len(valid) - 1, 7)):
        bad = valid[:end]
        bad[3:5] = word_bytes(end)
        failures.append((bad, status))
    for bad, status in failures:
        for load in (False, True):
            run_ap(image, bad, 0x20DC, body, load, status=status)
            count += 1
    run_ap(image, valid, 0x5000, body, status=6)
    count += 1
    print(f"PASS {count} AP parse/load cases: page boundaries, seal errors, truncation, and range policy")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path,
                        default=ROOT / "BUILD/s19/himon-rom-c000.s19")
    args = parser.parse_args()
    image = Image(args.image)
    test_mnemonics(image)
    test_fnv(image)
    test_ap(image)


if __name__ == "__main__":
    main()
