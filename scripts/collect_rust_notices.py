"""Collect license files for resolved Cargo dependencies in binary distributions."""
import json,pathlib,shutil,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
meta=json.loads(subprocess.check_output(['cargo','metadata','--locked','--format-version','1'],cwd=root))
licenses=root/'bindings/wasm/licenses';licenses.mkdir(parents=True,exist_ok=True)
rows=[]
for pkg in meta['packages']:
 if pkg['source'] is None: continue
 source=pathlib.Path(pkg['manifest_path']).parent
 files=sorted(set(source.glob('LICENSE*'))|set(source.glob('COPYING*')))
 files=[p for p in files if p.is_file()]
 if not files: raise RuntimeError(f"No license file for {pkg['name']}")
 name=pkg['name']+'-'+pkg['version'];dst=licenses/name;dst.mkdir(exist_ok=True)
 for p in files: shutil.copy2(p,dst/p.name)
 rows.append({'name':pkg['name'],'version':pkg['version'],'license':pkg['license'],'files':[f'{name}/{p.name}' for p in files]})
(licenses/'dependencies.json').write_text(json.dumps(rows,indent=2)+'\n')
print(f'Collected license notices for {len(rows)} resolved registry packages (includes test/build dependencies).')
