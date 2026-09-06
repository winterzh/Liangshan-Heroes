"""Bounded source/launch-gate checks only. Does not parse GDScript or start processes."""
import ast
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
results = []


def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.replace(b"\r\n", b"\n")
def check(ok, label):
    results.append({"check": label, "passed": bool(ok)})
    if not ok: raise AssertionError(label)


def namespace(path):
    space = {"__file__": str(path), "__name__": "static_check_import"}
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), space)
    return space


def draw_span(text, owner=None):
    offset = 0
    if owner:
        start = re.search(r"(?m)^class " + re.escape(owner) + r"\b", text)
        check(start is not None, "nested class exists " + owner)
        offset = start.start()
        segment = text[offset:]
        next_class = re.search(r"(?m)^class ", segment[1:])
        if next_class: segment = segment[:next_class.start()+1]
        marker = "\tfunc _draw() -> void:"
    else:
        segment = text
        marker = "func _draw() -> void:"
    hit = re.search(r"(?m)^" + re.escape(marker) + r"\n", segment)
    check(hit is not None, "draw method exists " + str(owner))
    a = offset + hit.start()
    indent = "\t" if owner else ""
    tail = text[offset+hit.end():]
    # The next sibling function/class ends this method. Blank lines and comments
    # are retained; deleting them identically cannot conceal an unrelated edit.
    nxt = re.search(r"(?m)^(?:" + indent + r"func |class |func )", tail)
    z = offset+hit.end()+nxt.start() if nxt else len(text)
    return a, z


def mask_draws(text, owners):
    spans = [(*draw_span(text, owner), owner) for owner in owners]
    for a,z,owner in sorted(spans, reverse=True):
        text = text[:a] + "# APPROVED_DRAW_BODY_" + str(owner) + "\n" + text[z:]
    return text


class FakePath:
    """Read-only in-memory path used to test preflight failures without live files."""
    def __init__(self, key, files): self.key, self.files = key, files
    def __truediv__(self, key): return FakePath((self.key + "/" + str(key)).strip("/"), self.files)
    def read_bytes(self): return self.files[self.key]
    def read_text(self, encoding="utf-8"): return self.read_bytes().decode(encoding)


def main():
    for path in sorted(HERE.glob("*.py")):
        ast.parse(path.read_text(encoding="utf-8"))
        check(True, "Python AST compiles " + path.name)
    prep = namespace(HERE / "prepare.py")
    pins = json.loads((HERE / "pins.json").read_text(encoding="utf-8"))
    receipt = json.loads((HERE / "preparation_receipt.json").read_text(encoding="utf-8"))
    base, candidate = {}, {}
    for name in pins["base_lf_sha256"]:
        stem = Path(name).stem
        raw = (HERE/"frozen"/(stem+".gd.bin")).read_bytes()
        out = (HERE/"candidate"/(stem+".gd.txt")).read_bytes()
        check(sha(raw) == pins["base_raw_sha256"][name], "exact raw frozen source " + name)
        check(sha(lf(raw)) == pins["base_lf_sha256"][name], "frozen LF source " + name)
        check(sha(out) == pins["candidate_lf_sha256"][name] and out == lf(out), "candidate LF source " + name)
        base[name], candidate[name] = lf(raw).decode(), out.decode()
    check(pins["base_lf_sha256"]["scripts/unit.gd"] == prep["UNIT_LF"], "Unit base is c8a692bf candidate")
    check(lf(prep["candidate_unit"]()).decode() == base["scripts/unit.gd"], "two-method frozen reconstruction matches base")
    patch = (HERE/"candidate.patch").read_text(encoding="utf-8")
    check(prep["apply_v1_memory"](base, patch, {"scripts/settings.gd":3,"scripts/settings_panel.gd":2,"scripts/battle.gd":6,"scripts/unit.gd":1}) == candidate, "unified patch reconstructs all four exact candidate texts")
    safe_target='\t\t\tvar target_value: Variant = hit.get("target")\n\t\t\tif not is_instance_valid(target_value):\n\t\t\t\tcontinue\n\t\t\tvar target: Unit = target_value'
    check(candidate["scripts/battle.gd"].count(safe_target)==2,"two explicit independently-tested freed-target guards")
    draw_candidate=candidate["scripts/battle.gd"].replace(safe_target,'\t\t\tvar target: Unit = hit.get("target")')
    check(mask_draws(base["scripts/battle.gd"], ["AmbientMotes","HitSpark","GroundFireFx","LiBrawnAxesFx"]) ==
          mask_draws(draw_candidate, ["AmbientMotes","HitSpark","GroundFireFx","LiBrawnAxesFx"]),
          "Battle outside four draw methods and two explicit lifetime guards is byte-identical after LF normalization")
    check(mask_draws(base["scripts/unit.gd"], [None]) == mask_draws(candidate["scripts/unit.gd"], [None]),
          "Unit outside draw method is byte-identical after LF normalization")
    for method, expected in pins["redraw_methods_preserved_sha256"].items():
        original = base["scripts/unit.gd"].encode(); changed = candidate["scripts/unit.gd"].encode()
        a,z = prep["method_span"](original,method); b,y = prep["method_span"](changed,method)
        check(original[a:z] == changed[b:y] and sha(changed[b:y]) == expected, "M2B method preserved " + method)
    for name in ("scripts/battle.gd","scripts/unit.gd","scripts/settings_panel.gd"):
        check("Settings.effects_quality" not in candidate[name], "no direct new Autoload property " + name)
    check(candidate["scripts/battle.gd"].count('Settings.get("effects_quality")') == 4 and
          candidate["scripts/unit.gd"].count('Settings.get("effects_quality")') == 1, "only five draw-only quality reads")
    check('if effects_value is String and effects_value in ["standard", "reduced"]:\n\t\t_row(p, "特效细节"' in candidate["scripts/settings_panel.gd"], "new preference row is under supported-field condition")
    check('Settings.set("effects_quality", String(v))' in candidate["scripts/settings_panel.gd"], "panel uses dynamic setter after capability check")
    settings = candidate["scripts/settings.gd"]
    check('var effects_quality := "standard"' in settings and 'c.set_value("show", "effects_quality", effects_quality)' in settings and
          'saved_effects is String and saved_effects in ["standard", "reduced"] else "standard"' in settings, "new full source defaults, persists and validates preference")
    qa = (HERE/"qa.gd.in").read_text(encoding="utf-8")
    check(qa.encode() == (HERE/"generated/driver.gd").read_bytes() and sha(qa.encode()) == receipt["qa_sha256"], "generated QA equals pinned template")
    check(sha((HERE/"candidate.patch").read_bytes()) == receipt["patch_sha256"], "patch receipt matches")
    check(sha((HERE/"prepare.py").read_bytes()) == receipt["generator_sha256"] and
          sha((HERE/"qa_extra.gd.in").read_bytes()) == receipt["extra_qa_sha256"], "generation inputs match receipt")
    executable_qa = "\n".join(line for line in qa.splitlines() if not line.lstrip().startswith("#"))
    check(re.search(r"\b(?:Settings|Sfx|Music|Art|Campaign)\.", executable_qa) is None, "QA has no direct Autoload symbols during script startup")
    for seam in ("func _settings_missing_corrupt_cases()", "func _in_tree_lifecycle_cases()", "func _critical_feedback_cases()",
                 "func _critical_fire_case()", "func _critical_axes_case()", "func _legacy_autoload_cases()"):
        check(qa.count(seam) == 1, "one executable QA seam " + seam)
    for token in ('for cycle in range(2)', 'fx.tree_exited.connect', 'ref.get_ref() == null', 'b._ground_fire_visuals == 0',
                  'fx.is_queued_for_deletion()', 'await process_frame', 'invalid_error == ERR_PARSE_ERROR',
                  'root.get_node("Art").item_texture("axe")', 'class AxeCoreOracle', 'fire keeps authored-radius ground anchor'):
        check(token in qa, "required bounded evidence prepared: " + token)
    suppression = qa[qa.index("Engine.print_error_messages = false"):qa.index("Engine.print_error_messages = print_errors_before")]
    check("await " not in suppression and "invalid.load(FIXTURE_SETTINGS)" in suppression and "_fresh_settings()" in suppression,
          "expected damaged-config console suppression has no asynchronous gap")
    check(sha((ROOT/"scratchpad/reduced_effects_candidate.patch").read_bytes()) == pins["v1_patch_raw_sha256"] and
          sha((ROOT/"scratchpad/reduced_effects_qa.gd.in").read_bytes()) == pins["v1_qa_raw_sha256"], "old draft inputs remain byte-identical")

    launcher = namespace(HERE / "launch_check.py")
    files = {name: text.encode() for name,text in candidate.items()}
    files.update({name:(ROOT/name).read_bytes() for name in pins["startup_dependency_raw_sha256"]})
    files["qa/generated/driver.gd"] = qa.encode()
    files["safety"] = (ROOT/"scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py").read_bytes()
    launcher["ROOT"] = FakePath("", files); launcher["HERE"] = FakePath("qa", files); launcher["SAFETY"] = FakePath("safety", files)
    gate = launcher["check_live_source"]
    check(gate(pins,receipt,"candidate") == pins["candidate_lf_sha256"], "synthetic exact candidate accepts before launch")
    files["scripts/settings.gd"] = base["scripts/settings.gd"].encode()
    check(gate(pins,receipt,"legacy")["scripts/settings.gd"] == pins["base_lf_sha256"]["scripts/settings.gd"], "synthetic explicit legacy profile accepts old Settings")
    def rejects(label, action):
        try: action()
        except RuntimeError: check(True,label)
        else: check(False,label)
    rejects("candidate profile rejects legacy Settings before launch", lambda: gate(pins,receipt,"candidate"))
    files["scripts/settings.gd"] = candidate["scripts/settings.gd"].encode()
    files["scripts/unit.gd"] += b"# changed\n"
    rejects("source drift rejects before any process call", lambda: gate(pins,receipt,"candidate"))
    files["scripts/unit.gd"] = candidate["scripts/unit.gd"].encode()
    files["qa/generated/driver.gd"] += b"# changed\n"
    rejects("QA drift rejects before any process call", lambda: gate(pins,receipt,"candidate"))
    files["qa/generated/driver.gd"] = qa.encode()
    files["project.godot"] += b'\nconfig/use_custom_user_dir=true\n'
    rejects("project source drift rejects before Autoload parsing", lambda: gate(pins,receipt,"candidate"))
    synthetic_pins = json.loads(json.dumps(pins))
    synthetic_pins["startup_dependency_raw_sha256"]["project.godot"] = sha(files["project.godot"])
    rejects("even a re-pinned custom user directory requires separate review", lambda: gate(synthetic_pins,receipt,"candidate"))
    output = {"passed": all(row["passed"] for row in results), "checks": len(results), "results": results,
              "godot_run":False,"gdscript_parsed_or_executed":False,"git_run":False,"production_mutated":False,
              "launcher_process_lifecycle_tested_here":False,"gameplay_or_render_results_claimed":False}
    (HERE/"static_receipt.json").write_bytes((json.dumps(output,ensure_ascii=False,indent=2)+"\n").encode())
    print(json.dumps({key: value for key,value in output.items() if key != "results"}))


if __name__ == "__main__": main()
