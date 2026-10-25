"""Run every self-contained Python/Lua regression from a consistent checkout root."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
scripts = [ROOT / 'tests/validate_modified_lua.py']
scripts += sorted((ROOT / 'tests').glob('test_*.py'))
failed = []
for script in scripts:
    print(f'\n=== {script.relative_to(ROOT)} ===', flush=True)
    try:
        result = subprocess.run([sys.executable, str(script)], cwd=ROOT, timeout=300)
        if result.returncode:
            failed.append(script.name)
    except subprocess.TimeoutExpired:
        failed.append(script.name + ' (timeout)')
print(f'\n{len(scripts) - len(failed)}/{len(scripts)} checks passed', flush=True)
if failed:
    print('Failed: ' + ', '.join(failed), flush=True)
    sys.exit(1)
