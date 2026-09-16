from pathlib import Path
import sys,json,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
import export_ram_transients as exporter
fake=HERE/'stale-export';assert not fake.exists()
(fake/'SRC/BUILD/tmp').mkdir(parents=True);(fake/'SRC/BUILD/s19').mkdir()
proof=json.loads((ROOT/'SRC/BUILD/tmp/fnv-ram-ap.json').read_text())
for name in ['s19/fnv-ram-ap-2000.s19',*proof['inputs']]:
 shutil.copy2(ROOT/'SRC/BUILD'/name,fake/'SRC/BUILD'/name)
proof['inputs']['s19/himon-rom-c000.s19']='0'*64
(fake/'SRC/BUILD/tmp/fnv-ram-ap.json').write_text(json.dumps(proof))
exporter.ROOT=fake
sys.argv=['export_ram_transients.py','--str8-home',str(ROOT.parent/'STR8-N'),'--output',str(fake/'out')]
try:exporter.main()
except AssertionError as error:
 assert 'stale private image pin' in str(error),str(error)
 for folder,ext in [('A','a'),('S19','s19'),('BIN','bin')]:
  assert not (fake/f'out/{folder}/fnv-ram-ap-2000.{ext}').exists()
 (HERE/'stale-export.json').write_text(json.dumps(dict(result='PASS',stale_pin_rejected=True,private_artifacts_not_written=True,error=str(error)),indent=2)+'\n')
 print('PASS stale image pin rejected before private artifacts were written')
else:raise AssertionError('Stale image pin accepted')
