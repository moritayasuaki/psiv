"""Fresh Lean/Rust observations; finite comparisons are not a refinement proof."""
import hashlib,json,pathlib,subprocess,time
root=pathlib.Path(__file__).resolve().parents[1];start=time.monotonic()
(root/'.local/reports').mkdir(parents=True,exist_ok=True)
vectors=json.loads((root/'tests/vectors-extended.json').read_text());requests=[];expected=[]
for v in vectors:
 k,n,a,m,r=[bytes.fromhex(v[f]) for f in ['key','nonce','ad','plaintext','record']]
 for op,nonce,data,want in [('seal',n,m,r),('open',n,r,m),('open',n,r[:-1]+bytes([r[-1]^1]),None),('open',bytes([n[0]^1])+n[1:],r,None)]:
  requests.append('\t'.join([op,k.hex(),nonce.hex(),a.hex(),data.hex()]));expected.append(want)
text='\n'.join(requests)+'\n';commands={'lean':[str(root/'.lake/build/bin/psiv_vectors')],'rust':[str(root/'.local/rust/release/examples/vectors')]}
outputs={}
for name,cmd in commands.items():
 p=subprocess.run(cmd,input=text,text=True,capture_output=True,check=True,timeout=120)
 lines=p.stdout.splitlines();assert len(lines)==len(expected),(name,len(lines))
 for i,(line,want) in enumerate(zip(lines,expected)):
  assert (line.startswith('ERR:') if want is None else line=='OK:'+want.hex()),(name,i,line[:60])
 outputs[name]=hashlib.sha256(p.stdout.encode()).hexdigest()
report={'status':'PASS','record_cases':len(vectors),'observations_per_backend':len(expected),'backends':['Lean executable model','safe Rust reusable core'],'output_sha256':outputs,'seconds':round(time.monotonic()-start,3),'formal_rust_refinement':False,'commands':commands}
(root/'.local/reports/rust-lean-comparison.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
