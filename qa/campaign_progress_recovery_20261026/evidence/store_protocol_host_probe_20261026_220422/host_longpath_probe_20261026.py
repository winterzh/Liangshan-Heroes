"""Host-only probe of preserved dead fixture; never launches an engine."""
import ctypes
import importlib.util
import json
from pathlib import Path
import sys
import traceback
import uuid

sys.dont_write_bytecode = True
ROOT = Path(r"D:\AI项目\水浒\开发工程")
HERE = ROOT / "qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io"
spec = importlib.util.spec_from_file_location("longpath_host_probe", HERE / "run_io.py")
io = importlib.util.module_from_spec(spec)
spec.loader.exec_module(io)
stage = ROOT / ".godot/campaign_store_protocol_io_20261026/20261026_214029_e8825c44/cleanup_delete_retry"
prepared = io.helper.read(stage / "prepared.json")
profile = Path(prepared["profile"])
directory = io.owned(prepared["directory"], profile)
output = ROOT / ".godot/campaign_store_protocol_io_20261026" / ("host_probe_" + io.helper.stamp())
output.mkdir(exist_ok=False)
receipt = {"schema": "campaign_store_host_longpath_probe_v1", "complete": False,
           "source_failed_stage": str(stage), "source_profile": str(profile),
           "source_directory": str(directory), "source_pid": prepared["pid"],
           "engine_started": False, "production_or_worker_changed": False,
           "store_protocol_qualified": False, "checks": []}


def check(value, label):
    receipt["checks"].append({"passed": bool(value), "label": label})
    io.require(value, label)


before = None
try:
    api = ctypes.WinDLL("kernel32", use_last_error=True)
    api.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_bool, ctypes.c_ulong]
    api.OpenProcess.restype = ctypes.c_void_p
    api.CloseHandle.argtypes = [ctypes.c_void_p]
    api.CloseHandle.restype = ctypes.c_bool
    process = api.OpenProcess(0x1000, False, prepared["pid"])
    if process:
        api.CloseHandle(process)
    check(not process and ctypes.get_last_error() == 87, "original writer PID no longer exists; no live process is touched")
    before = io.snapshot(directory)
    receipt["source_before"] = before
    markers = [name for name in before["files"] if name.startswith("release_v1_")]
    check(len(markers) == 1, "one real original marker is enumerated")
    marker = io.owned(directory / markers[0], profile)
    receipt["marker"] = {"path": str(marker), "ordinary_path_characters": len(str(marker)),
                         "sha256": io.helper.sha(io.fs_path(marker)),
                         "bytes": io.fs_path(marker).stat().st_size,
                         "ordinary_is_file": marker.is_file()}
    check(len(str(marker)) > 260 and io.fs_path(marker).is_file(), "actual marker longer than 260 characters reads through extended path")
    check(io.helper.read(io.fs_path(marker))["pid"] == str(prepared["pid"]), "marker metadata retains original writer PID")
    check(io.plain_path(io.fs_path(marker)) == marker, "extended I/O path round-trips to ordinary metadata path")
    target = io.fault_target(directory, profile, "cleanup_delete_retry")
    receipt["cleanup_target"] = str(target)
    check(io.fs_path(target).is_dir() and not list(io.fs_path(target).iterdir()), "actual fault_target resolves the original empty cleanup")
    for name, target_path in (("cleanup", target), ("long_marker", marker)):
        handle = io.NativeSharingDenial(target_path, profile, "cleanup_delete_retry" if name == "cleanup" else "marker_delete_retry")
        try:
            check(handle.handle is not None, "read-only native deny-DELETE handle opens: " + name)
        finally:
            handle.close()
        check(io.snapshot(directory) == before, "native handle open/close leaves all original files unchanged: " + name)
    outside_rejected = False
    try:
        io.owned(output, profile)
    except RuntimeError:
        outside_rejected = True
    check(outside_rejected, "extended path helper still rejects paths outside the private profile")
    copy_profile = Path(r"D:\CodexQA\campsp_host_probe") / uuid.uuid4().hex
    io.helper.identity.no_links(io.fs_path(copy_profile))
    io.fs_path(copy_profile).mkdir(parents=True, exist_ok=False)
    destination = copy_profile / ("long_evidence_copy_" + "x" * 70) / "terminated_account_copy"
    receipt["copy_destination"] = str(destination)
    io.copy_account_tree(directory, destination)
    copied = io.snapshot(destination)
    receipt["copy_inventory"] = copied
    check(copied == before, "long-path copytree source and destination preserve every original byte and directory")
    check(len(str(destination / markers[0])) > 260, "copied marker also exceeds ordinary MAX_PATH")
    refused = False
    try:
        io.copy_account_tree(directory, destination)
    except RuntimeError:
        refused = True
    check(refused and io.snapshot(destination) == copied, "duplicate evidence-copy destination is rejected without overwrite")
    post = {"complete": True, "slice_passed": True, "error": "synthetic original failure", "traceback": "synthetic original traceback"}
    def failed_snapshot():
        raise OSError("synthetic post-inventory failure")
    okay, _ = io.post_step(post, "synthetic secondary failure", failed_snapshot)
    check(not okay and not post["complete"] and not post["slice_passed"] and post["error"] == "synthetic original failure"
          and post["traceback"] == "synthetic original traceback" and len(post["post_errors"]) == 1,
          "isolated host post-error collector preserves primary failure and clears pass flags")
    collision = output / "exclusive_existing.json"
    io.helper.save(collision, {"original": True})
    collision_sha = io.helper.sha(collision)
    io.persist_result(collision, post)
    check(io.helper.sha(collision) == collision_sha and io.fs_path(post["fallback_evidence_path"]).is_file(),
          "controller write collision preserves existing evidence and writes a unique fallback")
    receipt["synthetic_post_error_fixture"] = post
    receipt["complete"] = True
except BaseException as error:
    receipt["error"] = repr(error)
    receipt["traceback"] = traceback.format_exc()
finally:
    if before is not None:
        okay, after = io.post_step(receipt, "final unchanged source snapshot", lambda: io.snapshot(directory))
        if okay:
            receipt["source_after"] = after
            receipt["source_unchanged"] = after == before
            if after != before:
                receipt["complete"] = False
    receipt["tool_sha256"] = {name: io.helper.sha(HERE / name) for name in
                              ("run_io.py", "run_delayed_acquire.py", "README.md", "README_delayed.md")}
    receipt["probe_script_sha256"] = io.helper.sha(__file__)
    io.persist_result(output / "receipt.json", receipt)
print(json.dumps({"output": str(output), "complete": receipt["complete"], "checks": len(receipt["checks"]),
                  "error": receipt.get("error"), "source_unchanged": receipt.get("source_unchanged")}, ensure_ascii=False))
raise SystemExit(0 if receipt["complete"] else 1)
