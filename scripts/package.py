#!/usr/bin/env python3
"""Validate, build and test a reproducible developer-plugin ZIP. No dependencies."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
FILES = [
    'plugin.json', 'main.lua', 'bosses.lua', 'pool.lua', 'preferences.lua',
    'reel.lua', 'controller.lua', 'views.lua', 'README.md',
    'docs/api-notes.md', 'docs/verification.md',
    'tests/run.lua', 'tests/host.lua', 'tests/native.lua', 'scripts/package.py',
]


def run_suite(cwd):
    result = subprocess.run(['lua', 'tests/run.lua'], cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    print(f'{cwd}: {result.stdout.strip().splitlines()[-1]}', flush=True)


def main():
    for command in ('lua', 'luac'):
        if not shutil.which(command):
            raise SystemExit(f'{command} is required on PATH.')
    manifest = json.loads((ROOT / 'plugin.json').read_text())
    expected_fields = {'name', 'version', 'contactEmailAddress', 'hasSettingsIcon',
                       'hasRibbonIcon', 'requiredPermissions', 'optionalPermissions',
                       'requiredDependencies', 'optionalDependencies'}
    assert set(manifest) == expected_fields
    assert manifest['name'] == 'Reaper Roulette' and manifest['version'] == '0.1.0'
    assert manifest['hasSettingsIcon'] is True and manifest['hasRibbonIcon'] is True
    assert manifest['requiredPermissions'] == [] and manifest['optionalPermissions'] == []
    assert '@' in manifest['contactEmailAddress']
    for filename in FILES:
        path = ROOT / filename
        assert path.is_file() and not path.is_symlink(), filename
        if path.suffix == '.lua':
            subprocess.run(['luac', '-p', str(path)], check=True)
    print('Manifest and Lua syntax checks passed.', flush=True)
    run_suite(ROOT)
    destination = ROOT / f"Reaper_Roulette_v{manifest['version']}.zip"
    staging = destination.with_suffix('.zip.tmp')
    try:
        with zipfile.ZipFile(staging, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for filename in FILES:
                info = zipfile.ZipInfo(filename, date_time=(2026, 11, 10, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, (ROOT / filename).read_bytes())
        with zipfile.ZipFile(staging) as archive:
            assert archive.namelist() == FILES
            assert archive.testzip() is None
            assert json.loads(archive.read('plugin.json')) == manifest
            with tempfile.TemporaryDirectory(prefix='reaper-roulette-package-') as directory:
                archive.extractall(directory)
                run_suite(directory)
        staging.replace(destination)
    finally:
        if staging.exists():
            staging.unlink()
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix('.zip.sha256').write_text(f'{digest}  {destination.name}\n')
    print(f'Created {destination} ({destination.stat().st_size:,} bytes)')
    print(f'SHA-256: {digest}')


if __name__ == '__main__':
    main()
