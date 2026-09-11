"""Assemble the MicroChess .a with the real ASM-F2 image under py65."""

from pathlib import Path
import argparse
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.dont_write_bytecode = True
import check_asm_errors as asmcheck


class LongSessionMachine(asmcheck.Machine):
    def run(self, name, a=0, xy=0, stop=None):
        c = self.cpu
        c.pc, c.a, c.x, c.y = asmcheck.ASM[name], a, xy & 255, xy >> 8
        c.sp, c.p = 0xFD, 0x20
        self.m[0x1FE:0x200] = [0xEF, 0x1F]
        limit = asmcheck.ASM[stop] if stop else 0x1FF0
        for _ in range(30_000_000):
            if c.pc == limit:
                return c.a, bool(c.p & 1), c.x | c.y << 8
            if c.pc in self.hooks:
                self.hooks[c.pc]()
            else:
                assert self.m[c.pc] != 0, (
                    f"unexpected BRK at {c.pc:04X} in {name}")
                c.step()
        raise AssertionError(f"instruction limit in {name} at {c.pc:04X}")


def package_from_memory(memory, address):
    assert bytes(memory[address:address + 3]) == b"AP\x02"
    length = memory[address + 3] | memory[address + 4] << 8
    return bytes(memory[address:address + length])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--host-package", type=Path, required=True)
    args = parser.parse_args()

    source_text = args.source.read_text(encoding="ascii")
    assert "OpenAI Codex, an AI coding system" in source_text
    assert "This does not alter upstream copyright" in source_text
    lines = source_text.splitlines()
    machine = LongSessionMachine()
    result = machine.session(
        lines + ["SEAL", "PACKAGE MICROCHESS $3000", "."])
    errors = [line for line in machine.output.splitlines() if "ERR" in line]
    assert result[:2] == (0, True), (result, errors, machine.output[-1000:])
    for expected in (
            "ASM OK\r\n", "SEAL OK", "PKG OK @=$3000", "ASM BYE\r\n"):
        assert expected in machine.output, (expected, machine.output[-1000:])

    onboard = package_from_memory(machine.m, 0x3000)
    host = args.host_package.read_bytes()
    if onboard != host:
        differences = [
            f"{index:04X}:{left:02X}!={right:02X}"
            for index, (left, right) in enumerate(zip(onboard, host))
            if left != right
        ]
        raise AssertionError(
            f"onboard package differs: ASM-F2={len(onboard)} host={len(host)}; "
            + ", ".join(differences[:24]))
    print(
        "Microchess onboard ASM-F2 check passed: "
        f"{len(lines)} source lines, exact {len(onboard)}-byte AP")


if __name__ == "__main__":
    main()
