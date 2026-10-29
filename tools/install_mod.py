"""Plan/apply a complete matched local F-22 package; never operate the simulator.

Plan first, then pass the saved plan to --apply. Source/build/installed drift
invalidates the plan. Saved controls, hooks and existing recorded audio survive.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from native_identity import exported_identity
from package_identity import native_source_digest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIRECTORIES = (
    'Cockpit', 'Effects', 'Encyclopedia', 'FM', 'ImagesGUI', 'Input', 'Liveries',
    'Missions', 'Shapes', 'Sounds', 'Textures', 'Theme', 'UnitPayloads', 'Weapons',
)
RUNTIME_FILES = (
    'entry.lua', 'F-22A.lua', 'Weapons.lua', 'Views.lua', 'comm.lua', 'IRST Pod.lua',
    'IRST Sensor.lua', 'VLO Fuel Tank.lua', 'DCS F-22A Raptor Manual.pdf',
)
AUDIO_EXTENSIONS = {'.wav', '.ogg', '.mp3', '.flac'}


def digest(path):
    if not path.is_file():
        return None
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()


def runtime_names():
    raw = git('ls-files', '-z', '--cached', '--others', '--exclude-standard', '--',
              *RUNTIME_DIRECTORIES, *RUNTIME_FILES)
    names = sorted(set(name for name in raw.split('\0') if name))
    if not 1 <= len(names) <= 25000:
        raise ValueError('Runtime file inventory exceeds declared bounds')
    for name in names:
        path = ROOT / name
        if not path.resolve().is_relative_to(ROOT) or not path.is_file():
            raise ValueError('Missing or out-of-root runtime input: ' + name)
    return names


def build_identity(build):
    dll = build / 'artifacts/Release/f22.dll'
    identity = exported_identity(dll)
    if not identity:
        raise ValueError('Built DLL has no native source identity')
    fields = dict(item.split('=', 1) for item in identity['token'].split('|')[1:])
    if fields.get('source') != native_source_digest():
        raise ValueError('Built DLL does not match the complete current native source')
    if fields.get('cache') != digest(build / 'CMakeCache.txt'):
        raise ValueError('Built DLL configuration differs from the current build cache')
    return {'path': str(dll), 'sha256': digest(dll), 'identity': identity['token']}


def target_path(mod, name):
    target = mod / name
    if not target.resolve().is_relative_to(mod):
        raise ValueError('Installation path escapes the named mod: ' + name)
    return target


def plan(build, mod):
    assets = []
    for name in runtime_names():
        source, installed = digest(ROOT / name), digest(target_path(mod, name))
        preserve_audio = (name.startswith('Sounds/') and Path(name).suffix.lower() in AUDIO_EXTENSIONS
                          and installed is not None and source != installed)
        assets.append({'path': name, 'source_sha256': source, 'installed_before_sha256': installed,
                       'preserve_audio': preserve_audio, 'copy': source != installed and not preserve_audio})
    return {'schema': 1, 'source_root': str(ROOT), 'source_commit': git('rev-parse', 'HEAD'),
            'source_status': git('status', '--short'), 'build_directory': str(build),
            'installed_root': str(mod), 'native': build_identity(build),
            'source_bin_before_sha256': digest(ROOT / 'bin/F22.dll'),
            'installed_dll_before_sha256': digest(mod / 'bin/F22.dll'), 'assets': assets}


def simulator_absent():
    tasks = subprocess.check_output([
        'tasklist', '/FI', 'IMAGENAME eq DCS.exe', '/FO', 'CSV', '/NH']).decode(errors='replace')
    if '"dcs.exe"' in tasks.lower():
        raise RuntimeError('DCS is running; installation waits until it is closed')


def protected_files(mod):
    saved = mod.parents[2]
    if (saved / 'Mods/aircraft/F-22A').resolve() != mod:
        raise ValueError('Expected the explicitly named Saved Games F-22A installation')
    files = set()
    for folder in (saved / 'Config/Input/F-22A', saved / 'Scripts/Hooks'):
        if folder.is_dir():
            files.update(path for path in folder.rglob('*') if path.is_file())
    files.update(path for path in (mod / 'Sounds').rglob('*')
                 if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS)
    return {str(path): digest(path) for path in sorted(files)}


def unchanged_inputs(record, mod):
    if runtime_names() != [item['path'] for item in record['assets']]:
        raise ValueError('Runtime inventory changed after planning')
    for item in record['assets']:
        name = item['path']
        if digest(ROOT / name) != item['source_sha256']:
            raise ValueError('Source changed after planning: ' + name)
        if digest(target_path(mod, name)) != item['installed_before_sha256']:
            raise ValueError('Installed file changed after planning: ' + name)
    if digest(mod / 'bin/F22.dll') != record['installed_dll_before_sha256']:
        raise ValueError('Another DLL was installed after planning')
    if digest(ROOT / 'bin/F22.dll') != record['source_bin_before_sha256']:
        raise ValueError('Primary-bin DLL changed after planning')


def apply(record, output):
    mod = Path(record['installed_root']).resolve()
    build = Path(record['build_directory']).resolve()
    if record['schema'] != 1 or Path(record['source_root']).resolve() != ROOT:
        raise ValueError('Plan belongs to another source checkout/schema')
    simulator_absent()
    if build_identity(build) != record['native']:
        raise ValueError('Native build changed after planning')
    unchanged_inputs(record, mod)
    protected = protected_files(mod)
    simulator_absent()
    for item in record['assets']:
        if item['copy']:
            target = target_path(mod, item['path'])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / item['path'], target)
    for target in (mod / 'bin/F22.dll', ROOT / 'bin/F22.dll'):
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(record['native']['path'], target)
    mismatches = []
    for item in record['assets']:
        expected = item['installed_before_sha256'] if item['preserve_audio'] else item['source_sha256']
        if digest(target_path(mod, item['path'])) != expected:
            mismatches.append(item['path'])
    if mismatches or protected_files(mod) != protected:
        raise RuntimeError('Post-copy package/protected-file verification failed: ' + repr(mismatches))
    if digest(mod / 'bin/F22.dll') != record['native']['sha256']:
        raise RuntimeError('Installed DLL hash differs from the checked artifact')
    if digest(ROOT / 'bin/F22.dll') != record['native']['sha256']:
        raise RuntimeError('Primary-bin DLL hash differs from the checked artifact')
    result = dict(record, installed_utc=datetime.now(timezone.utc).isoformat(),
                  status='INSTALLED_HASH_VERIFIED_FLIGHT_PENDING',
                  copied_files=[item['path'] for item in record['assets'] if item['copy']],
                  preserved_audio_overrides=[item['path'] for item in record['assets'] if item['preserve_audio']],
                  protected_files=protected, remaining_package_mismatches=mismatches,
                  DCS_launched_or_controlled=False, backups_created=False)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path)
    parser.add_argument('--installed-root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--apply', type=Path, help='Apply this previously captured plan')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.is_relative_to(ROOT):
        parser.error('Plan/receipt output must be outside the source checkout')
    output.parent.mkdir(parents=True, exist_ok=True)
    if args.apply:
        result = apply(json.loads(args.apply.read_text(encoding='utf-8')), output)
    else:
        if not args.build_dir or not args.installed_root:
            parser.error('Planning requires --build-dir and --installed-root')
        build, mod = args.build_dir.resolve(), args.installed_root.resolve()
        if build.is_relative_to(ROOT) or mod == ROOT or not (mod / 'entry.lua').is_file():
            parser.error('Expected an external build and the existing normal mod')
        result = plan(build, mod)
        output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'assets': len(result['assets']), 'updates': sum(item['copy'] for item in result['assets']),
                      'native_sha256': result['native']['sha256'], 'status': result.get('status', 'PLANNED'),
                      'output': str(output)}))


if __name__ == '__main__':
    main()
