"""Fail closed unless every project theorem has only the standard Lean axioms."""
import json,pathlib,re,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
(root/'build/reports').mkdir(parents=True,exist_ok=True)
names=[]
for file,namespace in [('PSIV/Properties.lean','PSIV'),('PSIV/Refinement.lean','PSIV.Refinement'),('PSIV/LimbAlgebra.lean','PSIV.LimbAlgebra'),('PSIV/ConstantTime.lean','PSIV.ConstantTime'),('PSIV/Library.lean','PSIV.Library')]:
    source=(root/file).read_text()
    assert not re.search(r'(?m)^\s*(?:axiom|unsafe)\b',source)
    names += [namespace+'.'+n for n in re.findall(r'(?m)^(?:@\[[^\]]*\]\s*)?theorem\s+(\w+)\s',source)]
audit='import PSIV.Properties\nimport PSIV.Refinement\nimport PSIV.LimbAlgebra\nimport PSIV.ConstantTime\nimport PSIV.Library\n'+''.join('#print axioms '+n+'\n' for n in names)
proc=subprocess.run(['lake','env','lean','--stdin'],input=audit,text=True,capture_output=True,cwd=root,check=True)
log=proc.stdout+proc.stderr
allowed={'propext','Classical.choice','Quot.sound'}
results={}
for n in names:
    m=re.search(re.escape("'"+n+"'")+r' (does not depend on any axioms|depends on axioms:\s*\[([^]]*)\])',log)
    assert m,(n,log)
    axioms=[] if m.group(2) is None else [s.strip() for s in m.group(2).split(',') if s.strip()]
    assert set(axioms)<=allowed,(n,axioms)
    results[n]=axioms
(root/'build/reports/axioms.log').write_text(log)
(root/'build/reports/axioms.json').write_text(json.dumps(results,indent=2)+'\n')
print(f'PASS: {len(results)} theorem axiom audits; no sorryAx or native-evaluation axioms.')
