from pathlib import Path
import sys, time
sys.path.insert(0, str(Path('LOCAL/himon-ap-init-size-20260916').resolve()))
import console
console.LOG=Path('LOCAL/ap-fnv-followup-20260916/serial-com4.jsonl')
with console.Board() as b:
    for bank in (0,1,2):
        print('LED observation: Bank',bank,flush=True)
        for repeat in range(3):
            b.command(f'APS B{bank}',seconds=30)
            time.sleep(1)
        time.sleep(3)
