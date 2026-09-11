#!/usr/bin/env python3
"""Focused host smoke test for the fixed-load Microchess AP body."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


def map_address(path: pathlib.Path, symbol: str) -> int:
    pattern = re.compile(rf"^\s*([0-9A-Fa-f]{{8}})\s+{re.escape(symbol)}\s*$")
    for line in path.read_text(encoding="ascii").splitlines():
        match = pattern.match(line)
        if match:
            return int(match.group(1), 16) & 0xFFFF
    raise ValueError(f"missing map symbol: {symbol}")


def package_body(path: pathlib.Path) -> tuple[int, bytes]:
    package = path.read_bytes()
    if package[:3] != b"AP\x02" or int.from_bytes(package[3:5], "little") != len(package):
        raise ValueError("invalid AP-v2 envelope")
    offset = 5
    origin = None
    body = None
    for expected in b"SREIB":
        if package[offset] != expected:
            raise ValueError(f"expected section {chr(expected)} at {offset:#x}")
        length = int.from_bytes(package[offset + 1 : offset + 3], "little")
        payload = package[offset + 3 : offset + 3 + length]
        if expected == ord("S"):
            origin = int.from_bytes(payload[1:3], "little")
        elif expected == ord("B"):
            body = bytes(payload)
        offset += 3 + length
    if offset != len(package) or origin is None or body is None:
        raise ValueError("incomplete AP-v2 envelope")
    return origin, body


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True, type=pathlib.Path)
    parser.add_argument("--map", required=True, type=pathlib.Path)
    parser.add_argument("--py65-root", required=True, type=pathlib.Path)
    args = parser.parse_args()

    sys.path.insert(0, str(args.py65_root))
    from py65.devices.mpu65c02 import MPU  # type: ignore

    origin, body = package_body(args.package)
    entry = map_address(args.map, "MICROCHESS")
    input_adapter = map_address(args.map, "syskin")
    char_adapter = map_address(args.map, "syschout")
    hex_adapter = map_address(args.map, "syshexout")

    memory = [0] * 0x10000
    memory[origin : origin + len(body)] = body
    mpu = MPU(memory=memory, pc=entry)

    # Model a caller whose JSR has left its return address on page one.
    sentinel = 0x7D00
    mpu.sp = 0xF0
    return_minus_one = (sentinel - 1) & 0xFFFF
    memory[0x1F1] = return_minus_one & 0xFF
    memory[0x1F2] = return_minus_one >> 8

    # Reset, take the canned first move, enter a non-book reply ($62->$42),
    # force a real search, then quit.
    keys = iter(b"cp6242\rpq")
    output: list[str] = []

    def emulate_rts() -> None:
        low = memory[0x100 + ((mpu.sp + 1) & 0xFF)]
        high = memory[0x100 + ((mpu.sp + 2) & 0xFF)]
        mpu.sp = (mpu.sp + 2) & 0xFF
        mpu.pc = (((high << 8) | low) + 1) & 0xFFFF

    for _ in range(20_000_000):
        if mpu.pc == sentinel:
            break
        if mpu.pc == input_adapter:
            try:
                mpu.a = next(keys)
            except StopIteration as exc:
                raise AssertionError("Microchess requested unexpected extra input") from exc
            emulate_rts()
            continue
        if mpu.pc == char_adapter:
            output.append(chr(mpu.a & 0x7F))
            # Console ABI does not preserve N/Z.  Force Z so an application
            # branch cannot accidentally depend on the character's flags.
            mpu.p |= mpu.ZERO
            emulate_rts()
            continue
        if mpu.pc == hex_adapter:
            output.append(f"{mpu.a:02X}")
            mpu.p |= mpu.ZERO
            emulate_rts()
            continue
        mpu.step()
    else:
        raise AssertionError("Microchess did not return within the instruction budget")

    rendered = "".join(output)
    if "MicroChess (c) 1976 Peter Jennings benlo.com - R-YORS AP" not in rendered:
        raise AssertionError("copyright banner was not rendered")
    if rendered.count("00 01 02 03 04 05 06 07") < 3:
        raise AssertionError("board was not rendered before each command")
    if memory[0x005F] != 0x33:
        board = " ".join(f"{value:02X}" for value in memory[0x0050:0x0070])
        raise AssertionError(
            f"the canned first move did not move piece $0F to square $33; "
            f"OMOVE={memory[0x00DC]:02X} board={board}"
        )
    if memory[0x006C] != 0x42:
        raise AssertionError("the human $62->$42 move was not applied")
    if memory[0x1B00] != 0xF0 or mpu.sp != 0xF2:
        raise AssertionError("AP caller stack was not restored before RTS")
    if mpu.a != 0xAC or not (mpu.p & mpu.CARRY):
        raise AssertionError("AP did not return A=$AC with carry set")

    print("Microchess runtime smoke passed: reset, opening move, human move, searched reply, Q return")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
