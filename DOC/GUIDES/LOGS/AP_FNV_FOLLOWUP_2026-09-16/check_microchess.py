from pathlib import Path
import sys, json
sys.path.insert(0, str(Path('LOCAL/himon-ap-init-size-20260916').resolve()))
import console
here=Path('LOCAL/ap-fnv-followup-20260916')
console.LOG=here/'serial-com4.jsonl'
with console.Board() as b:
    b.command('')
    r=b.command('APS B1 MICROCHESS',seconds=30)
    assert b'9000 APC MICROCHESS L=06A6 @2000' in r
    r=b.command('MICROCHESS',until=r'\?',seconds=30)
    assert b'GO 2000' in r and b'MicroChess' in r
    b.send(b'C'); r=b.read(10,r'\?'); print(r.decode('ascii','replace'))
    assert b'|BR|BN|BB|BQ|BK|BB|BN|BR|' in r or b'BR' in r
    b.send(b'H'); r=b.read(10,r'\?'); print(r.decode('ascii','replace'))
    for line in (b'H Help C New E Reverse P Play 0-7 FROMTO Enter Move Q Quit', b'(c) 1976 Peter Jennings benlo.com', b'R-YORS port AI-assisted with OpenAI Codex; review and hardware-verify.'):
        assert line in r
    b.send(b'Q'); r=b.read(10,r'>$'); print(repr(r))
    r=b.command('APS B2 APMAN',seconds=30)
    assert b'8000 APC APMAN L=0C05 @7000' in r
(here/'microchess-checks.json').write_text(json.dumps({'checks':['receive-only RST H and HIMON recovery','post-reset B1:9000 MICROCHESS 06A6 discovery','bare MICROCHESS GO 2000','C initializes board','three exact H help lines','Q returns to HIMON','post-child APMAN B2:8000 0C05 discovery'], 'scope':'serial lifecycle; no flash writes; visual LEDs pending'},indent=2)+'\n')
