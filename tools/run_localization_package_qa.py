"""Export the Windows PCK, inspect its translations/font, and boot its real menu.

This uses Godot with the packed project; it does not publish or claim standalone
Steam client acceptance. Every subprocess uses private application data.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--out', type=Path, default=ROOT/'scratchpad/localization/package')
    parser.add_argument('--pack', type=Path, default=ROOT/'build/localization/localized.pck')
    args = parser.parse_args()
    out, pack = args.out.resolve(), args.pack.resolve()
    out.mkdir(parents=True, exist_ok=True)
    pack.parent.mkdir(parents=True, exist_ok=True)
    runs = []
    catalog_sha = hashlib.sha256((ROOT/'assets/localization/catalog.json').read_bytes()).hexdigest()

    def run(name, command, locale='en'):
        folder = out/name
        folder.mkdir(exist_ok=True)
        env = os.environ.copy()
        for key in ('LEVEL', 'SMOKE_TEST', 'AUTOMICRO', 'SKIRMISH', 'SKIRMISH_AI', 'ARENA', 'SCENARIO', 'SCREENSHOT_DIR'):
            env.pop(key, None)
        env.update(APPDATA=str(folder/'profile/Roaming'), LOCALAPPDATA=str(folder/'profile/Local'),
                   XDG_DATA_HOME=str(folder/'profile/data'), XDG_CONFIG_HOME=str(folder/'profile/config'),
                   LSH_LANGUAGE=locale, LSH_QA_CATALOG_SHA=catalog_sha, LSH_QA_REPORT=str(folder/'report.json'))
        with (folder/'godot.log').open('w', encoding='utf-8') as log:
            result = subprocess.run([str(args.godot), *command], cwd=out, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=240,
                                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        errors = [line for line in (folder/'godot.log').read_text(encoding='utf-8').splitlines() if 'ERROR:' in line]
        receipt = dict(name=name, exit=result.returncode, errors=errors)
        runs.append(receipt)
        print(json.dumps(receipt, ensure_ascii=False), flush=True)
        if result.returncode or errors:
            raise RuntimeError(name + ' failed; see retained log')

    run('export', ['--headless', '--path', str(ROOT), '--export-pack', 'Windows Desktop', str(pack)])
    for locale in ('zh_CN', 'zh_TW', 'en', 'ja'):
        run('probe_'+locale, ['--headless', '--main-pack', str(pack), '--script', str(ROOT/'tools/localization_package_probe.gd')], locale)
        run('menu_'+locale, ['--headless', '--main-pack', str(pack), '--quit-after', '60'], locale)
    receipt = {'pack': str(pack), 'bytes': pack.stat().st_size,
               'sha256': hashlib.sha256(pack.read_bytes()).hexdigest(), 'catalog_sha256': catalog_sha, 'runs': runs}
    (out/'summary.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
