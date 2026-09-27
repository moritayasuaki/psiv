"""Archive the active source layout without caches, native artifacts or older ZIPs."""
import hashlib
import json
import os
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / 'docs/verification'
MANIFEST = REPORTS / 'manifest.json'
CHECKSUMS = REPORTS / 'SHA256SUMS'
EXCLUDED = {'.lake', '.git', 'build', 'target', 'node_modules', '.venv', '__pycache__', 'dist', 'releases'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_files():
    for directory, directories, names in os.walk(ROOT):
        directories[:] = sorted(d for d in directories if d not in EXCLUDED and not (Path(directory) / d).is_symlink())
        for name in sorted(names):
            path = Path(directory) / name
            if path.is_symlink() or path in {MANIFEST, CHECKSUMS} or path.suffix == '.pyc':
                continue
            yield path
    # The release index is useful in a source-only extraction; nested releases are not included.
    if (ROOT / 'releases/README.md').is_file():
        yield ROOT / 'releases/README.md'


version = re.search(r'^version = "([^"]+)"$', (ROOT / 'rust/psiv/Cargo.toml').read_text(), re.MULTILINE).group(1)
files = sorted(source_files())
REPORTS.mkdir(parents=True, exist_ok=True)
manifest = {
    'version': version,
    'layout': 'lean-rust-source',
    'lean': '4.32.1',
    'complete_pre_cleanup_archive': 'psiv-lean-rust-v0.5.0-experimental.zip',
    'complete_pre_cleanup_sha256': '751038a0a0fba200733523215ade2a4298844b49d1cb5e78f9a1d0a889e86592',
    'security_claim': 'Experimental; no whole Rust/Lean equivalence, compiled constant-time or production-security claim',
    'sha256': {p.relative_to(ROOT).as_posix(): digest(p) for p in files},
}
MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
files.append(MANIFEST)
CHECKSUMS.write_text(''.join(f'{digest(p)}  {p.relative_to(ROOT).as_posix()}\n' for p in sorted(files)))
files.append(CHECKSUMS)
releases = ROOT / 'releases'
releases.mkdir(exist_ok=True)
archive = releases / f'psiv-source-v{version}.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9, strict_timestamps=False) as z:
    for path in sorted(files):
        z.write(path, 'psiv/' + path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files)
    for path in files:
        assert z.read('psiv/' + path.relative_to(ROOT).as_posix()) == path.read_bytes()
sha = digest(archive)
archive.with_suffix('.sha256').write_text(f'{sha}  {archive.name}\n')
print(json.dumps({'archive': str(archive), 'files': len(files), 'bytes': archive.stat().st_size, 'sha256': sha}, indent=2))
