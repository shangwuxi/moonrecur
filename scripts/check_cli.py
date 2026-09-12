#!/usr/bin/env python3
"""Run real CLI processes, checking output and exit status (not just execute())."""
import argparse,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(); p.add_argument('--target',default='wasm-gc');args=p.parse_args()
    cases=[
        (['validate','--rule','FREQ=WEEKLY;COUNT=4;BYDAY=WE,MO'],0,(ROOT/'examples/weekly.expected.txt').read_text().strip()),
        (['expand','--start','2024-01-31','--rule','FREQ=MONTHLY;COUNT=3','--from','2024-01-01','--through','2024-06-30'],0,(ROOT/'examples/month-end.expected.txt').read_text().strip()),
        (['conflicts','--busy','release:2026-08-10..2026-08-12','--busy','review:2026-08-12..2026-08-13','--busy','travel:2026-08-20..2026-08-21'],0,(ROOT/'examples/conflicts.expected.txt').read_text().strip()),
        (['free','--from','2026-08-01','--through','2026-08-10','--busy','before:2026-07-20..2026-08-02','--busy','middle:2026-08-05..2026-08-06','--busy','after:2026-08-10..2026-08-20'],0,(ROOT/'examples/free.expected.txt').read_text().strip()),
        (['validate','--rule','FREQ=MONTHLY;BYMONTH=13'],2,(ROOT/'examples/invalid-month.expected.txt').read_text().strip()),
        (['nonsense'],2,None),
        (['nonsense','validate','--rule','FREQ=DAILY'],2,None),
        (['validate','--rule','FREQ=DAILY','--rule','FREQ=WEEKLY'],2,'duplicate option: --rule'),
        (['expand','--start','2026-01-01','--rule','FREQ=DAILY','--from','2026-01-01','--through','2026-01-10','--limit','4294967297'],2,'--limit exceeds integer range'),
        (['expand','--start','2026-01-01','--rule','FREQ=DAILY;COUNT=5','--from','2026-01-01','--through','2026-01-10','--limit','2','--exdate','2026-01-01','--exdate','2026-01-02'],0,'occurrences: 2\n2026-01-03\n2026-01-04'),
    ]
    for i,(argv,status,expected) in enumerate(cases):
        r=subprocess.run(['moon','run','cmd/moonrecur','--target',args.target,'--']+argv,cwd=str(ROOT),capture_output=True,encoding='utf-8',timeout=120)
        if r.returncode!=status or (expected is not None and r.stdout.strip()!=expected):
            raise SystemExit('CLI case %d failed: status=%s stdout=%r stderr=%r'%(i,r.returncode,r.stdout,r.stderr))
        if expected is None and not r.stdout.startswith('unknown command: nonsense'):
            raise SystemExit('Unknown command was hidden: '+r.stdout)
    print('CLI acceptance: %d/%d passed (%s)'%(len(cases),len(cases),args.target))
if __name__=='__main__':main()
