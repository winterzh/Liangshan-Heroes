"""Read-only closed-A admission and exclusive raw fixture copy; no world decoding.

Called only after the host has validated the actual A process. This adds a
separate byte/inventory gate, not a replacement for native Slot._decode or the
future 52 negative stages. Its isolated Python model is explicitly synthetic.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat

SCHEMA = "daming_flow_closed_a_fixture_v1"
CONTEXT = {"mode": "campaign", "level_id": "level8", "waves": 0}
APP = "5088120"
RECORD = "record_0000000001.json"
ZERO = "0" * 64
ENVELOPE = {"magic", "version", "app", "owner", "revision", "previous_sha256",
            "payload_bytes", "payload_sha256", "payload"}
SLOT_KEYS = {"schema", "generation", "context", "binding", "resume_paused", "options",
             "session_settings", "root_node", "world"}
LIFE_KEYS = {"schema", "generation", "token", "context", "scope", "state", "victory",
             "progress_state", "intent", "progress_receipt"}


def require(ok, message):
    if not ok:
        raise RuntimeError("Closed A fixture: " + message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def number(value, expected):
    return type(value) in (int, float) and math.isfinite(value) and value == expected


def hex_text(value, size):
    return type(value) is str and re.fullmatch("[0-9a-f]{%d}" % size, value) is not None


def strict_json(raw):
    def pairs(rows):
        out = {}
        for key, value in rows:
            require(key not in out, "duplicate JSON key")
            out[key] = value
        return out

    def bad_constant(value):
        raise RuntimeError("Closed A fixture: non-finite JSON constant " + value)

    return json.loads(raw.decode("utf-8", errors="strict"), object_pairs_hook=pairs,
                      parse_constant=bad_constant)


def context(value):
    return (type(value) is dict and set(value) == set(CONTEXT)
            and value["mode"] == "campaign" and value["level_id"] == "level8"
            and number(value["waves"], 0))


def checked_path(value, parent, p):
    require(type(value) is str and value and "\x00" not in value, "missing path")
    path = Path(value)
    require(path.is_absolute() and ".." not in path.parts and not value.startswith("\\\\?\\"),
            "ordinary absolute path required")
    parent = Path(parent).absolute()
    require(path != parent and path.is_relative_to(parent), "path escaped its exact private root")
    p.h.identity.no_links(p.fs(path))
    return path


def read_bytes(path, p, maximum=67108864):
    p.h.identity.no_links(p.fs(path))
    info = p.fs(path).stat()
    require(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= maximum, "invalid file type or size")
    raw = p.fs(path).read_bytes()
    require(len(raw) == info.st_size, "file changed while reading")
    return raw


def inventory(root, p):
    """Include all empty directories; reject links/reparse points and odd files."""
    p.h.identity.no_links(p.fs(root))
    require(p.fs(root).is_dir(), "scope directory missing")
    files, directories = {}, []

    def visit(folder):
        with os.scandir(p.fs(folder)) as entries:
            rows = sorted(entries, key=lambda row: row.name)
        for row in rows:
            path = folder / row.name
            p.h.identity.no_links(p.fs(path))
            require(not row.is_symlink(), "linked entry")
            rel = path.relative_to(root).as_posix()
            if row.is_dir(follow_symlinks=False):
                directories.append(rel)
                visit(path)
            else:
                require(row.is_file(follow_symlinks=False), "nonregular inventory entry")
                raw = read_bytes(path, p)
                files[rel] = {"bytes": len(raw), "sha256": digest(raw)}
    visit(root)
    return {"files": dict(sorted(files.items())), "directories": sorted(directories)}


def closed_inventory(observed, token):
    slot_rel = f"{APP}/1/{RECORD}"
    life_rel = f"local_runs/{token}/{APP}/1/{RECORD}"
    dirs = {APP, f"{APP}/1", "local_runs", f"local_runs/{token}",
            f"local_runs/{token}/{APP}", f"local_runs/{token}/{APP}/1"}
    require(set(observed["files"]) == {slot_rel, life_rel}
            and set(observed["directories"]) == dirs and len(observed["directories"]) == 6,
            "expected exactly two genesis records and six directories; no writer/pending/extra owner")
    return slot_rel, life_rel


def envelope(raw, magic):
    value = strict_json(raw)
    require(type(value) is dict and set(value) == ENVELOPE
            and all(type(item) is str for item in value.values()), "strict envelope fields/types")
    require(value["magic"] == magic and value["version"] == "1" and value["app"] == APP
            and value["owner"] == "1" and value["revision"] == "1"
            and value["previous_sha256"] == ZERO, "genesis envelope identity")
    payload = value["payload"].encode("utf-8", errors="strict")
    require(value["payload_bytes"] == str(len(payload)) and value["payload_sha256"] == digest(payload),
            "actual payload bytes/hash")
    document = strict_json(payload)
    require(type(document) is dict, "payload object")
    return document


def verify_frozen(*, p, output, reference, pins):
    """Recheck only the frozen inventory; never reread an advancing live scope."""
    role = reference.get("first_role")
    require(role in ("lu", "shi"), "frozen reference role")
    path = checked_path(reference.get("path"), Path(output).absolute(), p)
    require(path == Path(output).absolute() / "closed_a" / role / "descriptor.json",
            "exact frozen descriptor path")
    raw = read_bytes(path, p)
    require(digest(raw) == reference.get("sha256") == pins.get(str(path)), "frozen descriptor pin")
    descriptor = strict_json(raw)
    scope = path.parent / "slot_scope"
    require(descriptor.get("schema") == SCHEMA and descriptor.get("complete") is True
            and descriptor.get("first_role") == role and descriptor.get("frozen_scope") == str(scope)
            and descriptor.get("binding", {}).get("token") == reference.get("token"), "frozen descriptor contract")
    observed = inventory(scope, p)
    closed_inventory(observed, reference["token"])
    require(observed == descriptor.get("frozen_inventory"), "frozen inventory changed after A closure")
    for rel, row in observed["files"].items():
        require(pins.get(str(scope / rel)) == row["sha256"], "frozen raw file pin")


def freeze(*, p, output, profile, role, report_path, log_path, step, expected, pins,
           evidence_kind="actual_host_validated_closed_a"):
    """Return an immutable descriptor reference; any exception prevents B launch.

    No source profile mutation, recovery, Codec conversion or overwrite occurs.
    Original raw files are rechecked after copying but are not added to global
    pins: later B/C are authorized to advance that live scope. Frozen copies and
    the original A report/log remain pinned through the host's final audit.
    """
    output, profile = Path(output).absolute(), Path(profile).absolute()
    require(evidence_kind in ("actual_host_validated_closed_a", "synthetic_filesystem_model"),
            "explicit evidence kind")
    require(role in ("lu", "shi") and not output.is_relative_to(profile)
            and not profile.is_relative_to(output), "distinct fixture and live-profile roots")
    report_path = checked_path(str(report_path), output, p)
    log_path = checked_path(str(log_path), output, p)
    require(report_path == output / role / "save_single/report.json"
            and log_path == report_path.parent / "save_single.log", "exact A stage paths")
    report_raw, log_raw = read_bytes(report_path, p), read_bytes(log_path, p)
    require(digest(report_raw) == pins.get(str(report_path))
            and digest(log_raw) == pins.get(str(log_path)), "pinned original A evidence")
    report = strict_json(report_raw)
    require(report.get("schema") == "campaign_daming_flow_v1" and report.get("mode") == "save_single"
            and report.get("first_role") == role and report.get("passed") is True
            and report.get("stage_completed") is True and report.get("failures") == []
            and type(report.get("checks")) is list and report["checks"]
            and all(type(row) is dict and row.get("passed") is True for row in report["checks"])
            and report.get("save_exit_observed") is True and report.get("exit_reason") == "continue_saved",
            "successful closed A production SaveAndExit report")
    for key in ("batch_nonce", "role_nonce", "process_nonce"):
        require(hex_text(expected.get(key), 32) and report.get(key) == expected[key], "exact " + key)
    require(len({expected[key] for key in ("batch_nonce", "role_nonce", "process_nonce")}) == 3,
            "three distinct nonces")
    identity = report.get("identity", {})
    require(identity.get("content_version") == expected["content_version"]
            and identity.get("engine_sha256") == expected["engine_sha256"]
            and identity.get("source_mode") is True
            and report.get("candidate_manifest_sha256") == expected["candidate_manifest_sha256"]
            and report.get("sources_sha256") == expected["sources_sha256"]
            and report.get("profile") == str(profile) and report.get("slot_root") == "user://continue/v1",
            "exact source/engine/manifest/profile binding")
    require(type(report.get("pid")) is int and report["pid"] > 0
            and type(step.get("pid")) is int and step["pid"] == report["pid"]
            and type(step.get("exit_code")) is int and step["exit_code"] == 0
            and step.get("passed") is True and step.get("errors") == []
            and step.get("stopped_for") is None and step.get("case") == "save_single"
            and step.get("first_role") == role and step.get("mode") == "save_single"
            and step.get("process_nonce") == expected["process_nonce"]
            and step.get("log_sha256") == digest(log_raw), "actual terminal A step and log")
    cp = report.get("checkpoint", {})
    binding, life = cp.get("binding", {}), cp.get("lifecycle", {})
    require(type(binding) is dict and set(binding) == {"kind", "token", "receipt_sha256"}
            and binding["kind"] == "uncredited" and hex_text(binding["token"], 32)
            and hex_text(binding["receipt_sha256"], 64), "strict local token binding")
    token = binding["token"]
    require(cp.get("slot_root") == "user://continue/v1" and number(cp.get("generation"), 1)
            and context(cp.get("context")) and life.get("token") == token
            and number(life.get("generation"), 1) and life.get("file_sha256") == binding["receipt_sha256"],
            "A slot/LC gen1 same token and actual Daming context")
    directory = checked_path(cp.get("directory"), profile / "appdata", p)
    require(directory.parts[-4:] == ("continue", "v1", APP, "1"), "fixed slot suffix")
    scope = directory.parents[1]
    life_directory = checked_path(life.get("directory"), scope, p)
    require(life_directory == scope / "local_runs" / token / APP / "1", "exact lifecycle path")
    before = inventory(scope, p)
    slot_rel, life_rel = closed_inventory(before, token)
    raws = {rel: read_bytes(scope / rel, p, 65536 if rel == life_rel else 67108864)
            for rel in (slot_rel, life_rel)}
    require(all(digest(raws[rel]) == before["files"][rel]["sha256"] for rel in raws),
            "inventory bytes agree with validated raw reads")
    require(digest(raws[slot_rel]) == cp.get("file_sha256")
            and digest(raws[life_rel]) == binding["receipt_sha256"], "report-to-original raw SHA binding")
    slot = envelope(raws[slot_rel], "LH_CLASSIC_CONTINUE_SLOT")
    lc = envelope(raws[life_rel], "LH_LOCAL_CONTINUE_LIFECYCLE")
    require(set(slot) == SLOT_KEYS and slot["schema"] == "official_continue_slot_v1"
            and number(slot["generation"], 1) and context(slot["context"])
            and slot["binding"] == binding and slot["resume_paused"] is True, "slot header contract")
    world = slot["world"]
    require(type(world) is dict and set(world) == {"schema", "profile", "content_version", "engine_sha256", "sections"}
            and world["schema"] == "official_world_core_preparation_v1"
            and world["content_version"] == expected["content_version"]
            and world["engine_sha256"] == expected["engine_sha256"]
            and type(world["profile"]) is dict and world["profile"].get("schema") == "official_restore_profile_v1"
            and world["profile"].get("id") == "campaign_level8_v1"
            and context(world["profile"].get("context")), "actual saved world source and Level8 profile header")
    require(set(lc) == LIFE_KEYS and lc["schema"] == "local_campaign_continue_lifecycle_v3"
            and number(lc["generation"], 1) and lc["token"] == token and context(lc["context"])
            and lc["scope"] == {"owner": "", "content_version": expected["content_version"],
                                  "engine_sha256": expected["engine_sha256"]}
            and lc["state"] == "active" and lc["victory"] is False and lc["progress_state"] == "none"
            and lc["intent"] == {} and lc["progress_receipt"] == {} and lc == life.get("document"),
            "actual LC3 genesis document agrees with closed A report")
    destination = output / "closed_a" / role
    p.h.identity.no_links(p.fs(destination))
    require(not p.fs(destination).exists(), "fixture output already exists")
    p.fs(destination).mkdir(parents=True, exist_ok=False)
    frozen_scope = destination / "slot_scope"
    for rel, raw in raws.items():
        target = frozen_scope / rel
        p.h.identity.no_links(p.fs(target))
        p.fs(target.parent).mkdir(parents=True, exist_ok=True)
        with p.fs(target).open("xb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    after, copied = inventory(scope, p), inventory(frozen_scope, p)
    require(after == before == copied, "original and frozen full inventory must remain byte-identical")
    require(read_bytes(report_path, p) == report_raw and read_bytes(log_path, p) == log_raw,
            "A report/log changed during freeze")
    descriptor = {"schema": SCHEMA, "complete": True, "first_role": role, "evidence_kind": evidence_kind,
        "binding": binding, "context": CONTEXT, "source_scope": str(scope), "profile": str(profile),
        "frozen_scope": str(frozen_scope), "slot_relative_path": slot_rel, "lifecycle_relative_path": life_rel,
        "expected": dict(expected), "actual_process_step": step, "actual_pid": report["pid"],
        "a_report": {"path": str(report_path), "bytes": len(report_raw), "sha256": digest(report_raw)},
        "a_log": {"path": str(log_path), "bytes": len(log_raw), "sha256": digest(log_raw)},
        "source_inventory_before": before, "source_inventory_after": after, "frozen_inventory": copied,
        "copies": [{"source": str(scope / rel), "destination": str(frozen_scope / rel),
                    "relative_path": rel, **before["files"][rel]} for rel in sorted(raws)],
        "original_profile_unchanged": True, "native_slot_decode_still_required": True,
        "world_or_codec_reconstructed": False, "full_61_qualified": False,
        "original_19_faults_qualified": False, "public_continue_qualified": False,
        "native_release_tested": False, "human_acceptance": False, "published": False}
    descriptor_path = destination / "descriptor.json"
    p.h.save(p.fs(descriptor_path), descriptor)
    for rel in raws:
        p.pin(frozen_scope / rel, pins, before["files"][rel]["sha256"])
    p.pin(descriptor_path, pins)
    return {"path": str(descriptor_path), "sha256": pins[str(descriptor_path)], "schema": SCHEMA,
            "first_role": role, "token": token, "slot_sha256": digest(raws[slot_rel]),
            "lifecycle_sha256": digest(raws[life_rel]), "file_count": 2, "directory_count": 6}
