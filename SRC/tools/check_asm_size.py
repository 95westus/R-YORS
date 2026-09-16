"""Check linked ASM-F2 opcode selection, exact state clears, and service init.

Install py65==1.2.0 in BUILD/tmp/asm-error-deps, then run from SRC:
    python -B tools/check_asm_size.py [--asm-image PATH]
The opcode oracle uses py65's instruction definitions plus explicit WDC and
ASM syntax rules. No ASM tables, routine bytes, or service hooks form the oracle.
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


def symbols(path):
    return {name: int(address, 16) for address, name in re.findall(
        r"^\s*([0-9a-fA-F]{8})\s+(\w+)\s*$", path.read_text(), re.M)}


class Machine:
    def __init__(self, path):
        self.sym = symbols(path.with_suffix(".map"))
        self.memory = [0] * 65536
        for line in path.read_text().splitlines():
            if line.startswith("S1"):
                row = bytes.fromhex(line[2:])
                assert len(row) == row[0] + 1 and sum(row) & 255 == 255
                address = int.from_bytes(row[1:3], "big")
                self.memory[address:address + len(row) - 4] = row[3:-1]
        self.cpu = MPU(memory=self.memory)

    def run(self, name, a=0x59, x=0xA6, y=0x37):
        cpu = self.cpu
        cpu.pc, cpu.a, cpu.x, cpu.y = self.sym[name], a, x, y
        cpu.sp, cpu.p = 0xFD, 0x20
        self.memory[0x1FE:0x200] = [0xEF, 0x1F]
        for _ in range(4096):
            if cpu.pc == 0x1FF0:
                return cpu.a, bool(cpu.p & 1)
            cpu.step()
        raise AssertionError(f"instruction limit in {name} at ${cpu.pc:04X}")


def opcode_oracle(sym):
    modes = dict(imp="NONE", acc="ACC", imm="IMM8", zpg="ZP8", abs="ABS16",
                 zpx="ZP_X", abx="ABS_X", rel="REL8", zpy="ZP_Y", aby="ABS_Y",
                 zpi="ZP_IND", inx="ZP_X_IND", iny="ZP_IND_Y", ind="ABS_IND",
                 iax="ABS_X_IND")
    rows = {}
    for opcode, (name, mode) in enumerate(MPU.disassemble):
        if name == "???" or name == "BRK" or name.startswith(("RMB", "SMB")):
            continue
        key = (sym["ASM_VID_" + name], sym["ASM_OPM_" + modes[mode]])
        assert key not in rows, (name, mode)
        rows[key] = opcode
    # py65 1.2.0 does not describe WDC STP or BBR/BBS. ASM requires a BRK
    # signature operand, and accepts omitted A only for the four shifts.
    rows[sym["ASM_VID_STP"], sym["ASM_OPM_NONE"]] = 0xDB
    for mode in ("IMM8", "ZP8"):
        rows[sym["ASM_VID_BRK"], sym["ASM_OPM_" + mode]] = 0
    for name in ("ASL", "LSR", "ROL", "ROR"):
        rows[sym["ASM_VID_" + name], sym["ASM_OPM_NONE"]] = rows[
            sym["ASM_VID_" + name], sym["ASM_OPM_ACC"]]
    bit_rows = {sym["ASM_VID_" + name]: (sym["ASM_OPM_" + mode], opcode)
                for name, mode, opcode in (("RMB", "BIT_ZP", 0x07),
                                          ("SMB", "BIT_ZP", 0x87),
                                          ("BBR", "BIT_ZP_REL", 0x0F),
                                          ("BBS", "BIT_ZP_REL", 0x8F))}
    return rows, bit_rows


def test_opcodes(path):
    machine = Machine(path)
    sym, memory = machine.sym, machine.memory
    rows, bit_rows = opcode_oracle(sym)

    def check(ident, mode, bit):
        opcode = rows.get((ident, mode))
        if ident in bit_rows and bit_rows[ident][0] == mode:
            # The parser validates 0..7. The leaf routine's established
            # arithmetic wraps for arbitrary byte inputs; test that too.
            opcode = (bit_rows[ident][1] + ((bit << 4) & 255)) & 255
        memory[sym["ASM_STMT_OP_ID"]] = ident
        memory[sym["ASM_MODE"]] = mode
        memory[sym["ASM_TMP1_LO"]] = bit
        memory[sym["ASM_STATUS"]] = 0xA5
        result = machine.run("ASM_FIND_OPCODE")
        expected = (sym["ASM_STATUS_BAD_MODE"], False) if opcode is None else (opcode, True)
        assert result == expected, (ident, mode, bit, result, expected)
        assert memory[sym["ASM_STATUS"]] == (0 if opcode is not None else expected[0])
        assert memory[sym["ASM_STMT_OP_ID"]] == ident
        assert memory[sym["ASM_MODE"]] == mode
        assert memory[sym["ASM_TMP1_LO"]] == bit

    for ident in range(256):
        for mode in range(256):
            check(ident, mode, 0)
    for ident, (mode, _) in bit_rows.items():
        for bit in range(256):
            check(ident, mode, bit)
    print("PASS 65536 opcode ID/mode pairs and 1024 numbered-bit byte cases", flush=True)


def same_memory_except_stack(actual, expected, context):
    differences = [address for address, (a, b) in enumerate(zip(actual, expected))
                   if a != b and not 0x100 <= address < 0x200]
    assert not differences, (context, [f"${a:04X}" for a in differences[:12]])


def test_clears(path):
    statement = """KIND FLAGS NAME_PTR_LO NAME_PTR_HI NAME_LEN NAME_HASH0
        NAME_HASH1 NAME_HASH2 NAME_HASH3 VOC_SLOT OP_KIND OP_ID TAIL_PTR_LO
        TAIL_PTR_HI STATUS""".split()
    session = """SESSION_STATE LAST_STATUS LINE_COUNT_LO LINE_COUNT_HI SYM_COUNT
        SYM_NAME_USED_LO SYM_NAME_USED_HI FIX_COUNT LOCAL_COUNT LOCAL_SCOPE_ACTIVE
        REF_COUNT REPORT_FLAGS FIX_PLAN_NAME_PTR_LO FIX_PLAN_NAME_PTR_HI
        FIX_PLAN_NAME_LEN FIX_PLAN_HASH0 FIX_PLAN_HASH1 FIX_PLAN_HASH2 FIX_PLAN_HASH3
        FIX_PLAN_SEL RELOC_PLAN_TARGET_LO RELOC_PLAN_TARGET_HI RELOC_RESOLVE_FLAGS
        FIX_RESOLVE_COUNT DB_COUNTING PARSE_HEX_DEFAULT EXPORT_COUNT IMPORT_COUNT
        IMPORT_RESOLVE_COUNT PUBLIC_KIND RELOCATE_BASE_LO RELOCATE_BASE_HI
        RELOCATE_COUNT PACKAGE_BASE_LO PACKAGE_BASE_HI PACKAGE_LEN_LO PACKAGE_LEN_HI
        PACKAGE_REL_LEN PACKAGE_BODY_LO PACKAGE_BODY_HI PACKAGE_BODY_LEN_LO
        PACKAGE_BODY_LEN_HI INSTALL_BASE_LO INSTALL_BASE_HI EXPORT_REC_COUNT
        EXPORT_REC_LEN EXPORT_REC_LEN_HI IMPORT_REC_COUNT IMPORT_REC_LEN
        IMPORT_REC_LEN_HI""".split()
    for entry in ("ASM_CLEAR_STMT", "ASM_CLEAR_SESSION"):
        for seed in (1, 91, 254):
            machine = Machine(path)
            sym, memory = machine.sym, machine.memory
            memory[:0x8000] = [(address * 37 + seed) % 255 + 1 for address in range(0x8000)]
            expected = memory.copy()
            if entry == "ASM_CLEAR_STMT":
                addresses = [sym["ASM_STMT_" + name] for name in statement]
            else:
                addresses = [sym["ASM_" + name] for name in session]
                addresses += list(range(sym["ASM_SEAL_REC"], sym["ASM_RELOC_COUNT"] + 1))
            for address in addresses:
                expected[address] = 0
            result = machine.run(entry)
            assert result == (0x59, False) and machine.cpu.y == 0x37, (entry, seed, result)
            same_memory_except_stack(memory, expected, (entry, seed))
    print("PASS 6 exact state-clear cases on nonzero RAM, including unrelated-field guards", flush=True)


def test_init(path):
    # Each case is repeated with cold and stale, nonzero warm cached pointers.
    # No init routine or resident service is hooked: the linked init executes.
    cases = [("valid", None, None, True, True),
             ("larger service count", 3, 12, True, True),
             ("bad signature 0", 0, ord("X"), False, False),
             ("bad signature 1", 1, ord("X"), False, False),
             ("old version", 2, 0, False, False),
             ("new version", 2, 2, False, False),
             ("short service count", 3, 10, False, False),
             ("RAM joiner", 5, 0xBF, False, True)]
    cases += [(f"checksum corruption byte {offset}", offset, "xor", False, False)
              for offset in range(27)]
    for label, offset, value, accepted, copied in cases:
        for ready in (0, 1, 255):
            machine = Machine(path)
            sym, memory = machine.sym, machine.memory
            memory[:0x8000] = [(address * 29 + 17) % 255 + 1 for address in range(0x8000)]
            header = [ord("R"), ord("Y"), 1, 11]
            for index in range(11):
                pointer = 0xC123 + index * 0x37
                header += [pointer & 255, pointer >> 8]
            header += [0]
            if offset is not None and value != "xor":
                header[offset] = value
            for byte in header[:-1]:
                header[-1] ^= byte
            if value == "xor":
                header[offset] ^= 0x80
            start = sym["ASM_HIM_SVC_SIG0"]
            memory[start:start + len(header)] = header
            cached = sym["ASM_RJ_JOINER_LO"]
            memory[cached:cached + 22] = [0xF1, 0xEE] * 11
            memory[sym["ASM_RJ_READY"]] = ready
            memory[sym["ASM_RJ_PROGRESS"]] = 0xA5
            expected = memory.copy()
            expected[sym["ASM_RJ_READY"]] = int(accepted)
            expected[sym["ASM_RJ_PROGRESS"]] = 0
            if copied:
                expected[cached:cached + 22] = header[4:26]
            result = machine.run("ASM_RJOIN_INIT")
            assert result[1] == accepted, (label, ready, result)
            if accepted:
                assert result[0] == 1, (label, ready, result)
            same_memory_except_stack(memory, expected, (label, ready))
    print(f"PASS {len(cases) * 3} unhooked service-init header/checksum/cold/warm cases", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asm-image", type=Path,
                        default=ROOT / "BUILD/s19/asm-v1-flash-8000.s19")
    options = parser.parse_args()
    test_opcodes(options.asm_image)
    test_clears(options.asm_image)
    test_init(options.asm_image)


if __name__ == "__main__":
    main()
