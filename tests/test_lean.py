"""Run AFTER a successful Lean build. Fails (does not skip) if binary is missing."""
import json,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
exe=root/'.lake/build/bin/psiv_lean'
if not exe.is_file():
    raise SystemExit('FAIL: Lean executable unavailable; no Lean tests were run')
count=0
for v in json.loads((root/'tests/vectors.json').read_text()):
    for op,inp,expected in [('seal',v['plaintext'],v['record']),('open',v['record'],v['plaintext'])]:
        p=subprocess.run([str(exe),op,v['key'],v['nonce'],v['ad'],inp],capture_output=True,text=True,check=True,timeout=30)
        assert p.stdout.strip()==expected,(v['id'],op,p.stdout,expected)
        count+=1
print(f'PASS: {count} Lean/model fixture checks')
