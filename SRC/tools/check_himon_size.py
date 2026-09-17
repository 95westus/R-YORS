"""Exercise size-sensitive linked HIMON code with py65 1.2.0 (no board I/O).

Install: python -m pip install --target BUILD/tmp/asm-error-deps py65==1.2.0
Run from SRC: python tools/check_himon_size.py
Only terminal I/O is intercepted; disassembly, service initialization, FNV,
command dispatch, and AP parsing/loading execute from the supplied S19 image
and matching map.
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
        self.emitted = set()
        for line in path.read_text().splitlines():
            if line.startswith("S1"):
                row = bytes.fromhex(line[2:])
                assert len(row) == row[0] + 1 and sum(row) & 255 == 255
                address = int.from_bytes(row[1:3], "big")
                self.memory[address:address + len(row) - 4] = row[3:-1]
                self.emitted.update(range(address, address + len(row) - 4))


class Machine:
    def __init__(self, image):
        self.s = image.symbols
        self.m = image.memory.copy()
        self.cpu = MPU(memory=self.m)
        self.output = ""
        self.input = []
        self.hooks = {
            self.s["BIO_FTDI_WRITE_BYTE_BLOCK"]: lambda: self.emit(chr(self.cpu.a)),
            self.s["SYS_WRITE_HEX_BYTE"]: lambda: self.emit(f"{self.cpu.a:02X}"),
            self.s["SYS_WRITE_CRLF"]: lambda: self.emit("\r\n"),
        }

    def terminal_input(self, text=""):
        self.input = list(text.encode("ascii"))
        # Exercise both BIO and private HIMON receive paths, intercepting only
        # the bottom-level PIN read so their actual wrappers still execute.
        self.hooks[self.s["PIN_FTDI_READ_BYTE_NONBLOCK"]] = self.read_byte

    def read_byte(self):
        if self.input:
            self.cpu.a = self.input.pop(0)
            self.cpu.p = (self.cpu.p & ~0x83) | 1 | (self.cpu.a & 0x80)
            if self.cpu.a == 0:
                self.cpu.p |= 2
        else:
            self.cpu.p &= ~1
        self.return_()

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
        self.return_()

    def return_(self):
        self.cpu.sp = (self.cpu.sp + 1) & 255
        lo = self.m[0x100 + self.cpu.sp]
        self.cpu.sp = (self.cpu.sp + 1) & 255
        hi = self.m[0x100 + self.cpu.sp]
        self.cpu.pc = ((hi << 8) + lo + 1) & 65535

    def run(self, entry, a=0, x=0xA5, y=0x5A, p=0x20,
            stop=0x1FF0, stack=0xFF):
        c = self.cpu
        c.pc = self.s[entry] if isinstance(entry, str) else entry
        c.a, c.x, c.y, c.sp, c.p = a, x, y, 0xFD, p
        self.m[0x1FE:0x200] = [0xEF, 0x1F]  # RTS to $1FF0.
        for _ in range(2_000_000):
            if c.pc == stop:
                assert c.sp == stack, f"unbalanced stack in {entry}: ${c.sp:02X}"
                return c.a, bool(c.p & 1), c.x | c.y << 8
            if c.pc in self.hooks:
                self.hooks[c.pc]()
            else:
                assert self.m[c.pc] != 0, f"unexpected BRK at ${c.pc:04X} in {entry}"
                c.step()
        raise AssertionError(f"instruction limit in {entry} at ${c.pc:04X}")


def saved_context(t, status=0x26):
    values = [1, 0x41, 0x52, 0x63, status, 0x45, 0x23, 0xF3]
    start = t.s["NMI_CTX_FLAG"]
    t.m[start:start + len(values)] = values
    return values


def read_context(t):
    start = t.s["NMI_CTX_FLAG"]
    return t.m[start:start + 8]


def expected_flags(status, carry):
    # Preserve the historical display: N/n uses entry C, not saved P bit 7.
    return ("N" if carry else "n") + "".join(
        letter if status & mask else letter.lower()
        for letter, mask in zip("V-BDIZC", (0x40, 0, 0x10, 8, 4, 2, 1)))


def test_flags_and_reports(image):
    for status in range(256):
        for carry in (0, 1):
            t = Machine(image)
            context = saved_context(t, status)
            t.run("MON_PRINT_FLAGS", p=0x20 | carry)
            assert t.output == expected_flags(status, carry), (status, carry, t.output)
            assert read_context(t) == context
        for kind in (0, 1):
            t = Machine(image)
            context = saved_context(t, status)
            t.byte("CMD_EXEC_KIND", kind)
            address = t.s["CMD_EXEC_HASH0"]
            t.m[address:address + 4] = [0x85, 0x5B, 0x28, 0x20]
            t.run("MON_PRINT_RET_AND_REGS")
            identity = "GO" if kind else "20285B85"
            expected = (f"\r\n#{identity}# ENTRY=2345\r\n"
                        f"RET A=41 X=52 Y=63 P={status:02X} S=F3 "
                        f"{expected_flags(status, 1)}\r\n")
            assert t.output == expected, (status, kind, t.output, expected)
            assert read_context(t) == context

    # A returning routine reports only for explicit execution without a live trap.
    for trap in (0, 1):
        for kind in (0, 1):
            t = Machine(image)
            context = saved_context(t)
            context[0] = trap
            t.byte("NMI_CTX_FLAG", trap)
            t.byte("CMD_EXEC_KIND", kind)
            t.word("CMDP_ADDR_LO", 0x2800)
            t.word("CMD_EXEC_ENTRY_LO", 0x2800)
            t.m[0x2800:0x2808] = [0xA9, 0x41, 0xA2, 0x52, 0xA0, 0x63, 0x38, 0x60]
            t.run("CMD_EXEC_ADDR")
            if kind and not trap:
                assert t.output == ("\r\n#GO# ENTRY=2800\r\n"
                                    "RET A=41 X=52 Y=63 P=31 S=FD Nv-BdizC\r\n")
                assert read_context(t) == [0, 0x41, 0x52, 0x63, 0x31, 0, 0x28, 0xFD]
            else:
                assert t.output == "" and read_context(t) == context
    print("PASS 512 flag displays, 512 full return reports, and quiet/live-trap return paths")


def hbstring(t, name):
    result = ""
    address = t.s[name]
    for byte in t.m[address:]:
        result += chr(byte & 0x7F)
        if byte & 0x80:
            return result
    raise AssertionError(f"unterminated string {name}")


def command_line(t, text):
    data = text.encode("ascii") + b"\0"
    t.m[0x2200:0x2200 + len(data)] = data
    t.word("CMDP_PTR_LO", 0x2200)


def test_print_helpers(image):
    count = 0
    for name in sorted(image.symbols):
        if not name.startswith("CMD_USAGE_"):
            continue
        t = Machine(image)
        context = saved_context(t)
        expected = hbstring(t, name.replace("CMD_", "MSG_", 1)) + "\r\n"
        t.run(name)
        assert t.output == expected, (name, t.output, expected)
        assert read_context(t) == context
        count += 1
    for name in ("CMD_HASH_PRINT_ENTRY", "DBG_PRINT_CMD_ADDR"):
        t = Machine(image)
        t.word("CMDP_ADDR_LO", 0x12AB)
        t.run(name)
        assert t.output == "12AB", (name, t.output)
    for name in ("CMD_HASH_SPACE", "DIS_WRITE_SPACE"):
        t = Machine(image)
        t.run(name)
        assert t.output == " ", (name, t.output)
    print(f"PASS {count} usage lines and shared address/space output helpers")


def test_message_page(image, baseline=None):
    assert image.symbols["HIM_MESSAGE_PAGE"] == 0xEF00
    assert image.symbols["HIM_MESSAGE_PAGE_END"] == 0xF000
    end = image.symbols["HIM_CORE_END"]
    assert end == image.symbols["_END_DATA"] and 0xC000 < end <= 0xEF00
    assert image.emitted == set(range(0xC000, 0xF000)), "HIMON S19 must be dense and stop before STR8"
    assert image.memory[end:0xEF00] == [0xFF] * (0xEF00 - end)
    names = sorted(name for name, address in image.symbols.items()
                   if name.startswith("MSG_") and 0xEF00 <= address < 0xF000)
    assert names and all(image.memory[address] != 0xFF
                         for address in range(0xEF00, 0xF000))
    covered = set()
    for name in names:
        address = image.symbols[name]
        expected = hbstring(Machine(baseline or image), name)
        covered.update(range(address, address + len(expected)))
        for routine, newline in (("HIM_WRITE_HBSTRING", ""),
                                 ("HIM_WRITE_PAGE_TEXT", ""),
                                 ("HIM_WRITE_PAGE_LINE", "\r\n")):
            t = Machine(image)
            context = saved_context(t)
            y = address >> 8 if routine == "HIM_WRITE_HBSTRING" else 0x17
            t.run(routine, x=address & 255, y=y)
            assert t.output == expected + newline, (name, routine, t.output, expected)
            assert read_context(t) == context
    assert covered == set(range(0xEF00, 0xF000)), "message page must contain exactly 256 text bytes"
    assert image.symbols["MSG_STOP_PC"] == image.symbols["MSG_STOP_NMI"] + 3
    assert hbstring(Machine(image), "MSG_STOP_NMI") == "NMI PC="
    assert hbstring(Machine(image), "MSG_STOP_PC") == " PC="
    assert hbstring(Machine(image), "MSG_BOX_GO") == "GO"

    for reason, expected in ((0, ""), (1, "BOOT COLD\r\n"), (2, "BOOT WARM\r\n")):
        t = Machine(image)
        t.byte("BOOT_REASON", reason)
        t.run("MON_BOOTLOG_RESET")
        assert t.output == expected and t.byte("BOOT_REASON") == 0
    for cause, prefix in (("TRAP_CAUSE_NMI", "NMI PC=2345"),
                          ("TRAP_CAUSE_BRK", "BRK 55 PC=2345")):
        t = Machine(image)
        saved_context(t)
        t.byte("TRAP_CAUSE", t.s[cause])
        t.byte("TRAP_BRK_SIG", 0x55)
        t.run("MON_PRINT_STOP_AND_REGS")
        assert t.output == f"\r\n{prefix}\r\nA=41 X=52 Y=63 P=26 S=F3 Nv-bdIZc\r\n", t.output
    if baseline:
        # Fixed RAM/ZP state is represented by these absolute map symbols.
        # Compare the allocation names and addresses, not relocatable ROM code.
        def ram_symbols(img):
            return {name: address for name, address in img.symbols.items()
                    if 0x20 <= address <= 0xFF or 0x7E00 <= address <= 0x7EFF}
        assert ram_symbols(image) == ram_symbols(baseline), "fixed RAM/ZP symbols changed"
    print(f"PASS {len(names)} fixed-page message entries, shared suffixes, boot/stop output, "
          f"and {0xEF00 - end} dense $FF padding bytes")


def test_hex_parser(image, baseline=None):
    for value in range(256):
        t = Machine(image)
        result, carry, xy = t.run("UTL_HEX_ASCII_TO_NIBBLE", a=value)
        char = chr(value)
        valid = char in "0123456789ABCDEFabcdef"
        assert carry == valid and result == (int(char, 16) if valid else value)
        assert xy == 0x5AA5
    if baseline is not None:
        for decimal in (0, 8):
            for value in range(256):
                before, after = Machine(baseline), Machine(image)
                before.run("CMD_HEX_ASCII_TO_NIBBLE", a=value, p=0x20 | decimal)
                after.run("UTL_HEX_ASCII_TO_NIBBLE", a=value, p=0x20 | decimal)
                assert (before.cpu.a, before.cpu.x, before.cpu.y, before.cpu.p) == (
                    after.cpu.a, after.cpu.x, after.cpu.y, after.cpu.p), (value, decimal)

    words = ("0", "9", "a", "F", "aBcD", "$fF01", " \t$AbCd", "FFFF ",
             "1234\t", "42+", "", "$", " ", "G", "fg", "10000", "12,", "0x12")
    for token in words:
        t = Machine(image)
        command_line(t, token)
        _, carry, _ = t.run("CMD_PARSE_HEX_WORD_TOKEN")
        match = re.fullmatch(r"[ \t]*\$?([0-9a-fA-F]{1,4})([ \t+])?", token)
        assert carry == bool(match), (token, carry)
        if match:
            assert t.word("CMDP_ADDR_LO") == int(match[1], 16)
            consumed = len(token) - len(match[2] or "")
            assert t.word("CMDP_PTR_LO") == 0x2200 + consumed
    for token, expected in (("ff", 255), ("$Ab", 171), ("0001", 1), ("100", None),
                            ("g0", None), ("", None)):
        t = Machine(image)
        command_line(t, token)
        value, carry, _ = t.run("CMD_PARSE_HEX_BYTE_TOKEN")
        assert carry == (expected is not None), token
        if carry:
            assert value == expected, (token, value)
    comparison = "; 512 binary/decimal conversions match baseline" if baseline else ""
    print(f"PASS 256 hex characters and 24 word/byte tokens{comparison}")


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


def monitor_command(t, text):
    command_line(t, text)
    t.run("CMD_HASH_TOKEN")
    # MAIN_HAVE_LINE tail-jumps to the dispatcher. Stop before MAIN_LOOP reads
    # another command so this exercises the outer # call and its return too.
    t.run("CMD_DISPATCH_HASH", stop=t.s["MAIN_LOOP"], stack=0xFD)


def test_record(t, name="TEST_RET", kind=1, address=0x8000):
    header = b"FN\xD6" + fnv1a(name.encode("ascii")).to_bytes(4, "little") + bytes([kind])
    entry = 0x9000 if kind == 3 else address + 8
    if kind == 3:
        header += word_bytes(entry) + word_bytes(0xA000)
        text = b"CONFIRME\xC4"
        t.m[0xA000:0xA000 + len(text)] = text
    t.m[address:address + len(header)] = header
    # Deliberately return C=0 and nonzero A to distinguish a diagnostic return
    # report from the quiet dispatcher's ordinary RAM-command error path.
    t.m[entry:entry + 8] = [0xA9, 0x41, 0xA2, 0x52, 0xA0, 0x63, 0x18, 0x60]
    return entry


def watch_returns(t):
    returns = []
    address = t.s["CMD_EXEC_ADDR"]
    assert t.m[address] == 0x20, "CMD_EXEC_ADDR must begin by calling the target"
    def capture():
        c = t.cpu
        returns.append((c.a, c.x, c.y, c.p | 0x30, c.sp))
        c.step()  # Execute the real PHP; this hook only observes the return.
    t.hooks[address + 3] = capture
    return returns


def assert_call_report(t, name, entry, registers):
    a, x, y, p, stack = registers
    expected = (f"\r\n#{fnv1a(name.encode('ascii')):08X}# ENTRY={entry:04X}\r\n"
                f"RET A={a:02X} X={x:02X} Y={y:02X} P={p:02X} S={stack:02X} "
                f"{expected_flags(p, 1)}\r\n")
    assert t.output.endswith(expected), (t.output, expected)
    assert t.output.count("RET A=") == 1, "outer # duplicated the diagnostic report"
    assert "EXEC ERR" not in t.output
    assert read_context(t) == [0, a, x, y, p, entry & 255, entry >> 8, stack], (
        read_context(t), registers)
    assert t.byte("CMD_EXEC_KIND") == 0, "diagnostic kind leaked to the outer # call"


def test_hash_call(image):
    # Exercise the user's actual scenario with real resident FNV lookup and BIO
    # code. Only the PIN receive operation supplies the simulated typed 'A'.
    name = "BIO_FTDI_READ_BYTE_BLOCK"
    for diagnostic in (False, True):
        t = Machine(image)
        context = saved_context(t)
        context[0] = 0
        t.byte("NMI_CTX_FLAG", 0)
        t.terminal_input("A")
        returns = watch_returns(t)
        monitor_command(t, ("# ! " if diagnostic else "") + name)
        assert not t.input and returns[0][0] == 0x41
        if diagnostic:
            assert len(returns) == 2, "expected inner target and outer # returns"
            assert_call_report(t, name, t.s[name], returns[0])
        else:
            assert len(returns) == 1 and t.output == ""
            assert read_context(t) == context

    for line in ("# ! TEST_RET", "#\t!\tTEST_RET\t"):
        t = Machine(image)
        t.terminal_input()
        entry = test_record(t)
        returns = watch_returns(t)
        monitor_command(t, line)
        assert len(returns) == 2
        assert returns[0][:3] == (0x41, 0x52, 0x63) and not returns[0][3] & 1
        assert_call_report(t, "TEST_RET", entry, returns[0])

    # Preserve the returned D bit in the snapshot, but format the report in
    # binary mode. The real hex formatter uses ADC for the A..F conversion.
    t = Machine(image)
    t.terminal_input()
    entry = test_record(t)
    t.m[entry:entry + 9] = [0xF8, 0xA9, 0xAB, 0xA2, 0xCD, 0xA0, 0xEF, 0x38, 0x60]
    del t.hooks[t.s["SYS_WRITE_HEX_BYTE"]]
    returns = watch_returns(t)
    monitor_command(t, "# ! TEST_RET")
    assert returns[0][3] & 8 and not t.cpu.p & 8
    assert_call_report(t, "TEST_RET", entry, returns[0])

    for line, expected in (("# !", "# ! NAME"), ("# ! ", "# ! NAME"),
                           ("# !TEST_RET", "# ! NAME"),
                           ("# ! TEST_RET EXTRA", "# ! NAME"),
                           ("# ! NO_SUCH_ROUTINE", "# ! NF/EXEC"),
                           ("# ! BIO_FTDI_READ_BYTE_BLOCK_FNV", "# ! NF/EXEC"),
                           ("# ! TEST_TEXT", "# ! NF/EXEC"),
                           ('# ! "NOT_A_COMMAND', "# ! NF/EXEC")):
        t = Machine(image)
        t.terminal_input()
        context = saved_context(t)
        context[0] = 0
        t.byte("NMI_CTX_FLAG", 0)
        test_record(t)
        test_record(t, "TEST_TEXT", kind=4, address=0x8100)
        returns = watch_returns(t)
        monitor_command(t, line)
        assert t.output == expected + "\r\n", (line, t.output)
        assert len(returns) == 1 and read_context(t) == context
        assert t.byte("CMD_EXEC_KIND") == 0

    for answer in ("Y", "y", "N"):
        t = Machine(image)
        t.terminal_input(answer)
        entry = test_record(t, "TEST_CONFIRM", kind=3)
        returns = watch_returns(t)
        monitor_command(t, "# ! TEST_CONFIRM")
        prompt = f"RUN CONFIRMED @{entry:04X} K=03 ? {answer}\r\n"
        assert t.output.startswith(prompt) and not t.input, t.output
        if answer.upper() == "Y":
            assert len(returns) == 2
            assert_call_report(t, "TEST_CONFIRM", entry, returns[0])
        else:
            assert t.output == prompt and len(returns) == 1
            assert read_context(t) == [0] * 8
            assert t.byte("CMD_EXEC_KIND") == 0

    t = Machine(image)
    t.terminal_input()
    context = saved_context(t)
    t.byte("TRAP_CAUSE", t.s["TRAP_CAUSE_BRK"])
    t.byte("TRAP_BRK_SIG", 0x55)
    test_record(t)
    returns = watch_returns(t)
    monitor_command(t, "# ! TEST_RET")
    assert t.output == "# ! LIVE CTX\r\n" and len(returns) == 1
    assert read_context(t) == context
    assert t.byte("TRAP_CAUSE") == t.s["TRAP_CAUSE_BRK"] and t.byte("TRAP_BRK_SIG") == 0x55
    print("PASS # ! typed A=$41, exact saved returns, syntax/lookup/kind failures, "
          "Y/y/N confirmation, quiet bare calls, and live-context protection")


def test_hash_queries(image, baseline=None):
    def listing(img, line):
        t = Machine(img)
        t.terminal_input()
        test_record(t)
        test_record(t, "TEST_CONFIRM", kind=3, address=0x8100)
        test_record(t, "TEST_TEXT", kind=4, address=0x8200)
        context = saved_context(t)
        monitor_command(t, line)
        assert read_context(t) == context and "RET A=" not in t.output
        return t.output
    for line in ("#", "# K=01", "# K<03", "# K>03"):
        output = listing(image, line)
        rows = output.splitlines()
        assert rows.pop(0) == "HASH     ENTRY K TEXT"
        assert rows
        for row in rows:
            match = re.fullmatch(r"([0-9A-F]{8}) ([0-9A-F]{4}) ([0-9A-F]{2})(.*)", row)
            assert match, row
            kind = int(match[3], 16)
            assert line == "#" or {"# K=01": kind == 1, "# K<03": kind < 3,
                                  "# K>03": kind > 3}[line]
        if baseline:
            # Moving ROM code changes ENTRY values but not record identity,
            # order, kind, text, or filter behavior.
            def normalized(text):
                return re.sub(r"(?m)^([0-9A-F]{8}) [0-9A-F]{4} ", r"\1 ENTRY ", text)
            assert normalized(output) == normalized(listing(baseline, line)), line
    for name, entry, kind in (("TEST_RET", 0x8008, 1), ("TEST_TEXT", 0x8208, 4)):
        # Existing HB output consumes CMDP_PTR, so the historical info display
        # has a trailing space here rather than repeating the input token.
        expected = f"{fnv1a(name.encode('ascii')):08X} ENTRY={entry:04X} K={kind:02X} \r\n"
        assert listing(image, "# " + name) == expected
        if baseline:
            assert listing(image, "# " + name) == listing(baseline, "# " + name)
    print("PASS # listing, token information, and K=/K</K> filters without execution")


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


def test_launch_and_resume(image):
    for command in ("G", "AP"):
        t = Machine(image)
        saved_context(t)
        t.byte("TRAP_CAUSE", 2)
        t.byte("TRAP_BRK_SIG", 0x55)
        # Execute through the command's real parser and launch path; AP also
        # validates and loads a real package. Stop at the transferred PC.
        if command == "AP":
            data = package(b"\x60")
            t.m[0x2800:0x2800 + len(data)] = data
            command_line(t, "AP 2800 4000")
        else:
            t.m[0x4000] = 0x60
            command_line(t, "G 4000")
        t.run("CMD_" + command, stop=0x4000, stack=0xFD)
        assert t.output == "GO 4000\r\n", (command, t.output)
        assert t.word("CMD_EXEC_ENTRY_LO") == 0x4000
        assert t.byte("CMD_EXEC_KIND") == t.s["CMD_EXEC_KIND_GO"]
        assert t.m[0x4000] == 0x60
        assert all(t.byte(name) == 0 for name in
                   ("NMI_CTX_FLAG", "TRAP_CAUSE", "TRAP_BRK_SIG"))

    for command in ("X", "N"):
        t = Machine(image)
        context = saved_context(t, 0xE5)
        command_line(t, command)
        t.m[0x2345:0x2347] = [0xEA, 0xEA]  # NOP, followed by step-trap site.
        t.run("CMD_" + command, stop=0x2345, stack=0xF3)
        prefix = "STEP PC=2345 OP=EA NOP LEN=01 NEXT=2346\r\n" if command == "N" else ""
        assert t.output == prefix + "RESUME 2345\r\n", (command, t.output)
        assert (t.cpu.a, t.cpu.x, t.cpu.y, t.cpu.p) == (0x41, 0x52, 0x63, 0xF5)
        assert read_context(t) == [0, *context[1:]]
        if command == "N":
            assert t.byte("DBG_STEP_FLG") == t.s["DBG_BPF_ACTIVE"]
            assert t.byte("DBG_STEP_OP") == 0xEA and t.m[0x2346] == 0
    print("PASS G/AP launch, X/N register and stack restoration, and N step-trap placement")


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
    parser.add_argument("--baseline", type=Path,
                        help="optional pre-compaction image for private hex-converter comparison")
    parser.add_argument("--page-baseline", type=Path,
                        help="optional pre-message-page image for text/RAM/hash-query comparison")
    args = parser.parse_args()
    image = Image(args.image)
    baseline = Image(args.baseline) if args.baseline else None
    page_baseline = Image(args.page_baseline) if args.page_baseline else None
    test_flags_and_reports(image)
    test_print_helpers(image)
    test_message_page(image, page_baseline)
    test_hash_call(image)
    test_hash_queries(image, page_baseline)
    test_hex_parser(image, baseline)
    test_launch_and_resume(image)
    test_mnemonics(image)
    test_fnv(image)
    test_ap(image)


if __name__ == "__main__":
    main()
