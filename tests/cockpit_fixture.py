"""Write-only DCS fixture without running the startup test on import."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(source)}
exec(compile(source.read_text(encoding='utf-8').split('\nfor page in ', 1)[0],
             str(source), 'exec'), scope)
runtime = scope['runtime']
