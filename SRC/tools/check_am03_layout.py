"""Check AM03 tray limits and the accepted board's child destinations."""
import argparse
import hashlib
import json
from pathlib import Path

from report_himon_ap_baseline import srecord, symbols

ROOT = Path(__file__).resolve().parents[2]


def sections(package):
    assert package[:3] == b'AP\x02'
    length = int.from_bytes(package[3:5], 'little')
    assert 5 <= length <= len(package)
    cursor = 5
    found = {}
    for tag in b'SREIB':
        assert package[cursor] == tag
        size = int.from_bytes(package[cursor+1:cursor+3], 'little')
        end = cursor+3+size
        assert end <= length
        found[chr(tag)] = package[cursor+3:end]
        cursor = end
    assert cursor == length
    return length, found


def decode_name(row):
    alphabet = '\0ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?.'
    count = row[7]
    packed = row[8:8+2*((count+2)//3)]
    output = []
    for index in range(0, len(packed), 2):
        value = int.from_bytes(packed[index:index+2], 'little')
        codes = (value//1600, (value//40)%40, value%40)
        output.extend(alphabet[code] for code in codes)
    return ''.join(output[:count])


def package_facts(data):
    length, found = sections(data)
    seal = found['S']
    exports = found['E']
    assert len(seal) == 11 and seal[0] == 1 and exports[0] >= 1
    name = decode_name(exports[1:])
    return dict(name=name, package_length=length,
                preferred_base=int.from_bytes(seal[1:3], 'little'),
                preferred_end=int.from_bytes(seal[3:5], 'little'),
                body_length=int.from_bytes(seal[5:7], 'little'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=ROOT/'SRC/BUILD')
    parser.add_argument('--readback-dir', type=Path,
        default=ROOT/'DOC/GUIDES/LOGS/RAM_AP_HANDOFF_2026-09-16/final')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()

    image = srecord(args.build_dir/'s19/apman-7000.s19')
    sym = symbols(args.build_dir/'s19/apman-7000.map')
    package = (args.build_dir/'bin/apman-v1.ap').read_bytes()
    carrier = (args.build_dir/'bin/apman-v1-bank2-8000.bin').read_bytes()
    facts = package_facts(package)
    assert min(image) == facts['preferred_base'] == sym['APMAN_ENTRY'] == 0x6C00
    assert max(image)+1 == facts['preferred_end'] == sym['APMAN_IMAGE_END']
    assert facts['body_length'] == len(image) <= 0x1000
    assert facts['preferred_end'] <= 0x7C00
    assert facts['name'] == 'APMAN'
    marker = bytes(image[a] for a in range(sym['APMAN_ENTRY']+2, sym['APMAN_ENTRY']+6))
    assert marker == b'AM03'
    assert carrier[:len(package)] == package
    assert carrier[len(package):] == b'\xFF'*(0x1000-len(package))

    children = []
    for bank in range(3):
        bank_image = srecord(args.readback_dir/f'bank{bank}.s19')
        for sector in range(8, 16):
            start = 0x8000+(sector-8)*0x1000
            data = bytes(bank_image.get(address, 0xFF)
                         for address in range(start, start+0x1000))
            if data[:3] != b'AP\x02':
                continue
            child = package_facts(data)
            child.update(location=f'B{bank}:{sector:X}',
                         sha256=hashlib.sha256(data).hexdigest())
            if child['name'] != 'APMAN':
                assert child['body_length'] > 0
                assert child['preferred_end'] <= 0x6C00, child
            children.append(child)

    assert any(row['name'] == 'APMAN' and row['location'] == 'B2:8' for row in children)
    report = dict(result='PASS', candidate='AM03', manager=facts,
                  body_free=0x1000-facts['body_length'],
                  carrier_free=0x1000-len(package),
                  child_ceiling='6C00',
                  accepted_srecord_readback=str(args.readback_dir),
                  carriers=children)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(f'PASS AM03 body {facts["body_length"]} bytes; '
          f'{0x1000-facts["body_length"]} tray bytes free; '
          f'{len(children)-1} child carriers end below $6C00')


if __name__ == '__main__':
    main()
