"""Preserved original JSON533, OwnedSlot76 and admission mandatory/hold predicates.
The two legacy pure validators retain their original function bodies exactly.
Admission verify_slot and URI custody are explicit successors for continue/v1.
"""
import hashlib
import json
from pathlib import Path
import re
from durable_campaign_full_runtime import no_links, read, sha
from durable_campaign_full_evidence_v2 import data_tree, envelope, file_pin
from durable_campaign_full_matrices import require

CASES = ('A_half_save', 'B_continue_resave', 'C_verify_resave')
BOUNDARY_CASES = {'actual_v24p_pending', 'gao', 'daming', 'level1', 'level2', 'level3', 'level4', 'level6', 'level7', 'classic_liangshan', 'classic_none'}

def no_reparse(path):
    no_links(path)
    return Path(path)

class LegacyPredicates:
    def boundary_passed(self, step, log, report_path, nonce):
        require(step["exit_code"] == 0 and step["process_terminal"], "pure JSON boundary native process not terminal0")
        data = read(report_path)
        require(data.get("schema") == "native_ownership_json_boundary_report_v24q" and data.get("passed") is True
                and isinstance(data.get("checks"), list) and data["checks"]
                and all(isinstance(row, dict) and row.get("passed") is True for row in data["checks"]), "JSON boundary checks not fully passed")
        require(data.get("pid") == step["pid"] and data.get("nonce") == nonce
                and data.get("content_version") == self.installed["content_version"]
                and data.get("engine_sha256") == self.receipt["godot_sha256"], "boundary PID/nonce/actual native identity mismatch")
        userdata = no_reparse(Path(data["actual_user_data_dir"]).resolve())
        require(userdata.is_relative_to((self.profile / "appdata").resolve()), "boundary userdata escaped own private profile")
        require(data.get("harness_revision") == "v24q1", "new wrong-kind fixture revision not executed")
        negative_evidence = data.get("negative_node_kind_evidence")
        require(isinstance(negative_evidence, list) and len(negative_evidence) == 2
                and {row.get("case") for row in negative_evidence} == {"gao", "daming"}, "exact two actual negative node-kind proofs missing")
        frozen_rows = {row["case"]: row for row in self.boundary["manifest"]["maps"]}
        frozen_files = {row["original_path"]: row for row in self.boundary["files"]}
        for row in negative_evidence:
            fixture = frozen_rows[row["case"]]
            expected_fixture = frozen_files[fixture["path"]]
            require(Path(row["fixture_path"]).resolve() == Path(expected_fixture["path"]).resolve()
                    and row["fixture_sha256"] == expected_fixture["sha256"], "wrong-kind fixture provenance differs from actual frozen world")
            require(row.get("owner_path") == "ownership/sprites/0" and row.get("original_kind") == "sprite"
                    and row.get("selected_kind") == ("entrance" if row["case"] == "gao" else "night")
                    and type(row.get("original_index")) is int and row["original_index"] > 0
                    and type(row.get("selected_index")) is int and row["selected_index"] > 0
                    and row["original_index"] != row["selected_index"]
                    and type(row.get("selected_parent")) is int and row["selected_parent"] >= 0,
                    "wrong-kind fixture is not an actual distinct legal non-root node")
            for field in ["original_tagged_node_sha256", "selected_tagged_node_sha256", "source_map_sha256"]:
                require(isinstance(row.get(field), str) and re.fullmatch(r"[0-9a-f]{64}", row[field]), "actual negative node tagged/map SHA proof missing")
        step["negative_node_kind_evidence"] = negative_evidence
        require(isinstance(data.get("cases"), list) and {row.get("case") for row in data["cases"]} == BOUNDARY_CASES
                and len(data["cases"]) == len(BOUNDARY_CASES), "boundary full actual/L5/L8/six/std/none case set missing")
        expected = {str(self.boundary["frozen_manifest"]): sha(self.boundary["frozen_manifest"]), **{row["path"]: row["sha256"] for row in self.boundary["files"]}}
        observed = {}
        for row in data.get("provenance", []):
            path = no_reparse(Path(row["path"]).resolve())
            require(str(path) in expected and sha(path) == expected[str(path)] == row["sha256"], "boundary actually-read provenance mismatch")
            if str(path) != str(self.boundary["frozen_manifest"]):
                require(row.get("utf8_bytes") == path.stat().st_size, "boundary fixture read UTF8 byte count mismatch")
            observed[str(path)] = row["sha256"]
        require(observed == expected, "boundary did not read every fixed manifest/source fixture")
        source_rows = data.get("source_files")
        expected_source_paths = {"scripts/run_scenery_state.gd", "scripts/run_scenery_json_boundary.gd", "scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd", "scripts/run_state_value_codec.gd"}
        require(isinstance(source_rows, list) and len(source_rows) == len(expected_source_paths)
                and {row.get("path") for row in source_rows} == {"res://" + path for path in expected_source_paths}, "boundary exact five executed source rows missing")
        source_files = {row["path"]: row["sha256"] for row in source_rows}
        for path in expected_source_paths:
            require(source_files["res://" + path] == sha(self.project / path), "boundary installed source pin mismatch: " + path)
        require(data.get("pure_fixed_validator") is True
                and all(data.get(key) == 0 for key in ["battle_factory_calls", "deploy_or_tick_calls", "disk_slot_writes", "private_runtime_patches"])
                and all(data.get(key) is False for key in ["full_world_continuation_qualified", "natural_result_qualified", "public_campaign_entry_qualified"])
                and "NATIVE_OWNERSHIP_JSON_V24Q_COMPLETE " in log, "boundary pure-scope/terminal marker missing")
        step.update(report=str(report_path), report_sha256=sha(report_path), checks=len(data["checks"]), cases=sorted(BOUNDARY_CASES), actual_content_version=data["content_version"])
        self.receipt["json_boundary_report"] = {"path": str(report_path), "sha256": sha(report_path), "pid": step["pid"], "nonce": nonce, "checks": len(data["checks"]), "cases": sorted(BOUNDARY_CASES)}

    def owned_passed(self, step, log):
        require(step["exit_code"] == 0 and step["process_terminal"], "original OwnedSlot native process not terminal0")
        match = re.search(r"OWNED_SLOT_RETRY_QA ([0-9]+) true (.+)", log)
        require(match is not None, "original OwnedSlot successful terminal report marker missing")
        path = no_reparse(Path(match.group(2).strip()).resolve())
        require(path.name == "report.json" and path.parent.name == "owned_slot_retry_qa"
                and path.is_relative_to((self.profile / "appdata").resolve()), "OwnedSlot report outside own original fixture directory")
        data = read(path)
        rows = data.get("checks")
        require(data.get("passed") is True and isinstance(rows, list) and rows
                and int(match.group(1)) == len(rows)
                and all(isinstance(row, dict) and isinstance(row.get("name"), str) and row["name"] and row.get("passed") is True for row in rows), "original OwnedSlot checks not all passed")
        mandatory = {"release retryable with committed action", "pending retry uses validated forward action", "prewrite missing pending retries frozen proposal", "owner_readback missing pending retries frozen proposal", "wrong token refused with unsafe flags", "different owner refused", "new object cannot adopt same PID proposal", "corrupt pending refuses automatic repair", "corrupt pending retained byte for byte", "different valid pending cannot replace original intent", "partial release without token stays unsafe", "session exposes pending disk transaction", "session refuses disposal while token is needed", "session will not save and quit an unrelated source", "original store still completes after disposal refusal", "session disposal allowed after transaction completes"}
        require(mandatory <= {row["name"] for row in rows}, "original OwnedSlot branch assertions missing")
        require(all(data.get(key) is False for key in ["real_steam", "production_slot_document", "full_world_flow"]), "OwnedSlot scope overclaim")
        for relative in ["scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd", "scripts/run_world_session.gd", "tools/owned_slot_retry_qa.gd"]:
            require(data.get("source_sha256", {}).get("res://" + relative) == sha(self.project / relative), "OwnedSlot actual executed source SHA mismatch: " + relative)
        self.copy_checked(path, Path(step["step_dir"]) / "report.json", sha(path))
        step.update(report=str(path), report_sha256=sha(path), checks=len(rows), original_tool_sha256=sha(self.project / "tools/owned_slot_retry_qa.gd"))
        self.receipt["owned_slot_retry_report"] = {"path": str(path), "sha256": sha(path), "pid": step["pid"], "checks": len(rows), "production_slot_document": False, "original_tool_unchanged": True}

    def validate_case(self, case, step, text):
        require(step["exit_code"] == 0 and step["process_terminal"] is True, "native case did not actually terminate successfully")
        path = self.output / case / "report.json"
        data = read(path)
        require(data.get("passed") is True and data.get("checks") and all(row.get("passed") is True for row in data["checks"]), "native case/report checks not fully passed")
        require(data["case"] == case and data["pid"] == step["pid"] and data["nonce"] == step["process_nonce"], "native PID/case/nonce mismatch")
        require(data["trusted"]["content_version"] == self.installed["content_version"] and data["trusted"]["engine_binary_sha256"] == self.receipt["godot_sha256"], "native actual content/engine differs from independently pinned inputs")
        require(data.get("teleports") == 0 and data.get("fixture_ticks") == 0 and data.get("progress_injections") == 0 and data.get("clock_acceleration") is False, "native fixture boundary violated")
        require(data.get("public_campaign_continue_qualified") is False and data.get("natural_victory_qualified") is False and data.get("reward_once_qualified") is False, "native scope overclaim")
        for row in data["evidence"]:
            target = self.evidence_path(data, row["path"])
            require(target.is_file() and sha(target) == row["sha256"], "native original evidence file changed/missing")
        labels = {row["label"] for row in data["checks"]}
        mandatory = {"producer pinned exact installed content and engine"}
        if case == CASES[0]:
            mandatory |= {"normal Battle launch already classifies actual Daming context", "native manual admission observed in partial-progress window", "HELD still contains actual incomplete admission", "complete Session save_held succeeds", "actual committed disk head matches receipt"}
            require(data["orders"] == 2, "A ordinary two-mover route not executed")
        else:
            mandatory |= {"correct preceding genuinely distinct process", "prior disk bytes and generation verified", "same frozen source and actual engine across processes", "actual Session prepare_restore succeeds", "actual Session commit_restore_async succeeds", "fresh full Core capture at real restored HELD", "complete whole-world envelope and field set exact", "whole-world schema/profile/context/content/engine envelope exact", "complete exact section keyset retained", "every non-payload mission wrapper field exact", "every non-payload root wrapper field exact", "full Root clock subfield schemas exact", "all complete non-root sections exact after independent install", "Mission complete wall age rebased within real prepare/capture intervals", "Root logical tick/cache phase and mount/HELD input clock contract exact", "all Root non-clock values/references/grids/economy exact", "every Session Campaign option installed exactly", "every Session setting installed exactly", "every installed profile flag exact after Session commit", "Session context and saved resume pause actually installed", "actual durable local lifecycle binding exact", "Steam-disabled Session active lease/context installed", "complete saved Visual root_node installed exactly at HELD"}
            require(data["orders"] == 0, "B/C driver issued gameplay orders")
        if case == CASES[1]: mandatory |= {"original natural native tick completes admission after resume", "admission event/report/control/marker effects occur exactly once", "Mission elapsed advances only by resumed fixed physics ticks", "complete Session save_held succeeds"}
        if case == CASES[2]: mandatory |= {"second generation independently read and no driver orders", "requested real uninterrupted ticks observed", "final running-world complete capture succeeds", "process C leaves generation-two disk slot intact"}
        hold_labels = ["A partial admission"] if case == CASES[0] else ["restored complete world", "B admitted resave" if case == CASES[1] else "C post-run final audit"]
        for hold_label in hold_labels:
            mandatory |= {hold_label + " actual barrier request", hold_label + " real healthy HELD", hold_label + " exact two owned one-shot barrier listeners"}
            for stage in ["before_connect", "after_wait"]:
                mandatory.add(hold_label + " " + stage + " both own barrier listeners cleared")
                for signal_name in ["capture_ready", "capture_rejected"]:
                    mandatory.add(hold_label + " " + stage + " " + signal_name + " only own listeners cleared")
        audits = [row["hold_connection_audit"] for row in data.get("observations", []) if "hold_connection_audit" in row]
        require(len(audits) == len(hold_labels) * 3, "actual hold connection lifecycle row count mismatch")
        require([(row.get("label"), row.get("stage")) for row in audits] == [(label, stage) for label in hold_labels for stage in ["before_connect", "installed", "after_wait"]], "actual hold connection lifecycle sequence mismatch")
        for audit in audits:
            require(set(audit.get("signals", {})) == {"capture_ready", "capture_rejected"}, "actual both barrier signal audit absent")
            if audit["stage"] == "installed":
                require(audit.get("ready_error") == 0 and audit.get("rejected_error") == 0, "actual barrier connect failed")
                targets = []
                for signal_name, method in [("capture_ready", "_on_held"), ("capture_rejected", "_on_rejected")]:
                    row = audit["signals"][signal_name]
                    require(row.get("own_count") == 1 and row.get("flags") == [4] and row.get("methods") == [method] and row.get("bound_counts") == [0] and row.get("unbound_counts") == [0], "actual exact one-shot callable/flags mismatch")
                    require(isinstance(row.get("targets"), list) and len(row["targets"]) == 1 and isinstance(row["targets"][0], int) and row["targets"][0] > 0, "actual callable target absent")
                    targets.append(row["targets"][0])
                require(targets[0] == targets[1], "barrier callbacks do not target same actual QA instance")
            else:
                for signal_name in ["capture_ready", "capture_rejected"]:
                    row = audit["signals"][signal_name]
                    require(row.get("own_after") == 0 and row.get("flags_after") == [] and row.get("other_before") == row.get("other_after") and row.get("other_unchanged") is True, "cleanup left own listener or changed another callback")
                    require(row.get("own_count") in [0, 1] and row.get("flags") == ([] if row["own_count"] == 0 else [4]), "unexpected stale own listener count/flags")
                    if audit["stage"] == "after_wait":
                        require(row["own_count"] == (0 if signal_name == "capture_ready" else 1), "actual success did not consume ready while retaining then clearing rejected one-shot")
        require(mandatory <= labels, "required original case coverage absent: " + str(sorted(mandatory - labels)))
        require("DAMING_ADMIT_V24O_COMPLETE " + case in text, "native terminal marker missing")
        handoff_name = "handoff_A.json" if case == CASES[0] else "handoff_B.json"
        handoff_path = Path(data["actual_user_data_dir"]) / "daming_admit_v24o" / handoff_name
        handoff = read(handoff_path)
        generation = 1 if case == CASES[0] else 2
        require(int(handoff["generation"]) == generation, "unexpected saved generation")
        if case != CASES[2]: require(handoff["pid"] == step["pid"] and handoff["nonce"] == step["process_nonce"] and handoff["mode"] == case, "saved handoff not from actual current native process")
        if case != CASES[0]:
            preceding = CASES[0] if case == CASES[1] else CASES[1]
            prior = self.reports[preceding]
            require(data["previous_pid"] == prior["pid"] and data["previous_nonce"] == prior["nonce"], "native preceding-process chain broken")
            require(step["pid"] not in [report["pid"] for report in self.reports.values()] and step["process_nonce"] not in [report["nonce"] for report in self.reports.values()], "native process/nonce reused")
            earlier_step = [row for row in self.receipt["steps"] if row["case"] == preceding][0]
            require(earlier_step["process_terminal"] and earlier_step["native_finished_ns"] <= step["native_started_ns"], "native processes overlap or predecessor terminal unverified")
        slot = self.verify_slot(data, handoff, generation)
        step.update(report=str(path), report_sha256=sha(path), checks=len(data["checks"]),
                    slot_sha256=slot["sha256"], slot=slot, actual_content_version=data["trusted"]["content_version"])
        self.reports[case] = {"pid": step["pid"], "nonce": step["process_nonce"], "report": str(path),
                              "report_sha256": sha(path), "checks": len(data["checks"]), "slot_sha256": slot["sha256"], "generation": generation}
        self.receipt["reports"][case] = self.reports[case]
