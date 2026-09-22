"""Offline release-policy regression; never connects to a publishing server."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    files = ["publish_hot_update.sh", "publish_update_baseline.sh", "lib_update_release.sh",
             "publish_android_hot_update.sh", "build_android_release.sh", "build_packages.sh"]
    for name in files:
        subprocess.run(["bash", "-n", str(ROOT / "tools" / name)], check=True)
    updater = (ROOT / "scripts/android_updater.gd").read_text(encoding="utf-8")
    env = (ROOT / "tools/update_release.env").read_text(encoding="utf-8")
    assert 'const BOOTSTRAP_VERSION := 4' in updater
    assert '${UPDATE_BOOTSTRAP_VERSION:=4}' in env
    for name in ("publish_hot_update.sh", "publish_update_baseline.sh"):
        text = (ROOT / "tools" / name).read_text(encoding="utf-8")
        assert re.search(r'^PLATFORMS="android macos"', text, re.M)
    baseline = (ROOT / "tools/publish_update_baseline.sh").read_text(encoding="utf-8")
    assert 'min_bootstrap=1' not in baseline and 'ANDROID_PATCH' not in baseline
    assert 'patch_json="null"' in baseline and 'patch_base_version="$VERSION"' in baseline
    # Full releases still require all three complete GitHub artifacts; this
    # read-only gate must not be confused with the two publishing targets.
    assert 'for platform in android windows macos; do' in baseline
    # Intercept SSH completely and assert the exact selected promotion targets.
    result = subprocess.run(["bash", "-c", '''
source tools/lib_update_release.sh
SSH_KEY=not-a-key
REMOTE=not-a-host
UPDATE_REMOTE_WEB_ROOT=/not-a-server
ssh() { printf '%s\\n' "$@"; }
update_promote_all_stable 9.9
'''], cwd=ROOT, capture_output=True, text=True, check=True)
    assert result.stdout.splitlines()[-2:] == ["android", "macos"]
    assert "windows" not in result.stdout
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    android = preset.split('name="Android"', 1)[1].split('[preset.3]', 1)[0]
    for pattern in ('qa/*', 'docs/*', 'tools/*', 'assets/campaign/source/*', 'assets/direction4/source/*'):
        assert pattern in android
    print("[update-release-policy] PASS shell syntax, Windows exclusion, bootstrap 4, full Android baseline, APK filters")


if __name__ == "__main__":
    main()
