"""Boundary/serialization tests for HIMON's dense fixed-message-page layout."""
from finalize_himon_layout import BEGIN, PAGE, LIMIT, check_start, dense_srecord, layout, record


def main():
    symbols = dict(START=BEGIN, _BEG_CODE=BEGIN, _END_CODE=0xE000, _BEG_DATA=0xE000,
                   _END_DATA=0xED8E, HIM_CORE_END=0xED8E,
                   HIM_MESSAGE_PAGE=PAGE, HIM_MESSAGE_PAGE_END=LIMIT,
                   _BEG_HIMMSGPAGE=PAGE, _END_HIMMSGPAGE=LIMIT)
    memory = dict.fromkeys(range(BEGIN, 0xED8E), 0xEA)
    memory.update(dict.fromkeys(range(PAGE, LIMIT), 0xC1))
    info = layout(symbols, memory)
    assert (info['used_bytes'], info['padding_bytes'], info['core_headroom']) == (11918, 370, 370)
    dense = memory | dict.fromkeys(range(0xED8E, PAGE), 0xFF)
    assert layout(symbols, dense, require_dense=True) == info
    serialized = dense_srecord(memory, [record('9', 0)])
    lines = serialized.splitlines()
    assert len(lines) == 385 and lines[-1] == record('9', BEGIN)
    parsed = {}
    for line in lines[:-1]:
        raw = bytes.fromhex(line[2:])
        assert line.startswith('S1') and len(raw) == raw[0]+1 and sum(raw) & 255 == 255
        address = int.from_bytes(raw[1:3], 'big')
        parsed.update((address+i, value) for i, value in enumerate(raw[3:-1]))
    assert parsed == dense
    assert dense_srecord(parsed, lines) == serialized
    check_start(lines, finalized=True)

    failures = 0

    def rejects(sym, mem, **kwargs):
        nonlocal failures
        try:
            layout(sym, mem, **kwargs)
        except ValueError:
            failures += 1
        else:
            raise AssertionError('Invalid image accepted')

    rejects(symbols, memory, require_dense=True)
    rejects(symbols | {'START': BEGIN+1}, dense)
    rejects(symbols, {a: value for a, value in memory.items() if a != BEGIN})
    rejects(symbols, {a: value for a, value in memory.items() if a != PAGE})
    rejects(symbols, dense | {0xED8E: 0})
    rejects(symbols, dense | {LIMIT: 0xFF})
    rejects(symbols | {'_END_DATA': PAGE+1, 'HIM_CORE_END': PAGE+1}, dense)
    rejects(symbols | {'HIM_CORE_END': 0xED8F}, dense)
    rejects(symbols | {'_BEG_DATA': 0xE001}, dense)
    rejects(symbols | {'HIM_MESSAGE_PAGE': PAGE+1}, dense)
    rejects(symbols | {'HIM_MESSAGE_PAGE_END': LIMIT+1, '_END_HIMMSGPAGE': LIMIT+1}, dense)
    rejects({name: value for name, value in symbols.items() if name != 'HIM_CORE_END'}, dense)
    # A partially used page has separate page-tail room, not more core room.
    partial_symbols = symbols | {'HIM_MESSAGE_PAGE_END': 0xEFF0, '_END_HIMMSGPAGE': 0xEFF0}
    partial = dense | dict.fromkeys(range(0xEFF0, LIMIT), 0xFF)
    result = layout(partial_symbols, partial, require_dense=True)
    assert (result['core_headroom'], result['message_headroom'], result['padding_bytes']) == (370, 16, 386)
    entry_failures = 0
    for start_lines, finalized in [([], False), ([record('9', 0)]*2, False),
                                   ([record('9', 0x1234)], False),
                                   ([record('9', 0)], True),
                                   (['S903C00000'], False),
                                   ([record('9', BEGIN, b'\x00')], False)]:
        try:
            check_start(start_lines, finalized=finalized)
        except ValueError:
            entry_failures += 1
        else:
            raise AssertionError('Invalid S9 start accepted')
    print(f'HIMON layout tests = PASS; dense serialization, split padding, '
          f'{failures} rejected invalid layouts, {entry_failures} rejected invalid starts')


if __name__ == '__main__':
    main()
