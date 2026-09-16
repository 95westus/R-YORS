"""Require exact artifact and symbol identity against a frozen AP extraction baseline."""
import argparse
import json
from pathlib import Path
from report_himon_ap_baseline import sha, symbols, srecord

ARTIFACTS = [
    's19/himon-c000.s19', 's19/himon-c000.map',
    's19/himon-rom-c000.s19', 's19/himon-rom-c000.map',
    'bin/himon-rom-c000.bin',
    's19/asm-v1-flash-8000.s19', 's19/asm-v1-flash-8000.map',
    's19/apman-7000.s19', 's19/apman-7000.map', 'bin/apman-v1.ap',
    'bin/apman-v1-bank2-8000.bin', 's19/apman-v1-bank2-8000.s19',
    's19/ryors-v1.2-asm-bank3-8-b.s19',
    's19/ryors-v1.2-himon-bank3-c-e.s19',
    's19/ryors-v1.2-himon-asm-bank3-8-e.s19',
]


def compare(baseline, candidate):
    rows=[]
    for name in ARTIFACTS:
        old, new = baseline/name, candidate/name
        a,b = old.read_bytes(),new.read_bytes()
        if a!=b: raise ValueError(f'Extraction changed {name}; no timestamp exclusions permitted')
        row=dict(path=name,bytes=len(a),sha256=sha(a))
        if old.suffix=='.map':
            before,after=symbols(old),symbols(new)
            if not before or before!=after: raise ValueError(f'Symbol dictionary changed: {name}')
            row['identical_symbols']=len(before)
        elif old.suffix=='.s19':
            if srecord(old)!=srecord(new): raise ValueError(f'Emitted bytes changed: {name}')
        rows.append(row)
    return rows


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--candidate',type=Path,default=Path('SRC/BUILD'))
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    rows=compare(args.baseline,args.candidate)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(dict(result='PASS',baseline=str(args.baseline),
        candidate=str(args.candidate),exclusions=[],identical_artifacts=rows),indent=2)+'\n')
    print(f'PASS {len(rows)} exact S19/BIN/AP/map artifacts; all linked symbols identical')
