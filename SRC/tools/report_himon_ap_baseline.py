"""Measure emitted HIMON/AP ownership from linked symbols and checked S-records.

Run from the repository root:
  python SRC/tools/report_himon_ap_baseline.py --build-dir SRC/BUILD \
      --markdown DOC/GENERATED/HIMON_AP_BASELINE.md --json path/to/ledger.json

Ranges are physical ownership groups, not estimates of removable code. Embedded
tables/FNV records stay with their containing block. Shared routines count once.
This report does not assign new RAM or prove runtime stack/lifetime bounds.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


# Start inclusive, end exclusive. Keep semantic boundaries explicit: sorting
# label names alone misattributes local labels, aliases and non-emitted equates.
HIMON_GROUPS = [
    ('ap', 'AP/APS command adapters and FNV records', 'CMD_AP_FNV', 'CMD_L_FNV'),
    ('ap', 'Manager discovery/bootstrap and bank staging', 'HIM_APMAN_BOOTSTRAP', 'HIM_AP_SERVICE'),
    ('ap', 'Service dispatch and load orchestration', 'HIM_AP_SERVICE', 'HIM_AP_PARSE_MIN'),
    ('ap', 'Package parsing, validation and source bounds', 'HIM_AP_PARSE_MIN', 'HIM_AP_LOAD_RANGE_OK'),
    ('ap', 'Destination bounds, copy and internal relocation', 'HIM_AP_LOAD_RANGE_OK', 'HIM_AP_IMPORT_LINK'),
    ('ap', 'Typed import orchestration and signed addend', 'HIM_AP_IMPORT_LINK', 'HIM_AP_LINK_RESOLVE_SLOT_X'),
    ('ap', 'HIMON-owned typed-import provider (AP functional subtotal)', 'HIM_AP_LINK_RESOLVE_SLOT_X', 'HIM_AP_LINK_IMPORT_ROW_PTR_X'),
    ('ap', 'Import row walking and relocation patching', 'HIM_AP_LINK_IMPORT_ROW_PTR_X', 'HIM_AP_FIND_HOLE'),
    ('ap', 'Hole suggestion and shared AP error exits', 'HIM_AP_FIND_HOLE', 'L_NOTE_S1_ADDR'),
    ('ap', 'AP usage and manager-not-found strings', 'MSG_USAGE_AP', 'MSG_USAGE_L'),
    ('ap', 'AP error prefix', 'MSG_AP_ERR', 'MSG_L_READY'),
    ('shared', 'High-bit string output', 'HIM_WRITE_HBSTRING', 'MON_CTX_REQUIRE_VALID'),
    ('shared', 'PACK40 primitives', 'HIM_PACK40_ASCII_TO_CODE', 'HIM_APMAN_BOOTSTRAP'),
    ('shared', 'Resident catalog/resolver, including catalog UI helpers', 'THE_JOIN_EXEC_XY_FNV', 'FNV1A_INIT_FNV'),
    ('shared', 'FNV and arithmetic, including inline records/basis', 'FNV1A_INIT_FNV', 'CMD_REQUIRE_EOL'),
    ('shared', 'Monitor token/parser primitives', 'CMD_REQUIRE_EOL', 'MON_BOOTLOG_RESET'),
    ('shared', 'Linked library console/flash/debug/hex primitives', 'BIO_FTDI_READ_BYTE_NONBLOCK', '_END_CODE'),
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def symbols(path):
    result = {}
    for address, name in re.findall(r'^\s*([0-9a-fA-F]{8})\s+(\w+)\s*$', path.read_text(), re.M):
        value = int(address, 16)
        if name in result and result[name] != value:
            raise ValueError(f'Conflicting symbol {name} in {path}')
        result[name] = value
    return result


def srecord(path):
    memory = {}
    for line in path.read_text().splitlines():
        if not line:
            continue
        if line[:2] not in ('S0', 'S1', 'S5', 'S9'):
            raise ValueError(f'Unsupported S-record in {path}: {line[:2]}')
        raw = bytes.fromhex(line[2:])
        if len(raw) != raw[0] + 1 or sum(raw) & 255 != 255:
            raise ValueError(f'Bad S-record checksum/count in {path}')
        if line.startswith('S1'):
            address = int.from_bytes(raw[1:3], 'big')
            for offset, value in enumerate(raw[3:-1]):
                site = address + offset
                if site in memory or site > 0xFFFF:
                    raise ValueError(f'Overlapping/out-of-range S-record in {path}')
                memory[site] = value
    if not memory:
        raise ValueError(f'No emitted bytes: {path}')
    return memory


def spans(addresses):
    result = []
    for address in sorted(addresses):
        if result and address == result[-1][1]:
            result[-1][1] += 1
        else:
            result.append([address, address + 1])
    return result


def image(build, name, begin, end_symbol, limit):
    spath = build / 's19' / (name + '.s19')
    mpath = spath.with_suffix('.map')
    sym, memory = symbols(mpath), srecord(spath)
    end = sym[end_symbol]
    if not begin < end <= limit:
        raise ValueError(f'Invalid image bounds: {name}')
    expected = set(range(begin, end))
    if set(memory) != expected:
        raise ValueError(f'{name}: map span and S19 bytes disagree; audit holes/extra records')
    data = bytes(memory[a] for a in range(begin, end))
    padded = data + b'\xff' * (limit - end)
    result = dict(name=name, start=begin, end_exclusive=end, emitted_bytes=len(data),
                  holes=0, limit=limit, headroom=limit-end, dense_bytes=len(padded),
                  body_sha256=sha(data), dense_sha256=sha(padded),
                  s19_sha256=sha(spath.read_bytes()), map_sha256=sha(mpath.read_bytes()))
    if '_BEG_DATA' in sym:
        result['code_section_bytes'] = sym['_END_CODE'] - sym['_BEG_CODE']
        result['data_section_bytes'] = sym['_END_DATA'] - sym['_BEG_DATA']
        if result['code_section_bytes'] + result['data_section_bytes'] != len(data):
            raise ValueError(f'CODE/DATA accounting mismatch: {name}')
    if '_BEG_UDATA' in sym:
        result['udata'] = [sym['_BEG_UDATA'], sym['_END_UDATA']]
    return result, sym, memory, padded


def report(build):
    himon, sym, memory, _ = image(build, 'himon-rom-c000', 0xC000, '_END_DATA', 0xF000)
    asm, _, _, _ = image(build, 'asm-v1-flash-8000', 0x8000, '_END_DATA', 0xC000)
    manager, msym, mmemory, _ = image(build, 'apman-7000', 0x6C00, 'APMAN_IMAGE_END', 0x7C00)
    owners = {}
    rows = []
    for owner, label, first, last in HIMON_GROUPS:
        start, end = sym[first], sym[last]
        if not 0xC000 <= start < end <= himon['end_exclusive']:
            raise ValueError(f'Invalid ownership range {label}')
        for a in range(start, end):
            if a not in memory or a in owners:
                raise ValueError(f'Missing/overlapping ownership at ${a:04X}: {label}')
            owners[a] = owner
        rows.append(dict(owner=owner, label=label, start_symbol=first, end_symbol=last,
                         spans=[[start, end]], bytes=end-start))
    for section, start, end in [('CODE', sym['_BEG_CODE'], sym['_END_CODE']),
                                ('DATA', sym['_BEG_DATA'], sym['_END_DATA'])]:
        remainder = set(range(start, end)) - owners.keys()
        rows.append(dict(owner='himon', label=f'Other HIMON {section} (incl. embedded tables/records)',
                         spans=spans(remainder), bytes=len(remainder)))
    totals = {owner: sum(row['bytes'] for row in rows if row['owner'] == owner)
              for owner in ['ap', 'shared', 'himon']}
    if sum(totals.values()) != himon['emitted_bytes']:
        raise ValueError('HIMON ownership totals do not reconcile')
    package_path = build / 'bin/apman-v1.ap'
    package = package_path.read_bytes()
    if package[:3] != b'AP\x02' or int.from_bytes(package[3:5], 'little') != len(package):
        raise ValueError('Invalid APMAN envelope header')
    sections, offset, body = [], 5, None
    while offset < len(package):
        tag = chr(package[offset])
        size = int.from_bytes(package[offset+1:offset+3], 'little')
        end = offset + 3 + size
        if end > len(package):
            raise ValueError('APMAN section overrun')
        sections.append(dict(tag=tag, offset=offset, bytes=size, end_exclusive=end))
        if tag == 'B':
            body = package[offset+3:end]
        offset = end
    if ''.join(row['tag'] for row in sections) != 'SREIB':
        raise ValueError('Unexpected AP section sequence')
    if body != bytes(mmemory[a] for a in sorted(mmemory)):
        raise ValueError('APMAN package BODY differs from linked S19')
    carrier = (build / 'bin/apman-v1-bank2-8000.bin').read_bytes()
    if carrier != package + b'\xff' * (0x1000-len(package)):
        raise ValueError('APMAN carrier is not exact package plus erased padding')
    manager.update(package_bytes=len(package), envelope_overhead=len(package)-len(body),
                   package_sha256=sha(package), carrier_bytes=len(carrier),
                   carrier_sha256=sha(carrier), carrier_tail_bytes=len(carrier)-len(package),
                   worker_bytes=msym['APMAN_WORKER_IMAGE_END']-msym['APMAN_WORKER_IMAGE'],
                   sections=sections, raw_linker_end_code=msym['_END_CODE'])
    return dict(schema=1, images=[himon, asm, manager], himon_ownership=rows,
                himon_totals=totals, himon_excluding_dedicated_ap=himon['emitted_bytes']-totals['ap'])


def markdown(data):
    lines = ['# HIMON/AP linked baseline', '',
             'Generated by `SRC/tools/report_himon_ap_baseline.py`. Do not edit manually.', '',
             'All ranges below are inclusive; JSON endpoints are exclusive. Counts come from',
             'linked symbols reconciled against every emitted S19 byte. No image has holes.', '',
             '| Image | Emitted range | Bytes | Contiguous headroom |',
             '| --- | --- | ---: | ---: |']
    for row in data['images']:
        lines.append(f"| {row['name']} | `${row['start']:04X}-${row['end_exclusive']-1:04X}` | {row['emitted_bytes']:,} | {row['headroom']:,} |")
    lines += ['', '## HIMON physical byte ownership', '',
              'Shared groups are counted once and remain physically linked with HIMON.',
              'The AP subtotal includes its monitor adapters; source ownership is shown',
              'explicitly for the typed-import provider without changing that subtotal.',
              'These counts do not predict bytes saved or routines safe to remove. The',
              'catalog group includes its UI helpers; linked library code includes flash',
              'and debugger support. Other HIMON includes initialization, MicroChess alias,',
              'monitor/debug/S19 logic, metadata and remaining tables/strings.', '',
              '| Owner | Block | Emitted ranges | Bytes |', '| --- | --- | --- | ---: |']
    for row in data['himon_ownership']:
        ranges = ', '.join(f'`${a:04X}-${b-1:04X}`' for a,b in row['spans'])
        lines.append(f"| {row['owner']} | {row['label']} | {ranges} | {row['bytes']:,} |")
    lines += ['', '| Owner | Total bytes |', '| --- | ---: |']
    for key, value in data['himon_totals'].items():
        lines.append(f'| {key} | {value:,} |')
    lines += [f"| HIMON excluding dedicated AP, including shared | {data['himon_excluding_dedicated_ap']:,} |", '',
              'CODE/DATA are assembler sections, not an opcode-versus-table classification.',
              'Inline tables, FNV records and stored RAM workers remain in their containing',
              'physical blocks. EQU/IF-0 declarations contribute no bytes.', '', '## Image accounting', '']
    for row in data['images'][:2]:
        lines.append(f"- {row['name']}: CODE {row['code_section_bytes']:,}, DATA {row['data_section_bytes']:,}; dense component {row['dense_bytes']:,} bytes including {row['headroom']:,} bytes of FF padding.")
    manager = data['images'][2]
    ustart, uend = data['images'][1]['udata']
    lines += [f"- APMAN: BODY {manager['emitted_bytes']:,}, envelope overhead {manager['envelope_overhead']:,}, package {manager['package_bytes']:,}, carrier {manager['carrier_bytes']:,}, erased carrier tail {manager['carrier_tail_bytes']:,} bytes.",
              f"- APMAN contains {manager['worker_bytes']:,} stored worker bytes; they are already included in BODY.",
              f"- APMAN raw linker `_END_CODE=${manager['raw_linker_end_code']:04X}` is not its CPU end. Use `APMAN_IMAGE_END=${manager['end_exclusive']:04X}`, confirmed by S19 and package BODY.", '',
              f'ASM UDATA is `${ustart:04X}-${uend-1:04X}` ({uend-ustart:,} allocated bytes), not emitted ROM.',
              f"APMAN overlays `${manager['start']:04X}-${manager['end_exclusive']-1:04X}`; its {manager['headroom']}-byte gap ends at `${manager['limit']:04X}`.",
              'Neither allocation proves runtime high-water or maximum stack use. Those',
              'lifetime/stack questions belong to the next audit; no new RAM is assigned.', '',
              'Bank-3 component allocation remains four ASM sectors plus three HIMON sectors.',
              'The STR8-N top sector is separate. APMAN consumes one external 4K carrier',
              'sector when installed; package size and occupied flash sectors are distinct.', '',
              '## Artifact identities', '', '| Artifact | SHA-256 |', '| --- | --- |']
    for row in data['images']:
        for kind in ['s19', 'map', 'body', 'dense']:
            lines.append(f"| {row['name']} {kind} | `{row[kind+'_sha256']}` |")
    lines += [f"| APMAN package | `{manager['package_sha256']}` |",
              f"| APMAN carrier | `{manager['carrier_sha256']}` |", '',
              'Dense hashes are S19 body plus FF to the stated limit; APMAN dense means',
              'the RAM overlay envelope, not its flash carrier. Accepted board identity and',
              'build provenance are recorded separately in the dated qualification record.', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=Path('SRC/BUILD'))
    parser.add_argument('--markdown', type=Path, required=True)
    parser.add_argument('--json', type=Path, required=True)
    args = parser.parse_args()
    data = report(args.build_dir)
    for path, content in [(args.markdown, markdown(data)), (args.json, json.dumps(data, indent=2)+'\n')]:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8', newline='\n')
    print(json.dumps({'himon_totals': data['himon_totals'],
                      'image_bytes': {x['name']: x['emitted_bytes'] for x in data['images']}}, indent=2))


if __name__ == '__main__':
    main()
