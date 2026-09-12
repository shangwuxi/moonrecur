#!/usr/bin/env python3
"""Compare public MoonRecur APIs with python-dateutil, without vendoring its source.

800 reproducible cases: 640 RRULE cases (160/frequency), 160 recurrence sets.
A temporary MoonBit test package is generated, executed, and removed. Only the
optional JSON report persists. Fixture expectations never use MoonRecur itself.
"""
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import random
import re
import subprocess
import tempfile
import dateutil
from dateutil.rrule import rrulestr, rruleset

ROOT = pathlib.Path(__file__).resolve().parents[1]
SEED = 5545

def build_cases():
    rng = random.Random(SEED)
    cases = []
    starts = ['1999-12-31','2000-02-29','2023-01-31','2024-01-29','2024-02-29','2025-12-28','2099-12-31','2100-02-28']
    for freq in ['DAILY','WEEKLY','MONTHLY','YEARLY']:
        for i in range(160):
            start = dt.datetime.fromisoformat(starts[i % len(starts)])
            fields = ['FREQ='+freq, 'INTERVAL='+str(rng.choice([1,1,2,3,7]))]
            if i % 3 == 0:
                fields += ['COUNT='+str(rng.choice([1,2,5,20,100]))]
            elif i % 3 == 1:
                fields += ['UNTIL='+(start+dt.timedelta(days=rng.randint(0,1000))).date().isoformat()]
            if i % 4 in (1,3):
                fields += ['BYMONTH='+rng.choice(['2','1,6,12','2,3','4,7,11'])]
            if freq != 'DAILY' and i % 5 in (1,2):
                fields += ['BYDAY='+rng.choice(['MO','MO,WE,FR','SA,SU'])]
            if freq != 'WEEKLY' and i % 5 in (2,3,4):
                fields += ['BYMONTHDAY='+rng.choice(['-1','1,15','29,30,31','-2,-1,1'])]
            rule = ';'.join(fields)
            begin = start+dt.timedelta(days=rng.choice([0,0,10,90,400]))
            end = start+dt.timedelta(days=1460)
            limit = rng.choice([1,2,10,80])
            reference_rule = rule
            for field in fields:
                if field.startswith('UNTIL='):
                    reference_rule = rule.replace(field, field.replace('-',''))
            reference = rrulestr(reference_rule, dtstart=start, cache=False)
            expected = reference.between(begin, end, inc=True)[:limit]
            cases.append(dict(kind='rule',start=start.date().isoformat(),rule=rule,
                begin=begin.date().isoformat(),end=end.date().isoformat(),limit=limit,
                additions=[],exclusions=[],expected=[x.date().isoformat() for x in expected]))
    for i in range(160):
        start = dt.datetime(2024,1,1)
        rule = rng.choice(['FREQ=DAILY','FREQ=DAILY;COUNT=3','FREQ=WEEKLY;BYDAY=MO,WE;COUNT=40','FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=8'])
        begin = start+dt.timedelta(days=rng.choice([0,3,31]))
        end = start+dt.timedelta(days=240)
        additions = [start+dt.timedelta(days=rng.randint(-10,260)) for _ in range(12)]
        additions += additions[:3]
        exclusions = [start+dt.timedelta(days=n) for n in range(rng.randint(0,15))]
        exclusions += additions[3:7]
        limit = rng.choice([1,2,5,20])
        reference = rruleset(cache=False)
        reference.rrule(rrulestr(rule,dtstart=start))
        for value in additions: reference.rdate(value)
        for value in exclusions: reference.exdate(value)
        expected=reference.between(begin,end,inc=True)[:limit]
        cases.append(dict(kind='set',start=start.date().isoformat(),rule=rule,
            begin=begin.date().isoformat(),end=end.date().isoformat(),limit=limit,
            additions=[x.date().isoformat() for x in additions],exclusions=[x.date().isoformat() for x in exclusions],
            expected=[x.date().isoformat() for x in expected]))
    return cases

def quote(value): return json.dumps(value,ensure_ascii=True)
def date(value): return '@lib.Date::parse('+quote(value)+').unwrap()'
def source(case, index):
    args=[date(case['start']), '@lib.Rule::parse('+quote(case['rule'])+').unwrap()',
          '@lib.ExpansionWindow::make('+date(case['begin'])+','+date(case['end'])+','+str(case['limit'])+').unwrap()']
    if case['kind']=='set':
        args += ['['+','.join(date(x) for x in case[k])+']' for k in ['additions','exclusions']]
    call='@lib.expand'+('_set' if case['kind']=='set' else '')+'('+','.join(args)+').unwrap()'
    return '///|\ntest "dateutil case '+str(index)+'" {\n  let actual = '+call+'\n  assert_eq(@lib.dates_to_lines(actual), '+quote('\n'.join(case['expected']))+')\n}\n'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--target',choices=['wasm-gc','wasm','js','native'],default='wasm-gc')
    parser.add_argument('--report',type=pathlib.Path)
    parser.add_argument('--project-root',type=pathlib.Path,default=ROOT)
    args=parser.parse_args()
    if dateutil.__version__ != '2.9.0.post0': raise SystemExit('Install scripts/requirements-test.txt for the pinned oracle version')
    root=args.project_root.resolve()
    cases=build_cases()
    digest=hashlib.sha256(json.dumps(cases,sort_keys=True).encode()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='oracle_run_',dir=str(root)) as folder:
        package=pathlib.Path(folder).resolve()
        assert package.parent == root and package.name.startswith('oracle_run_')
        (package/'moon.pkg').write_text('import { "shangwuxi/moonrecur" @lib, } for "test"\n',encoding='utf-8')
        (package/'oracle_test.mbt').write_text('\n'.join(source(c,i) for i,c in enumerate(cases)),encoding='utf-8')
        run=subprocess.run(['moon','test',str(package),'--target',args.target,'--deny-warn'],cwd=str(root),capture_output=True,encoding='utf-8',timeout=300)
        print(run.stdout,end=''); print(run.stderr,end='')
        match=re.search(r"Total tests: (\d+), passed: (\d+), failed: (\d+)\.",run.stdout+run.stderr)
        executed,passed,failed = map(int,match.groups()) if match else (0,0,0)
        success=run.returncode==0 and executed==len(cases) and passed==len(cases)
        report=dict(oracle='python-dateutil '+dateutil.__version__,target=args.target,seed=SEED,
            rule_cases=640,set_cases=160,total_cases=len(cases),fixture_sha256=digest,executed=executed,passed_cases=passed,failed_cases=failed,passed=success)
        if args.report:
            args.report.parent.mkdir(parents=True,exist_ok=True)
            args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report))
        return 0 if success else (run.returncode or 1)
if __name__=='__main__': raise SystemExit(main())
