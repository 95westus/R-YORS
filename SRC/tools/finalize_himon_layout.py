"""Validate HIMON's fixed message page and emit its dense, FF-padded S19.

The linker owns CODE/DATA below $EF00 and HIMMSGPAGE at $EF00. Only the
intentional gaps after those sections may be filled. No missing linked bytes,
overlap, or out-of-component records are silently repaired. The map retains
the true core endpoint; padding is an image property, not occupied code/data.
The finalized S9 start is HIMON's START=$C000, not WDC's unset $0000 default.
"""
import argparse
from pathlib import Path


BEGIN = 0xC000
PAGE = 0xEF00
LIMIT = 0xF000


def layout(symbols, memory, *, require_dense=False):
    required = ('START', '_BEG_CODE', '_END_CODE', '_BEG_DATA', '_END_DATA',
                'HIM_CORE_END', 'HIM_MESSAGE_PAGE', 'HIM_MESSAGE_PAGE_END',
                '_BEG_HIMMSGPAGE', '_END_HIMMSGPAGE')
    for name in required:
        if name not in symbols:
            raise ValueError(f'HIMON layout symbol missing: {name}')
    core_end = symbols['_END_DATA']
    page_end = symbols['HIM_MESSAGE_PAGE_END']
    if symbols['START'] != BEGIN:
        raise ValueError('HIMON START must remain $C000')
    if not (symbols['_BEG_CODE'] == BEGIN
            < symbols['_END_CODE'] == symbols['_BEG_DATA']
            <= core_end == symbols['HIM_CORE_END'] <= PAGE):
        raise ValueError('HIMON core must be contiguous CODE/DATA below $EF00')
    if not (symbols['_BEG_HIMMSGPAGE'] == symbols['HIM_MESSAGE_PAGE'] == PAGE
            < page_end == symbols['_END_HIMMSGPAGE'] <= LIMIT):
        raise ValueError('HIMON messages must fit the fixed $EF00-$EFFF page')
    used = set(range(BEGIN, core_end)) | set(range(PAGE, page_end))
    component = set(range(BEGIN, LIMIT))
    padding = component - used
    if not used <= memory.keys():
        raise ValueError('HIMON S19 is missing linked code/data/message bytes')
    if not memory.keys() <= component:
        raise ValueError('HIMON S19 emits bytes outside $C000-$EFFF')
    if any(memory[a] != 0xFF for a in padding & memory.keys()):
        raise ValueError('HIMON intentional padding contains non-FF bytes')
    if require_dense and memory.keys() != component:
        raise ValueError('HIMON S19 must emit every byte in $C000-$EFFF')
    return dict(core_end=core_end, message_start=PAGE, message_end=page_end,
                core_bytes=core_end-BEGIN, message_bytes=page_end-PAGE,
                used_bytes=len(used), padding_bytes=len(padding),
                core_headroom=PAGE-core_end, message_headroom=LIMIT-page_end,
                used_spans=[[BEGIN, core_end], [PAGE, page_end]],
                padding_spans=[[a, b] for a, b in
                               [(core_end, PAGE), (page_end, LIMIT)] if a < b])


def record(kind, address, payload=b''):
    raw = bytes([len(payload)+3, address >> 8, address & 255]) + payload
    return f'S{kind}' + (raw + bytes([(~sum(raw)) & 255])).hex().upper()


def check_start(lines, *, finalized=False):
    starts = [line for line in lines if line.startswith('S9')]
    if len(starts) != 1:
        raise ValueError('HIMON S19 must contain exactly one S9 start record')
    raw = bytes.fromhex(starts[0][2:])
    if len(raw) != 4 or raw[0] != 3 or sum(raw) & 255 != 255:
        raise ValueError('Invalid HIMON S9 start record')
    address = int.from_bytes(raw[1:3], 'big')
    if address not in ((BEGIN,) if finalized else (0, BEGIN)):
        raise ValueError('HIMON S9 must be $C000 (or unset $0000 before finalizing)')


def dense_srecord(memory, original_lines):
    headers = [line for line in original_lines if line.startswith('S0')]
    check_start(original_lines)
    lines = headers + [record('1', address, bytes(memory.get(a, 0xFF)
                                                for a in range(address, address+32)))
                       for address in range(BEGIN, LIMIT, 32)]
    if any(line.startswith('S5') for line in original_lines):
        lines.append(record('5', (LIMIT-BEGIN)//32))
    return '\n'.join(lines + [record('9', BEGIN)]) + '\n'


def main():
    # Keep the parser shared with the ownership report; that report imports
    # layout(), so defer this import until its CLI-independent functions exist.
    from report_himon_ap_baseline import srecord, symbols
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--s19', type=Path, required=True)
    parser.add_argument('--map', type=Path, required=True)
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    memory = srecord(args.s19)
    original_lines = args.s19.read_text().splitlines()
    check_start(original_lines, finalized=args.check_only)
    info = layout(symbols(args.map), memory, require_dense=args.check_only)
    if not args.check_only:
        content = dense_srecord(memory, original_lines)
        temporary = args.s19.with_suffix(args.s19.suffix + '.tmp')
        temporary.write_text(content, encoding='ascii', newline='\n')
        # Verify the actual serialized image before replacing the link output.
        layout(symbols(args.map), srecord(temporary), require_dense=True)
        check_start(temporary.read_text().splitlines(), finalized=True)
        temporary.replace(args.s19)
    print(f"HIMON layout = PASS; core end=${info['core_end']:04X}; "
          f"messages={info['message_bytes']}; used={info['used_bytes']}; "
          f"FF padding={info['padding_bytes']} "
          f"(core room={info['core_headroom']}, page room={info['message_headroom']}); "
          f"dense bytes={LIMIT-BEGIN}; S9=${BEGIN:04X}")


if __name__ == '__main__':
    main()
