"""Strict fixed predicates retained from immutable r2b2; distinct durable report schemas."""
import re
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
CASES = ("A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal")
RETREAT_CASES = CASES
def require(condition, message):
    if not condition: raise RuntimeError(message)

def validate_world(data, interface):
    require(data.get("schema") == interface["report_schema"]
                 and all(data.get(k) is True for k in ["pure_matrix_passed", "fixture_ready", "matrix_complete"])
                 and data.get("whole_world_dto_negative_only") is True, "world DTO scope/matrix missing")
    for k in ["overall_v25_qualified", "live_object_capture_negative_implemented", "live_object_capture_negative_qualified", "separate_component_harness_implemented", "future_producer_integration_qualified"]:
        require(data.get(k) is False, "DTO claimed another scope")
    require(all(type(data.get(k)) is int and data[k] == 0 for k in ["disk_slot_writes", "direct_gameplay_calls", "cached_grids_cleared"]), "DTO side effects claimed")
    expected = {(r["case"], r["route"]): r for r in interface["route_expectations"]}
    rows = data.get("executed_rows")
    require(isinstance(rows, list) and len(rows) == 264, "world exact264 rows absent")
    actual = {(r.get("case"), r.get("route")): r for r in rows}
    require(len(actual) == 264 and set(actual) == set(expected), "world duplicated/missing fixed routes")
    for key, row in actual.items():
        require(set(expected[key]) <= set(row), "world actual mandatory nullable evidence key omitted")
        for field, value in expected[key].items():
            require(type(row.get(field)) is type(value) and row.get(field) == value, "world actual route layer/nullable observation mismatch: " + field)
        require(row.get("passed") is True and row.get("actual_code") == expected[key]["expected_code"]
                     and row.get("source_input_type_ieee_exact") is True and row.get("cached_grids_preserved") is True
                     and HEX64.fullmatch(row.get("mutated_packet_sha256", ""))
                     and HEX64.fullmatch(row.get("typed_document_sha256", "")), "world actual immutable source/code proof missing")
    positives = data.get("positives")
    require(isinstance(positives, list) and len(positives) == 2 and {r["route"] for r in positives} == {"source", "json"}
                 and all(all(r.get(k) is True for k in ["actual_A_unmodified", "prepared", "detached_inert", "input_exact"]) for r in positives),
                 "world actual A full original positive prepare not proven")

def validate_component(data, interface):
    require(data.get("schema") == interface["report_schema"]
                 and all(data.get(k) is True for k in ["pure_matrix_passed", "fixture_ready", "component_matrix_complete"])
                 and data.get("independent_component_calls_implemented") is True
                 and data.get("whole_world_DTO_prepare_substitution") is False, "independent actual component scope incomplete")
    for key in ["overall_v25_qualified", "future_producer_integration_qualified", "native_zero_ERROR_log_verified", "actual_two_unretreated_whole_fixture_qualified"]:
        require(data.get(key) is False, "component falsely qualified wider scope")
    for key in ["actual_Core_prepare_calls", "actual_Core_capture_calls", "disk_slot_writes", "local_journal_writes", "gameplay_ticks_injected", "cached_grids_cleared"]:
        require(type(data.get(key)) is int and data[key] == 0, "component source-only side effect violated")
    expected = {(r["id"], r["route"]): r for r in interface["required_route_rows"]}
    rows = data.get("executed_rows")
    require(isinstance(rows, list) and len(rows) == 362, "component exact362 target calls absent")
    actual = {(r.get("id"), r.get("route")): r for r in rows}
    require(len(actual) == len(rows) and set(actual) == set(expected), "component duplicated/missing fixed rows")
    fields = ["id", "route", "module", "actual_call", "expected_code", "expected_guard_layer",
              "core_constructor_called", "core_prepare_called", "core_capture_called",
              "core_zero_before", "core_zero_after", "direct_pair_branch_called"]
    for key, row in actual.items():
        require(set(fields) <= set(row), "component actual mandatory nullable evidence key omitted")
        for field in fields:
            value = expected[key][field]
            require(type(row.get(field)) is type(value) and row.get(field) == value, "component actual API/nullable Core row mismatch")
        require(all(row.get(k) is True for k in ["passed", "actual_component_call_executed", "input_type_ieee_unchanged", "original_A_type_ieee_unchanged", "native_node_count_unchanged"])
                     and row.get("actual_code") == expected[key]["expected_code"]
                     and row.get("input_type_ieee_sha256_before") == row.get("input_type_ieee_sha256_after")
                     and re.fullmatch(r"[0-9a-f]{64}", row.get("input_type_ieee_sha256_before", "")),
                     "component actual unchanged typed input/refusal missing")
        require(row.get("native_node_count_before") == row.get("native_node_count_after"), "component actual native Node allocation changed")
    positives = data.get("positives")
    require(isinstance(positives, list) and len(positives) == 8
                 and {(r.get("id"), r.get("route")) for r in positives} == {(r["id"], r["route"]) for r in interface["required_positives"]}
                 and all(r.get("passed") is True for r in positives), "component actual original positives missing or fabricated")

def validate_capture(data, interface, fixture, case, expected_code):
    require(data.get("schema") == interface["report_schema"] and data.get("case") == case
                 and all(data.get(k) is True for k in ["row_completed", "actual_Core_capture_called", "actual_live_object_capture", "successful_handoff_owned_world_tracked"])
                 and data.get("harness_revision") == "campaign_v2_r1" and data.get("planned_cases") == 24
                 and data.get("live_cast_cases_implemented") == 5, "actual d1 full24 live capture row absent")
    for key in ["whole_live_capture_matrix_qualified", "overall_v25_qualified", "separate_component_harness_implemented", "native_log_zero_ERROR_verified"]:
        require(data.get(key) is False, "single live row claimed aggregate/wider scope")
    for key in ["disk_slot_writes", "gameplay_ticks_injected", "grid_clears", "runtime_patches"]:
        require(type(data.get(key)) is int and data[key] == 0, "live row mutation scope violated")
    row = data.get("executed_live_row")
    require(isinstance(row, dict) and set(interface["required_row_fields"]) <= set(row)
                 and row.get("case") == case and row.get("first_role") == fixture["first_role"]
                 and row.get("expected_code") == row.get("actual_code") == expected_code
                 and row.get("DTO_substitution") is False, "actual live row precise source/code missing")
    for key in ["passed", "actual_Core_capture_called", "single_live_field_applied",
                "temporary_field_unchanged_by_capture", "original_field_type_ieee_restored",
                "retained_identity_same_live_unchanged", "source_held_no_ticks_no_nodes_added"]:
        require(row.get(key) is True, "live full source/identity/no-tick restoration missing")
    if case.startswith("safe_caster_"):
        array = case.removeprefix("safe_caster_")
        require(row.get("cast_component_capture_called") is True and row.get("cast_component_capture_accepted") is True
                     and row.get("expected_guard_layer") == row.get("actual_guard_layer") == "level8_safe_pair"
                     and row.get("actual_section") == row.get("actual_pair_array") == row.get("expected_pair_array") == array
                     and row.get("direct_safe_cast_pair_coverage") is True
                     and re.fullmatch(r"[1-9][0-9]*", row.get("actual_caster_object_id", "")),
                     "actual live array component acceptance and pair section proof missing")
    validate_hold(data, CASES[2])

INHERITED_INSTALL_LABELS = {
    "correct preceding genuinely distinct process", "prior disk bytes and generation verified",
    "same frozen source and actual engine across processes", "actual Session prepare_restore succeeds",
    "actual Session paused stage_mount succeeds", "actual Session commit_restore_async succeeds",
    "fresh full Core capture at real restored HELD", "complete whole-world envelope and field set exact",
    "whole-world schema/profile/context/content/engine envelope exact", "complete exact section keyset retained",
    "every non-payload mission wrapper field exact", "every non-payload root wrapper field exact",
    "full Root clock subfield schemas exact", "all complete non-root sections exact after independent install",
    "Mission complete wall age rebased within real prepare/capture intervals",
    "Root logical tick/cache phase and mount/HELD input clock contract exact",
    "all Root non-clock values/references/grids/economy exact", "every Session Campaign option installed exactly",
    "every Session setting installed exactly", "every installed profile flag exact after Session commit",
    "Session context and saved resume pause actually installed", "actual durable local lifecycle binding exact",
    "Steam-disabled Session active lease/context installed", "complete saved Visual root_node installed exactly at HELD",
    "new Mission and all Units refer to installed new Battle",
}

def validate_case_labels(data, case):
    labels = {r["label"] for r in data["checks"]}
    mandatory = {"producer pinned exact installed content and engine"}
    if case in RETREAT_CASES[:3]: mandatory.add("one safe actor remains coherent full FIGHT")
    if case == RETREAT_CASES[0]:
        mandatory |= {"fresh profile has no previous level8 result", "real safe report appears once and other report absent",
                      "single safe full state HELD", "complete Session save_held succeeds", "actual committed disk head matches receipt"}
        require(data.get("single_safe_disk_case_qualified") is True and data.get("natural_victory_qualified") is False,
                     "A natural save eligibility missing")
    elif case in RETREAT_CASES[1:3]: mandatory |= INHERITED_INSTALL_LABELS
    if case == RETREAT_CASES[1]:
        mandatory |= {"B independently installed generation1 and no driver commands", "B observed real ordinary clock ticks",
                      "B Mission elapsed follows real physics ticks", "safe actor report/action/control identity does not replay or revive",
                      "complete Session save_held succeeds"}
        require(data.get("orders") == 0 and data.get("single_safe_disk_case_qualified") is True,
                     "B issued commands or failed resave")
    if case == RETREAT_CASES[2]:
        mandatory |= {"C independent generation2 install and no driver commands", "actual durable local terminal completes before outcome claim",
                      "one observed natural durable terminal notification", "normal completion froze actual Mission result",
                      "same-run local campaign core result present in memory", "private Steam service performs zero credited settlement",
                      "actual terminal HUD displayed after completion", "safe and victory reports each exactly once",
                      "post-terminal normal frames add no result or callback signal", "actual terminal preserves last complete generation2 slot bytes"}
        require(data.get("natural_victory_qualified") is True and data.get("local_terminal_readback_qualified") is False,
                     "C actual natural terminal not qualified")
    if case == RETREAT_CASES[3]:
        mandatory |= {"new process verifies old slot remains exact generation2", "new process exact terminal receipt full readback",
                      "new process reloads confirmed Campaign records",
                      "actual Session refuses obsolete active slot after durable terminal",
                      "terminal rejected before any new Battle Unit or graph allocation"}
        require(data.get("orders") == 0 and data.get("local_terminal_readback_qualified") is True
                     and data.get("natural_victory_qualified") is False, "D terminal-only readback eligibility wrong")
    require(mandatory <= labels, "missing v25 strict coverage: " + str(sorted(mandatory - labels)))

def validate_hold(data, case):
    hold_labels = {RETREAT_CASES[0]: ["single retreat first completed physics"],
                   RETREAT_CASES[1]: ["restored complete world", "B settled single-safe resave"],
                   RETREAT_CASES[2]: ["restored complete world"], RETREAT_CASES[3]: []}[case]
    labels = {r["label"] for r in data["checks"]}
    expected_labels = set()
    for label in hold_labels:
        expected_labels |= {label + " actual barrier request", label + " real healthy HELD", label + " exact two owned one-shot barrier listeners"}
        for stage in ["before_connect", "after_wait"]:
            expected_labels.add(label + " " + stage + " both own barrier listeners cleared")
            for signal in ["capture_ready", "capture_rejected"]:
                expected_labels.add(label + " " + stage + " " + signal + " only own listeners cleared")
    require(expected_labels <= labels, "v25s exact hold cleanup branches not reported")
    audits = [r["hold_connection_audit"] for r in data.get("observations", []) if "hold_connection_audit" in r]
    require([(r.get("label"), r.get("stage")) for r in audits] ==
                 [(label, stage) for label in hold_labels for stage in ["before_connect", "installed", "after_wait"]],
                 "v25s actual hold audit lifecycle sequence missing or duplicated")
    for audit in audits:
        require(set(audit.get("signals", {})) == {"capture_ready", "capture_rejected"}, "v25s both barrier signal audits required")
        if audit["stage"] == "installed":
            require(audit.get("ready_error") == audit.get("rejected_error") == 0, "v25s barrier connect failed")
            targets = []
            for signal, method in [("capture_ready", "_on_held"), ("capture_rejected", "_on_rejected")]:
                row = audit["signals"][signal]
                require(row.get("own_count") == 1 and row.get("flags") == [4] and row.get("methods") == [method]
                             and row.get("bound_counts") == [0] and row.get("unbound_counts") == [0],
                             "v25s exact own unbound one-shot listener missing")
                require(isinstance(row.get("targets"), list) and len(row["targets"]) == 1
                             and type(row["targets"][0]) is int and row["targets"][0] > 0, "v25s actual listener target ID missing")
                targets.append(row["targets"][0])
            require(targets[0] == targets[1], "v25s callbacks target different actual QA objects")
        else:
            for signal in ["capture_ready", "capture_rejected"]:
                row = audit["signals"][signal]
                require(row.get("own_after") == 0 and row.get("flags_after") == []
                             and row.get("other_before") == row.get("other_after") and row.get("other_unchanged") is True,
                             "v25s cleanup left own link or changed another owner's listener")
                require(row.get("own_count") in [0, 1]
                             and row.get("flags") == ([] if row["own_count"] == 0 else [4]), "v25s unexpected stale own connection")
                if audit["stage"] == "after_wait":
                    require(row["own_count"] == (0 if signal == "capture_ready" else 1),
                                 "v25s ready not consumed or rejected not explicitly cleared after success")
