from pathlib import Path
import sys, time
sys.path.insert(0, str(Path('LOCAL/himon-ap-init-size-20260916').resolve()))
import console
here = Path('LOCAL/ap-fnv-followup-20260916')
console.LOG = here/'serial-com4.jsonl'
with console.Board() as b:
    print('Receive-only COM4 reset capture ready.', flush=True)
    received = bytearray()
    deadline = time.monotonic()+600
    while time.monotonic()<deadline:
        received.extend(b.read(1))
        (here/'physical-reset.txt').write_bytes(received)
        if b'RST H' in received and received.endswith(b'\r\n>'):
            print(received.decode('ascii','replace'),flush=True)
            print('Physical reset received; COM4 closed for follow-up.',flush=True)
            break
    else:
        print('No physical reset captured; gate remains pending.',flush=True)
