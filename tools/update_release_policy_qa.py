"""Offline release-policy regression; never connects to a publishing server."""
from pathlib import Path
import copy
import hashlib
import json
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "tools/lib_update_release.sh"


def check_release_guards():
    script = '''source "$1"
git() {
    case "$1" in
        diff)
            [[ "$*" == *"--no-renames"* && "$*" == *"--diff-filter=ACDMRTUXB"* ]] || return 9
            printf '%s\\n' "$QA_CHANGED_PATHS" ;;
        status) printf '%s' "$QA_DIRTY" ;;
        rev-parse)
            if [ "$2" = HEAD ]; then printf '%s\\n' "$QA_HEAD"; else printf '%s\\n' "$QA_TAG"; fi ;;
        *) return 9 ;;
    esac
}
if [ "$2" = hot ]; then update_require_hot_update_safe 9.9; else update_verify_release_checkout 9.9 original; fi
'''
    import os
    for paths, expected in (("scripts/levels/level1.gd", True), ("scripts/android_updater.gd", False),
                            ("project.godot", False), ("scripts/android_updater.gd\nscripts/renamed.gd", False),
                            ("android/plugin.so", False)):
        env = {**os.environ, "QA_CHANGED_PATHS": paths, "QA_DIRTY": "", "QA_HEAD": "original", "QA_TAG": "original"}
        result = subprocess.run(["bash", "-e", "-c", script, "guard-qa", str(LIBRARY), "hot"],
                                env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == expected, result.stdout + result.stderr
    for dirty, head, tag, expected in (("", "original", "original", True), (" M scripts/example.gd", "original", "original", False),
                                       ("", "changed", "changed", False), ("", "original", "wrong-tag", False)):
        env = {**os.environ, "QA_CHANGED_PATHS": "", "QA_DIRTY": dirty, "QA_HEAD": head, "QA_TAG": tag,
               "LIANGSHAN_SKIP_GIT_GUARD": "0"}
        result = subprocess.run(["bash", "-e", "-c", script, "guard-qa", str(LIBRARY), "checkout"],
                                env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == expected, result.stdout + result.stderr
    with tempfile.TemporaryDirectory(prefix="lsh-signed-input-") as temporary:
        artifact = Path(temporary) / "fixture.pck"
        manifest = Path(temporary) / "manifest.json"
        content = b"original signed input"
        artifact.write_bytes(content)
        manifest.write_text(json.dumps({"patch": {"size": len(content), "sha256": hashlib.sha256(content).hexdigest()}}), encoding="utf-8")
        for value, expected in ((content, True), (b"X" * len(content), False), (b"short", False)):
            artifact.write_bytes(value)
            result = subprocess.run(["bash", "-e", "-c", 'source "$1"; update_verify_manifest_artifact "$2" patch "$3"',
                                     "input-qa", str(LIBRARY), str(manifest), str(artifact)], capture_output=True, text=True)
            assert (result.returncode == 0) == expected, result.stdout + result.stderr


def check_build_proofs():
    """Exercise the production verifier with throwaway files and a fake Git ID."""
    with tempfile.TemporaryDirectory(prefix="lsh-release-proof-") as temporary:
        root = Path(temporary)
        proof = {"schema": 1, "version": "9.9", "git_commit": "a" * 40, "platforms": {}}
        for platform, extension in {"android": "apk", "windows": "exe", "macos": "dmg"}.items():
            entries = {}
            for kind, relative in (("package", f"build/LiangshanHeroes-v9.9.{extension}"),
                                   ("base", f"build/updates/{platform}/base-9.9.pck")):
                data = f"private fixture: {platform} {kind}".encode()
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
                entries[kind] = {"path": relative, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            proof["platforms"][platform] = entries

        def verify(value, expected, required="android"):
            path = root / "proof.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            script = '''source "$1"
git() { [ "$*" = "rev-parse HEAD" ] && printf '%s\\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; }
update_verify_build_source "$2" "$3" 9.9 "$4"
'''
            result = subprocess.run(["bash", "-c", script, "proof-qa", str(LIBRARY), str(path), str(root), required],
                                    capture_output=True, text=True, timeout=10)
            assert (result.returncode == 0) == expected, result.stdout + result.stderr

        verify(proof, True)  # Explicit legacy three-platform proof verifies all six artifacts.
        android = copy.deepcopy(proof)
        android["platforms"] = {"android": android["platforms"]["android"]}
        for platform in ("windows", "macos"):
            for item in proof["platforms"][platform].values():
                (root / item["path"]).unlink()
        verify(android, True)  # No desktop outputs are needed for an Android-only build.
        verify(proof, False)  # Declared desktop outputs may not be silently skipped.
        for declared in ({}, [], None, {"ios": {}}, {"windows": {}}):
            invalid = copy.deepcopy(android)
            invalid["platforms"] = declared
            verify(invalid, False)
        for key, value in (("version", "9.8"), ("git_commit", "b" * 40), ("schema", 2)):
            invalid = copy.deepcopy(android)
            invalid[key] = value
            verify(invalid, False)
        invalid = copy.deepcopy(android)
        invalid["platforms"]["android"]["package"]["path"] = "build/LiangshanHeroes-v9.9.exe"
        verify(invalid, False)
        invalid = copy.deepcopy(android)
        invalid["platforms"]["android"]["base"]["sha256"] = "0" * 64
        verify(invalid, False)
        artifact = root / android["platforms"]["android"]["package"]["path"]
        artifact.write_bytes(b"X" * artifact.stat().st_size)
        verify(android, False)


def check_promotion():
    """Capture SSH's program, then exercise it only against local fixture trees."""
    command = '''source tools/lib_update_release.sh
SSH_KEY=not-a-key
REMOTE=not-a-host
UPDATE_REMOTE_WEB_ROOT=/not-a-server
ssh() { printf '%s\\n' "$@" >&2; cat; }
update_promote_all_stable 9.9
'''
    result = subprocess.run(["bash", "-c", command], cwd=ROOT, capture_output=True, text=True, check=True)
    assert result.stderr.splitlines()[-1:] == ["android"]
    assert "windows" not in result.stderr and "macos" not in result.stderr
    for fail_replace in (False, True):
        with tempfile.TemporaryDirectory(prefix="lsh-release-promotion-") as temporary:
            root = Path(temporary)
            for platform in ("android", "windows", "macos"):
                for directory in ("stable", "releases"):
                    (root / platform / directory).mkdir(parents=True)
                for suffix in ("json", "sig"):
                    (root / platform / "stable" / f"manifest.{suffix}").write_bytes(f"old {platform} {suffix}".encode())
                    (root / platform / "releases" / f"manifest-9.9.{suffix}").write_bytes(f"new {platform} {suffix}".encode())
            before = {str(path.relative_to(root)): path.read_bytes() for path in root.rglob("*") if path.is_file()}
            # The production script must reject alternate targets before touching any path.
            rejected = subprocess.run(["python3", "-", temporary, "9.9", "macos"], input=result.stdout,
                                      capture_output=True, text=True, timeout=10)
            assert rejected.returncode != 0
            injection = '''import os
original_replace = os.replace
def fail_once(source, target):
    if str(source).endswith(".manifest.json.next-9.9"):
        raise OSError("fixture promotion failure")
    return original_replace(source, target)
os.replace = fail_once
''' if fail_replace else ""
            promoted = subprocess.run(["python3", "-", temporary, "9.9", "android"], input=injection + result.stdout,
                                      capture_output=True, text=True, timeout=10)
            assert (promoted.returncode == 0) != fail_replace, promoted.stderr
            after = {str(path.relative_to(root)): path.read_bytes() for path in root.rglob("*") if path.is_file()}
            expected = before.copy()
            if not fail_replace:
                for suffix in ("json", "sig"):
                    expected[f"android/stable/manifest.{suffix}"] = before[f"android/releases/manifest-9.9.{suffix}"]
            assert after == expected, "promotion or rollback changed a historical/unexpected file"


def check_hot_delta():
    """Exercise only the builder's pure inventory check, without running Godot."""
    from build_android_hot_patch import check_delta

    def entry(path, digest="a" * 32, size=16):
        return {"path": path, "bytes": size, "md5": digest}

    protected = ("project.binary", "scripts/android_updater.gdc", "scripts/campaign.gdc")
    base = {"entries": [entry(path) for path in protected] + [
        entry("assets/fonts/OFL.txt"), entry("assets/fonts/NotoSansCJK-Regular.ttc"),
        entry("assets/localization/catalog.json")]}

    def verify(entries, changed=(), failure=None, baseline=None):
        inventory = {"entries": entries}
        baseline = base if baseline is None else baseline
        inputs = (inventory, baseline, list(changed))
        before = copy.deepcopy(inputs)
        try:
            check_delta(*inputs)
        except RuntimeError as error:
            assert failure is not None and failure in str(error), str(error)
        else:
            assert failure is None, "Unsafe delta accepted: " + repr(inputs)
        assert inputs == before, "Pure delta validation mutated its inputs"

    # A delta inherits complete-package resources from the fixed base. Neither
    # fonts/OFL nor project.binary/catalog is mandatory in an unrelated delta.
    verify([entry("scripts/hud.gdc")], ["scripts/hud.gd"])
    verify([entry("assets/localization/catalog.json")], ["assets/localization/catalog.json"])
    verify([entry(".godot/imported/icon.svg-fixture.ctex")], ["assets/icon.svg"])
    verify([entry(path) for path in protected])  # Byte-identical protected entries are safe.
    verify([], failure="Empty/duplicate")
    verify([entry("scripts/hud.gdc"), entry("scripts/hud.gdc", "b" * 32)], failure="Empty/duplicate")
    for path in ("tools/probe.gdc", "qa/result.json", "docs/readme.md", "build/fixture.pck",
                 "assets/campaign/source/background.png", "assets/poses/reference.png",
                 "assets/hero_raw.png", "override.cfg"):
        verify([entry(path)], failure="Development/native")
    for extension in (".so", ".dll", ".dylib", ".gdextension"):
        verify([entry("plugins/runtime" + extension)], failure="Development/native")
    for path in protected:
        verify([entry(path, "b" * 32)], failure="Protected exported resource changed")
        verify([entry(path, size=17)], failure="Protected exported resource changed")
        verify([entry(path)], baseline={"entries": []}, failure="Protected exported resource changed")
    for source in ("scripts/hud.gd", "scripts/static_scenery_draw_batch.gd", "assets/localization/catalog.json"):
        verify([entry("scenes/menu.tscn")], [source], failure="Changed production resource missing")


def check_hot_publication_policy(hot):
    """Keep both original-APK gates mandatory and ahead of their remote writes."""
    assert "set -euo pipefail" in hot
    assert 'git archive "$SOURCE_COMMIT"' not in hot and '--export-patch' not in hot
    assert 'WORK="$(mktemp -d "$WORK/run.XXXXXX")"' in hot
    assert 'patch="$WORK/$platform/$patch_name"' in hot
    builder_call = 'python3 -B "$ROOT/tools/build_android_hot_patch.py"'
    gate_call = 'python3 -B "$ROOT/tools/verify_android_hot_candidate.py"'
    commands = [line.strip() for line in hot.replace("\\\n", " ").splitlines()]
    builds = [line for line in commands if line.startswith(builder_call)]
    gates = [line for line in commands if line.startswith(gate_call)]
    assert len(builds) == 1 and len(gates) == 2
    for argument in ('--godot "$GODOT"', '--commit "$SOURCE_COMMIT"', '--version "$VERSION"',
                     '--base "$base"', '--manifest "$manifest"', '--out "$WORK/build-$platform"'):
        assert argument in builds[0]
    assert 'cp "$WORK/build-$platform/patch.pck" "$patch"' in hot
    assert '"$WORK/build-$platform/build-receipt.json"' in hot
    for guard in ('receipt.get("passed") is not True', 'receipt.get("source_commit") != source_commit',
                  'receipt.get("content_version") != version', 'receipt.get("baseline") != data["patch_base"]',
                  'receipt.get("patch", {}).get("size") != int(patch_size)',
                  'receipt.get("patch", {}).get("sha256") != patch_sha'):
        assert guard in hot
    assert hot.index('Copied patch does not match verified build receipt') < hot.index('update_sign_manifest ')
    for gate in gates:
        for argument in ('--godot "$GODOT"', '--apk "$BASE_APK"', '--manifest "$WORK/android/manifest.json"',
                         '--signature "$WORK/android/manifest.sig"',
                         '--patch "$WORK/android/patch-$UPDATE_BASE_VERSION-to-$VERSION.pck"',
                         '--source-root "$WORK/build-android/project"'):
            assert argument in gate
        assert "||" not in gate and "&&" not in gate and not gate.endswith("&")
    assert '--out "$WORK/offline-apk-gate"' in gates[0] and '--live-url' not in gates[0]
    assert '--out "$WORK/online-apk-gate"' in gates[1]
    assert '--live-url "$UPDATE_PUBLIC_ROOT/android/releases/manifest-$VERSION.json"' in gates[1]
    build = hot.index(builder_call)
    offline = hot.index(gate_call)
    online = hot.index(gate_call, offline + len(gate_call))
    assert build < hot.index('update_verify_release_checkout "$VERSION" "$SOURCE_COMMIT"', build) \
        < hot.index('update_sign_manifest ') < offline
    assert offline < hot.index('echo "== 服务器不可变路径预检') \
        < hot.index('"install -d -m 700 \'$REMOTE_TMP\'"') \
        < hot.index('scp -i "$SSH_KEY" "$patch" "$REMOTE:$REMOTE_TMP/$remote_patch"')
    assert hot.index('update_verify_manifest "$WORK/$platform/public-manifest.json"') < online \
        < hot.rindex('update_verify_release_checkout "$VERSION" "$SOURCE_COMMIT"') \
        < hot.index('update_promote_all_stable "$VERSION"')

    builder = (ROOT / "tools/build_android_hot_patch.py").read_text(encoding="utf-8")
    for guard in ('selected = allowlist(ROOT)', 'shutil.copy2(source, dest)',
                  'sha(dest) != before or sha(source) != before',
                  '[str(args.godot), "--headless", "--path", str(project), *extra]',
                  '"--export-patch", "Android"', '"--patches", str(args.base.resolve())',
                  'check_delta(inventory, base_inventory, [name for name in changed if name in selected])',
                  'selected != allowlist(ROOT)', 'git("rev-parse", "HEAD") != args.commit',
                  'any(sha(Path(path)) != digest for path, digest in identities.items())'):
        assert guard in builder


def main():
    files = ["publish_hot_update.sh", "publish_update_baseline.sh", "lib_update_release.sh",
             "publish_android_baseline.sh", "publish_android_hot_update.sh", "build_android_release.sh", "build_packages.sh"]
    for name in files:
        subprocess.run(["bash", "-n", str(ROOT / "tools" / name)], check=True)
    updater = (ROOT / "scripts/android_updater.gd").read_text(encoding="utf-8")
    env = (ROOT / "tools/update_release.env").read_text(encoding="utf-8")
    assert 'const BOOTSTRAP_VERSION := 4' in updater
    assert '${UPDATE_BOOTSTRAP_VERSION:=4}' in env
    for name in ("publish_hot_update.sh", "publish_update_baseline.sh"):
        text = (ROOT / "tools" / name).read_text(encoding="utf-8")
        assert re.search(r'^PLATFORMS="android"', text, re.M)
        assert 'update_verify_git_release_point "$VERSION"' in text
        assert 'update_version_gt "$VERSION" "$current"' in text
        assert 'test ! -e' in text
        assert 'update_verify_manifest ' in text and 'update_download_and_verify ' in text
        assert 'update_fetch_stable ' in text and 'cmp -s ' in text
        assert text.count('update_verify_release_checkout "$VERSION" "$SOURCE_COMMIT"') >= 2
        assert text.index('update_verify_release_checkout "$VERSION" "$SOURCE_COMMIT"') < text.index('echo "== 服务器不可变路径预检')
        assert text.rindex('update_verify_release_checkout "$VERSION" "$SOURCE_COMMIT"') < text.index('update_promote_all_stable "$VERSION"')
        assert 'update_verify_manifest_artifact ' in text
    baseline = (ROOT / "tools/publish_update_baseline.sh").read_text(encoding="utf-8")
    assert 'min_bootstrap=1' not in baseline and 'ANDROID_PATCH' not in baseline
    assert 'patch_json="null"' in baseline and 'patch_base_version="$VERSION"' in baseline
    assert 'update_verify_build_source "$UPDATE_OUT/build-source.json" "$ROOT" "$VERSION" android' in baseline
    assert 'ANDROID_APK_URL="$UPDATE_PUBLIC_ROOT/android/releases/$ANDROID_APK_NAME"' in baseline
    assert 'full_url="$ANDROID_APK_URL"' in baseline
    assert 'update_github_artifact_url' not in baseline and 'LIANGSHAN_VERIFY_FULL_DOWNLOAD' not in baseline
    assert 'update_require_executable "$GODOT"' not in baseline
    assert baseline.count('update_verify_build_source "$UPDATE_OUT/build-source.json" "$ROOT" "$VERSION" android') >= 3
    hot = (ROOT / "tools/publish_hot_update.sh").read_text(encoding="utf-8")
    check_hot_publication_policy(hot)
    check_hot_delta()
    for alias, target in (("publish_android_baseline.sh", "publish_update_baseline.sh"),
                          ("publish_android_hot_update.sh", "publish_hot_update.sh")):
        text = (ROOT / "tools" / alias).read_text(encoding="utf-8")
        assert f'exec "$ROOT/tools/{target}" "$@"' in text
        assert 'gh release' not in text and 'ssh ' not in text
    rejected = subprocess.run(["bash", "-c", 'source "$1"; LIANGSHAN_SKIP_GIT_GUARD=1 update_verify_git_release_point 9.9',
                               "guard-qa", str(LIBRARY)], capture_output=True, text=True)
    assert rejected.returncode != 0 and "不允许跳过" in rejected.stderr
    check_build_proofs()
    check_release_guards()
    check_promotion()
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    android = preset.split('name="Android"', 1)[1].split('[preset.3]', 1)[0]
    for pattern in ('qa/*', 'docs/*', 'tools/*', 'assets/campaign/source/*', 'assets/direction4/source/*'):
        assert pattern in android
    print("[update-release-policy] PASS Android-only targets, scoped build proofs, mandatory Git/tag/drift guards, protected deletions/renames, frozen allowlisted hot-update inputs, delta-only positive/negative inventory cases, mandatory offline/online original-APK gates, signed-input hashes, canonical APK URL, promotion rollback, desktop history untouched, shell syntax, bootstrap 4, APK filters")


if __name__ == "__main__":
    main()
