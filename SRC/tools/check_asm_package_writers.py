"""Check linked ASM-F2 AP writers against independent AP-v2/PACK40 records.

Uses the actual ASM and HIMON routines through check_asm_errors.Machine.
Run from SRC: python -B tools/check_asm_package_writers.py [--asm-image FILE]
No board I/O. Requires the existing BUILD/tmp/asm-error-deps py65 install.
"""

import argparse
from pathlib import Path

import check_asm_errors as harness


def word(value):
    return (value & 0xFFFF).to_bytes(2, "little")


def fnv(data):
    value = 0x811C9DC5
    for byte in data:
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return value.to_bytes(4, "little")


def pack40(name):
    alphabet = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?."
    codes = [alphabet.index(char.upper()) for char in name]
    codes += [0] * (-len(codes) % 3)
    return b"".join(word(a * 1600 + b * 40 + c)
                    for a, b, c in zip(codes[::3], codes[1::3], codes[2::3]))


def names(count, length=None):
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?."
    return ["".join(alphabet[(i * 7 + j * 11) % len(alphabet)]
                    for j in range(length or (i * 13 % 32 + 1)))
            for i in range(count)]


def indexed(machine, name, index, value):
    machine.m[harness.ASM[name] + index] = value


def fixture(export_names, import_names, body=b"", reloc_count=0):
    """Seed records directly, including nonsequential symbol slots and borrows."""
    machine = harness.Machine()
    source = 0x20F3
    machine.word("ASM_SEAL_BASE_LO", source)
    machine.word("ASM_SEAL_END_LO", source + len(body))
    machine.word("ASM_SEAL_LEN_LO", len(body))
    machine.byte("ASM_SEAL_FLAGS", 1)
    machine.m[source:source + len(body)] = body
    machine.byte("ASM_EXPORT_COUNT", len(export_names))
    machine.byte("ASM_IMPORT_COUNT", len(import_names))
    export_record = bytearray([len(export_names)])
    import_record = bytearray([len(import_names)])
    name_address = harness.ASM["ASM_SYM_NAMES"] + 0xF9
    for i, name in enumerate(export_names):
        slot = (127 + i * 37) % 128
        name_offset = name_address - harness.ASM["ASM_SYM_NAMES"]
        # The first value $2100 minus base $20F3 exercises low-byte borrow.
        offset = (13 + i * 3) % len(body) if body else 13 + i * 3
        value = source + offset
        kind = 0x81 if i == 0 else (1 if i & 1 else 2)
        digest = fnv(name.upper().encode("ascii"))
        indexed(machine, "ASM_EXPORT_SYM_SLOT", i, slot)
        indexed(machine, "ASM_EXPORT_KIND", i, kind)
        for label, byte in (("ASM_SYM_NAME_OFF_LO", name_offset & 255),
                            ("ASM_SYM_NAME_OFF_HI", name_offset >> 8),
                            ("ASM_SYM_NAME_LEN", len(name)),
                            ("ASM_SYM_VAL_LO", value & 255),
                            ("ASM_SYM_VAL_HI", value >> 8)):
            indexed(machine, label, slot, byte)
        for j, byte in enumerate(digest):
            indexed(machine, f"ASM_SYM_HASH{j}", slot, byte)
        encoded = name.encode("ascii")
        machine.m[name_address:name_address + len(encoded)] = encoded
        name_address += len(encoded)
        export_record += bytes([kind]) + word(offset) + digest
        export_record += bytes([len(name)]) + pack40(name)
    assert name_address <= harness.ASM["ASM_LOW_FIX_NAMES"], "fixture exceeds symbol name pool"
    for i, name in enumerate(import_names):
        kind = 1 if i & 1 else 2
        digest = fnv(name.upper().encode("ascii"))
        packed = pack40(name)
        indexed(machine, "ASM_IMPORT_KIND", i, kind)
        indexed(machine, "ASM_IMPORT_NAME_LEN", i, len(name))
        for j, byte in enumerate(digest):
            indexed(machine, f"ASM_IMPORT_HASH{j}", i, byte)
        address = harness.ASM["ASM_IMPORT_NAME_PACKS"] + i * 22
        machine.m[address:address + 22] = [0xD3] * 22
        machine.m[address:address + len(packed)] = packed
        import_record += bytes([kind]) + digest + bytes([len(name)]) + packed
    machine.byte("ASM_RELOC_COUNT", reloc_count)
    columns = [[2 if len(body) == 1 else 1 + i % 3 for i in range(reloc_count)],
               [(i * 3) & 255 for i in range(reloc_count)],
               [0] * reloc_count,
               [(i * 5) % max(1, len(body)) & 255 for i in range(reloc_count)],
               [((i * 5) % max(1, len(body))) >> 8 for i in range(reloc_count)]]
    for label, values in zip(("ASM_RELOC_KIND", "ASM_RELOC_SITE_LO", "ASM_RELOC_SITE_HI",
                              "ASM_RELOC_TARGET_LO", "ASM_RELOC_TARGET_HI"), columns):
        address = harness.ASM[label]
        machine.m[address:address + 64] = [0xD7] * 64
        machine.m[address:address + len(values)] = values
    reloc_record = bytes([reloc_count]) + b"".join(bytes(column) for column in columns)
    seal = bytes([1]) + word(source) + word(source + len(body)) + word(len(body)) + fnv(body)
    return machine, bytes(export_record), bytes(import_record), reloc_record, seal


def checked_write(machine, entry, expected, destination=0x30FD, package=False):
    guard = 16
    begin, end = destination - guard, destination + len(expected) + guard
    machine.m[begin:end] = [0xA5] * (end - begin)
    if package:
        result = machine.run(entry, xy=destination)
        assert result == (0, True, destination), (entry, result)
        assert machine.word("ASM_PACKAGE_LEN_LO") == len(expected)
    else:
        machine.word("ASM_EMIT_PTR_LO", destination)
        machine.run(entry)
    actual = bytes(machine.m[destination:destination + len(expected)])
    assert actual == expected, (entry, len(expected), actual.hex(), expected.hex())
    assert machine.word("ASM_EMIT_PTR_LO") == destination + len(expected), entry
    assert machine.m[begin:destination] == [0xA5] * guard, (entry, "leading guard")
    assert machine.m[destination + len(expected):end] == [0xA5] * guard, (entry, "trailing guard")


def test_records():
    cases = [(names(count), names(count)) for count in (0, 1, 2, 7, 63, 64)]
    cases += [(names(1, length), names(1, length)) for length in range(1, 33)]
    cases += [(["ABC", "A_?", ".9Z", "LONG_SYMBOL_NAME_1234567890"],
               ["A", "BC", "DEF", "GHIJ", "KLMNO", "PQRSTU", "VWXYZ01"])]
    for exports, imports in cases:
        machine, export_record, import_record, _, _ = fixture(exports, imports)
        machine.run("ASM_EXPORT_BUILD_RECORD")
        machine.run("ASM_IMPORT_BUILD_RECORD")
        assert machine.byte("ASM_EXPORT_REC_COUNT") == len(exports)
        assert machine.byte("ASM_IMPORT_REC_COUNT") == len(imports)
        assert machine.word("ASM_EXPORT_REC_LEN") == len(export_record)
        assert machine.word("ASM_IMPORT_REC_LEN") == len(import_record)
        checked_write(machine, "ASM_PACKAGE_WRITE_EXPORT_REC", export_record)
        checked_write(machine, "ASM_PACKAGE_WRITE_IMPORT_REC", import_record)
    print(f"PASS {len(cases) * 2} exact export/import records: 0-64 rows, nonsequential slots, "
          "base borrow, names 1-32, PACK40 triples, source/destination page crossings")


def test_packages():
    cases = [(0, 0, 0, 0), (1, 1, 1, 1), (7, 3, 51, 255),
             (3, 7, 52, 256), (63, 64, 63, 257), (64, 63, 64, 511)]
    for export_count, import_count, reloc_count, body_length in cases:
        body = bytes((i * 73 + (i >> 8) * 19 + 0x60) & 255 for i in range(body_length))
        machine, exports, imports, reloc, seal = fixture(names(export_count), names(import_count),
                                                       body, reloc_count)
        sections = ((b"S", seal), (b"R", reloc), (b"E", exports), (b"I", imports), (b"B", body))
        payload = b"".join(tag + word(len(record)) + record for tag, record in sections)
        expected = b"AP\x02" + word(len(payload) + 5) + payload
        assert len(expected) <= 0x1000
        checked_write(machine, "ASM_SEAL_PACKAGE", expected, package=True)
        assert bytes(machine.m[0x20F3:0x20F3 + body_length]) == body
    print(f"PASS {len(cases)} exact complete AP-v2 packages: empty/full records, "
          "relocations 0/1/51/52/63/64, BODY lengths 0/1/255/256/257/511 and guards")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asm-image", type=Path,
                        default=harness.ROOT / "BUILD/s19/asm-v1-flash-8000.s19")
    args = parser.parse_args()
    harness.ASM = harness.symbols(args.asm_image.with_suffix(".map"))
    harness.ROM = [0] * 65536
    harness.load_s19(harness.ROM, args.asm_image)
    harness.load_s19(harness.ROM, harness.ROOT / "BUILD/s19/himon-rom-c000.s19")
    test_records()
    test_packages()
    print(f"PASS ASM-F2 package writer regression ({args.asm_image.name})")


if __name__ == "__main__":
    main()
