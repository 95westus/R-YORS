"""Execute linked ASMF2 diagnostics and source cases on a 65C02 (py65 1.2.0).

Install with: python -m pip install --target BUILD/tmp/asm-error-deps py65==1.2.0
Run from SRC: python tools/check_asm_errors.py
Console I/O and service discovery are simulated; ASM and the HIMON arithmetic,
PACK40 and AP routines execute from their actual S19 images. No board I/O.
"""

from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "BUILD/tmp/asm-error-deps"))
try:
    from py65.devices.mpu65c02 import MPU
except ImportError as exc:
    raise SystemExit(__doc__) from exc


def symbols(path):
    return {name: int(address, 16) for address, name in re.findall(
        r"^\s*([0-9a-fA-F]{8})\s+(\w+)\s*$", path.read_text(), re.M)}


def load_s19(memory, path):
    for line in path.read_text().splitlines():
        if line.startswith("S1"):
            row = bytes.fromhex(line[2:])
            assert len(row) == row[0] + 1 and sum(row) & 255 == 255
            address = int.from_bytes(row[1:3], "big")
            memory[address:address + len(row) - 4] = row[3:-1]


ARGS = argparse.ArgumentParser(description=__doc__)
ARGS.add_argument("--asm-image", type=Path,
                  default=ROOT / "BUILD/s19/asm-v1-flash-8000.s19")
OPTIONS = ARGS.parse_args() if __name__ == "__main__" else ARGS.parse_args([])
ASM = symbols(OPTIONS.asm_image.with_suffix(".map"))
HIM = symbols(ROOT / "BUILD/s19/himon-rom-c000.map")
ROM = [0] * 65536
load_s19(ROM, OPTIONS.asm_image)
load_s19(ROM, ROOT / "BUILD/s19/himon-rom-c000.s19")
REASONS = ["OK", "UNKNOWN OP", "DIRECTIVE", "OPERAND", "ADDR MODE", "SIZE",
           "RANGE", "LINE", "NAME", "FIXUP", "LOCAL", "SERVICE"]


def reason(status, sealed=False, ap=False):
    if ap:
        return {0: "OK", 6: "RANGE", 7: "INVALID", 9: "FIXUP", 11: "SERVICE"}.get(status, "FAIL")
    if sealed and status in (1, 2):
        return {1: "NO END", 2: "INVALID"}[status]
    return REASONS[status] if status < len(REASONS) else "FAIL"


class Machine:
    def __init__(self):
        self.m = ROM.copy()
        self.cpu = MPU(memory=self.m)
        self.output = ""
        self.lines = []
        self.hooks = {}
        for slot, target in {
            "ASM_RJ_FNV_INIT_LO": "FNV1A_INIT",
            "ASM_RJ_FNV_UPDATE_LO": "FNV1A_UPDATE_A_FAST",
            "ASM_RJ_HEX_NIB_LO": "UTL_HEX_ASCII_TO_NIBBLE",
            "ASM_RJ_UPPER_LO": "HIM_CHAR_TO_UPPER",
            "ASM_HIM_SVC_PACK40_ASCII_LO": "HIM_PACK40_ASCII_TO_CODE",
            "ASM_HIM_SVC_PACK40_PACK3_LO": "HIM_PACK40_PACK3",
            "ASM_HIM_SVC_AP_LO": "HIM_AP_SERVICE",
        }.items():
            self.word(slot, HIM[target])
        self.hook("ASM_RJOIN_INIT", lambda: self.ret(carry=True))
        self.hook("ASM_RJOIN_INIT_IO", lambda: self.ret(carry=True))
        self.hook("ASM_RJ_RESIDENT_XY", lambda: self.ret(carry=False))
        self.hook("ASM_RJ_WRITE_HBSTRING", self.hbstring)
        self.hook("ASM_RJ_WRITE_HEX_BYTE", self.hexbyte)
        self.hook("ASM_RJ_PRINT_CRLF", lambda: self.emit("\r\n"))
        self.hook("ASM_RJ_READ_CSTRING", self.read)
        self.hook("ASM_RJ_READ_CSTRING_UPPER", self.read)

    def hook(self, name, fn):
        self.hooks[ASM[name]] = fn

    def byte(self, name, value=None):
        if value is None:
            return self.m[ASM[name]]
        self.m[ASM[name]] = value

    def word(self, name, value=None):
        address = ASM[name]
        if value is None:
            return self.m[address] | self.m[address + 1] << 8
        self.m[address:address + 2] = [value & 255, value >> 8]

    def ret(self, a=None, carry=None, xy=None):
        c = self.cpu
        if a is not None:
            c.a = a
            c.p = (c.p & ~0x82) | (0x02 if a == 0 else 0) | (a & 0x80)
        if carry is not None:
            c.p = (c.p & ~1) | int(carry)
        if xy is not None:
            c.x, c.y = xy & 255, xy >> 8
        c.sp = (c.sp + 1) & 255
        lo = self.m[0x100 + c.sp]
        c.sp = (c.sp + 1) & 255
        c.pc = (lo + (self.m[0x100 + c.sp] << 8) + 1) & 65535

    def emit(self, text):
        self.output += text
        # Exercise callers with destructive output registers/flags.
        self.cpu.x, self.cpu.y = 0xA5, 0x5A
        self.ret(a=0xCC, carry=False)

    def hbstring(self):
        address = self.cpu.x | self.cpu.y << 8
        text = ""
        for i in range(256):
            byte = self.m[(address + i) & 65535]
            text += chr(byte & 127)
            if byte & 128:
                self.emit(text)
                return
        raise AssertionError(f"unterminated HB string at {address:04X}")

    def hexbyte(self):
        self.emit(f"{self.cpu.a:02X}")

    def read(self):
        assert self.lines, "unexpected input request"
        line = self.lines.pop(0)
        if isinstance(line, int):
            self.ret(a=line, carry=False)
            return
        address = self.cpu.x | self.cpu.y << 8
        self.m[address:address + len(line) + 1] = [*line.encode("ascii"), 0]
        self.ret(a=len(line), carry=True)

    def run(self, name, a=0, xy=0, stop=None):
        c = self.cpu
        c.pc, c.a, c.x, c.y = ASM[name], a, xy & 255, xy >> 8
        c.sp, c.p = 0xFD, 0x20
        self.m[0x1FE:0x200] = [0xEF, 0x1F]  # RTS to $1FF0
        limit = ASM[stop] if stop else 0x1FF0
        for _ in range(2000000):
            if c.pc == limit:
                return c.a, bool(c.p & 1), c.x | c.y << 8
            if c.pc in self.hooks:
                self.hooks[c.pc]()
            else:
                assert self.m[c.pc] != 0, f"unexpected BRK at {c.pc:04X} in {name}"
                c.step()
        raise AssertionError(f"instruction limit in {name} at {c.pc:04X}")

    def session(self, lines):
        self.lines = list(lines)
        result = self.run("START")
        assert not self.lines
        return result


def test_messages():
    expected = {
        "MSG_PROMPT": "ASM>$", "MSG_PROMPT_TAIL": ": ",
        "MSG_SEAL_PROMPT": "SEAL> ", "MSG_READ": "READ FAIL",
        "MSG_FAIL": "BEGIN", "MSG_PC": " PC=$", "MSG_SEAL_ERR": "SEAL",
        "MSG_SEAL_OK": "SEAL OK", "MSG_RELOCATE_ERR": "REL",
        "MSG_RELOCATE_OK": "REL OK BASE=$", "MSG_RELOCATE_COUNT": " C=$",
        "MSG_PACKAGE_ERR": "PKG", "MSG_PACKAGE_OK": "PKG OK @=$",
        "MSG_PACKAGE_LEN": " L=$", "MSG_LOAD_ERR": "LOAD", "MSG_LOAD_OK": "LOAD OK=$",
        "MSG_INSTALL_ERR": "INST", "MSG_ERR": "ERR", "MSG_INSTALL_OK": "INST @=$",
        "MSG_FLAGS": " FLAGS=$", "MSG_DONE": "ASM OK", "MSG_BYE": "ASM BYE",
    }
    for name, text in expected.items():
        t = Machine()
        t.run("ASMF_WRITE_MSG", a=ASM[name] & 255)
        assert t.output == text, (name, t.output, text)
    t = Machine()
    t.word("ASMF_PC_LO", 0x1234)
    t.run("ASMF_PRINT_PC_TAIL", a=(ASM["MSG_PC"] + 1) & 255)
    assert t.output == "PC=$1234\r\n"
    print("PASS 23 message/address checks, including shared READ/FAIL and ASM/OK suffixes")


def test_decoders():
    for status in range(256):
        for entry, prefix, sealed, suffix in (
            ("ASMF_PRINT_STATUS_PC_LINE", "ERR", False, " PC=$2345"),
            ("ASMF_PRINT_STATUS_LINE", "LOAD", False, ""),
            ("ASMF_PRINT_SEAL_STATUS_LINE", "PKG", True, ""),
            ("ASMF_PRINT_AP_STATUS_LINE", "LOAD", False, ""),
        ):
            t = Machine()
            t.byte("ASMF_RESULT", status)
            t.word("ASMF_PC_LO", 0x2345)
            msg = {"ERR": "MSG_ERR", "LOAD": "MSG_LOAD_ERR", "PKG": "MSG_PACKAGE_ERR"}[prefix]
            t.run(entry, a=ASM[msg] & 255)
            assert t.output == f"{prefix} {reason(status, sealed, entry == 'ASMF_PRINT_AP_STATUS_LINE')}{suffix}\r\n", (entry, status, t.output)
            assert t.byte("ASMF_RESULT") == status
            assert t.run("ASMF_RETURN_RESULT") == (status, False, 0x2345)
    print("PASS 1024 decoder cases: all 256 bytes in native/PC/seal/AP contexts and return ABI")


def test_commands():
    cases = [
        ("ASMF_RELOCATE_CMD", "ASMF_PARSE_RELOCATE_ARG", "ASM_SEAL_RELOCATE", "REL", True),
        ("ASMF_PACKAGE_CMD", "ASMF_PARSE_RELOCATE_ARG", "ASM_SEAL_PACKAGE", "PKG", True),
        ("ASMF_LOAD_CMD", "ASMF_PARSE_TWO_ARGS", "ASM_PACKAGE_LOAD", "LOAD", False),
        ("ASMF_INSTALL_CMD", "ASMF_PARSE_RELOCATE_ARG", "ASM_PACKAGE_INSTALL_SUGGEST", "INST", False),
    ]
    if "ASMF_CHECK_CMD" in ASM:
        cases.append(("ASMF_CHECK_CMD", "ASMF_PARSE_RELOCATE_ARG", "ASM_SEAL_CHECK_PACKAGE", "CHECK", False))
    count = 0
    for entry, parser, worker, prefix, sealed in cases:
        for parser_fails in (False, True):
            for status in range(1, 256):
                t = Machine()
                # PACKAGE expects its original command-tail X/Y before this parser.
                t.m[0x1A00:0x1A06] = list(b"$3000\0")
                t.hook("ASMF_PARSE_INSTALL_BANK", lambda: t.ret(carry=False))
                if entry == "ASMF_INSTALL_CMD":
                    t.hook("ASMF_PARSE_TWO_ARGS", lambda: t.ret(carry=False))
                t.hook(parser, lambda: t.ret(a=status if parser_fails else 0,
                                            carry=not parser_fails, xy=0x3000))
                t.hook(worker, lambda: t.ret(a=status, carry=False))
                t.run(entry, xy=0x1A00, stop="ASMF_LOOP")
                expected = f"{prefix} {reason(status, sealed and not parser_fails, not sealed and not parser_fails)}\r\n"
                assert t.output == expected, (entry, parser_fails, status, t.output, expected)
                assert t.byte("ASMF_RESULT") == status
                count += 1
    for status in range(1, 256):
        t = Machine()
        t.hook("ASM_SEAL_COMPUTE_FNV", lambda: t.ret(a=status, carry=False))
        t.byte("ASM_SEAL_FLAGS", 9)
        t.run("ASMF_SEAL_CMD", stop="ASMF_LOOP")
        assert t.output == f"SEAL {reason(status, True)} FLAGS=$09\r\n"
        t = Machine()
        assert t.session([status])[:2] == (status, False)
        assert t.output.endswith("READ FAIL\r\n")
        count += 2
    print(f"PASS {count} command failure cases: parser/worker domains, SEAL flags, READ, status retention")


def test_sources():
    cases = [
        (["FOO BAR"], 1),
        (["LDA #"], 3),
        (["LDA A"], 4),
        (["STA #$01"], 4),
        (["LDA 1000"], 5),
        (["LDA #$100"], 5),
        (["ORG $7D00"], 6),
        (["ORG $5000"], 6),
        (["DB 1", "ORG $2000"], 6),
        (["BNE $3000"], 6),
        (["A" * 64], 7),
        (["FOO EQU 1", "FOO EQU 2"], 8),
        (["A EQU 1"], 8),
        ([".LOOP NOP"], 8),
        (["JMP MISSING", "END"], 9),
    ]
    for lines, status in cases:
        t = Machine()
        # END failure exits immediately; all other source failures allow '.'.
        inputs = lines if lines[-1] == "END" else lines + ["."]
        result = t.session(inputs)
        assert result[:2] == (status, False), (lines, result, t.output)
        assert f"ERR {reason(status)} PC=$" in t.output, (lines, t.output)
        assert t.byte("ASM_LAST_STATUS") == status
    t = Machine()
    result = t.session(["DB $A5", "DB $11,", "DB $5A", "."])
    assert result == (3, False, 0x2002), (result, t.output)
    assert t.m[0x2000:0x2003] == [0xA5, 0x5A, 0], t.m[0x2000:0x2003]
    assert "ERR OPERAND PC=$2001\r\n" in t.output
    t = Machine()
    assert t.session(["LDA #", "END", "NEW", "."])[:2] == (0, True)
    t = Machine()
    commands = ["LDA #$AC", "RTS", "END", "SEAL", "RELOCATE $2400", "PACKAGE $3000"]
    if "ASMF_CHECK_CMD" in ASM:
        commands.append("CHECK $3000")
    result = t.session(commands + ["LOAD $3000 $4000", "."])
    assert result[:2] == (0, True), (result, t.output)
    assert t.m[0x2000:0x2003] == [0xA9, 0xAC, 0x60]
    assert "ASM OK\r\n" in t.output and "SEAL OK\r\n" in t.output
    assert "PKG OK @=$3000" in t.output, t.output
    assert "REL OK BASE=$2400 C=$00\r\n" in t.output
    assert "LOAD OK=$4000" in t.output
    assert t.m[0x2400:0x2403] == t.m[0x4000:0x4003] == [0xA9, 0xAC, 0x60]
    if "ASMF_CHECK_CMD" in ASM:
        assert "CHECK OK @=$3000" in t.output
    t = Machine()
    t.byte("ASMF_POST_FLAG", 1)
    t.m[0x7A03:0x7A05] = [ord(" "), ord("S")]
    result = t.session(["SEAL", "."])
    assert result[:2] == (1, False), (result, t.output)
    assert "SEAL NO END FLAGS=$00\r\n" in t.output
    for command in ("SEAL", "RELOCATE $3000", "PACKAGE $3000"):
        t = Machine()
        result = t.session(["DB 1", "ORG $2010", "DB 2", "END", command, "."])
        assert result[:2] == (2, False), (command, result, t.output)
        prefix = {"SEAL": "SEAL", "RELOCATE": "REL", "PACKAGE": "PKG"}[command.split()[0]]
        assert f"{prefix} INVALID" in t.output
    t = Machine()
    assert t.session(["END", "LOAD $3000 $4000", "."])[:2] == (7, False)
    assert "LOAD INVALID\r\n" in t.output
    t = Machine()
    t.m[0x7CFF:0x7D01] = [0x33, 0x44]
    assert t.session(["ORG $7CFF", "DB $A5,$5A", "."]) == (6, False, 0x7CFF)
    assert t.m[0x7CFF:0x7D01] == [0x33, 0x44]
    for commands, status in (
        ([f"S{i} EQU 1" for i in range(129)], 8),
        ([f"S{i:03d}" + "X" * 27 + " EQU 1" for i in range(67)], 8),
        ([f"JMP F{i}" for i in range(129)], 9),
    ):
        t = Machine()
        result = t.session(commands + ["."])
        assert result[:2] == (status, False), (status, result, t.output[-300:])
        assert f"ERR {reason(status)}" in t.output
    print("PASS real-source 01,03-09; addressing/range/name variants; row/name-pool/fixup exhaustion")
    print("PASS rollback/boundary; sticky failure/NEW; SEAL/RELOCATE/PACKAGE/LOAD success; invalid/no-END/malformed AP")


def test_entry_and_install():
    t = Machine()
    t.hook("ASM_RJOIN_INIT_IO", lambda: t.ret(carry=False))
    assert t.run("START") == (11, False, 0) and not t.output
    t = Machine()
    t.hook("ASM_RJOIN_INIT", lambda: t.ret(carry=False))
    assert t.run("START")[:2] == (11, False)
    assert "BEGIN SERVICE\r\n" in t.output
    t = Machine()
    t.m[0x7A03:0x7A05] = [ord(" "), ord("S")]
    assert t.run("START")[:2] == (3, False)  # No saved SEAL session.
    t = Machine()
    assert t.session(["END", "NOPE", "."])[:2] == (3, False)
    assert "ERR OPERAND PC=$2000\r\n" in t.output
    t = Machine()
    assert t.session([".P", "."]) == (0, True, 0x2000)
    assert "PC=$2000\r\n" in t.output
    t = Machine()
    t.word("ASMF_PC_LO", 0x7D00)
    assert t.run("ASMF_NEW_CMD")[:2] == (6, False)
    assert t.output == "BEGIN RANGE\r\n"
    for status in range(1, 256):
        t = Machine()
        t.hook("ASMF_PARSE_INSTALL_BANK", lambda: t.ret(carry=False))
        t.hook("ASMF_PARSE_TWO_ARGS", lambda: t.ret(carry=True, xy=0x3000))
        t.hook("ASM_PACKAGE_PARSE_MIN", lambda: t.ret(a=status, carry=False))
        t.run("ASMF_INSTALL_CMD", stop="ASMF_LOOP")
        assert t.output == f"INST {reason(status, ap=True)}\r\n"
        assert t.byte("ASMF_RESULT") == status
    # Exercise the actual legacy flash-install failure tail without flash I/O.
    t = Machine()
    t.word("HIM_SVC_FLASH_INSTALL_LO", 0xC100)
    t.hook("ASMF_FLASH_INSTALL", lambda: t.ret(a=0xD7, carry=False))
    result = t.session(["RTS", "END", "PACKAGE $3000", "INSTALL $3000 $8000", "."])
    assert result[:2] == (6, False), (result, t.output)
    assert "INST RANGE\r\n" in t.output
    print("PASS entry/service/resume/.P/post-END handling; 255 two-address INSTALL statuses; flash failure mapping")


if __name__ == "__main__":
    test_messages()
    test_decoders()
    test_commands()
    test_sources()
    test_entry_and_install()
    if ASM['_BEG_DATA'] < 0x8000:
        print(f"PASS optional host fixture: CODE end=${ASM['_END_CODE']:04X}, "
              f"DATA end=${ASM['_END_DATA']:04X}; not a resident flash image")
    else:
        assert ASM['_END_DATA'] <= 0xBE00
        print(f"PASS ASMF2 error regression; ROM end=${ASM['_END_DATA']:04X}, "
              f"headroom=${0xC000 - ASM['_END_DATA']:04X}")
