"""Read-only source/build/install identity capture; never installs or operates DCS."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    if not path.is_file():
        return None
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--installed-root', type=Path)
    parser.add_argument('--hook-root', type=Path)
    args = parser.parse_args()
    for path in (args.build_dir, args.output):
        resolved = path.resolve()
        if resolved == ROOT or ROOT in resolved.parents:
            parser.error('Build and identity output must be outside the source checkout')
    names = command('git','ls-files','EFM','Cockpit','Input','Sounds','entry.lua',
                    'F-22A.lua','CMakeLists.txt','CMakePresets.json','Weapons.lua','Weapons').splitlines()
    sources = []
    for name in names:
        source = ROOT / name
        item = dict(path=name,sha256=digest(source))
        if args.installed_root:
            item['installed_sha256'] = digest(args.installed_root / name)
            item['matches_installed'] = item['sha256'] == item['installed_sha256']
        sources.append(item)
    artifacts = [dict(path=str(p.relative_to(args.build_dir)),sha256=digest(p))
                 for p in sorted((args.build_dir / 'artifacts').rglob('*')) if p.is_file()]
    hooks = []
    if args.hook_root:
        for path in sorted(args.hook_root.glob('F22*.lua')):
            candidates = [ROOT / 'tools' / path.name,ROOT / 'tools/diagnostics' / path.name]
            counterpart = next((p for p in candidates if p.is_file()), None)
            hooks.append(dict(path=str(path),sha256=digest(path),
                              counterpart=str(counterpart) if counterpart else None,
                              counterpart_sha256=digest(counterpart) if counterpart else None,
                              authority='passive recorder' if path.name == 'F22TrimTelemetry.lua'
                              else 'actuating diagnostic; filename gates can activate without control file',
                              loaded='unmeasured'))
    cache = args.build_dir / 'CMakeCache.txt'
    manifest = dict(captured_at=datetime.now(timezone.utc).isoformat(),
                    branch=command('git','branch','--show-current'),head=command('git','rev-parse','HEAD'),
                    status=command('git','status','--short'),profile='public_f22_manual_recovery@1',
                    cmake=command('cmake','--version').splitlines()[0],
                    build_cache=dict(path=str(cache),sha256=digest(cache)),
                    sources=sources,artifacts=artifacts,hooks=hooks,
                    source_bin_sha256=digest(ROOT / 'bin/F22.dll'),
                    installed_dll_sha256=digest(args.installed_root / 'bin/F22.dll')
                    if args.installed_root else None,
                    loaded_binary='unmeasured; file identity does not prove module loading',
                    runtime_qualification=False)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(source_files=len(sources),artifacts=len(artifacts),hooks=len(hooks),
                          manifest=str(args.output),runtime_qualification=False)))


if __name__ == '__main__':
    main()
