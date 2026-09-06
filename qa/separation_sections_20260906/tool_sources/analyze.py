"""Read-only analysis of paired M1 and separation sidecar reports."""
import math


def need(ok, message):
    if not ok: raise RuntimeError(message)


def analyze(m1, data):
    need(m1.get("integrity_passed") and m1.get("sample_complete") and m1.get("acceptance_eligible") is False,"Incomplete/eligible M1 diagnostic")
    need(m1["requested_seconds"]==10 and m1["scenario"]=="defense200" and m1["camera_mode"]=="fixed","Wrong bounded M1 workload")
    need(data.get("valid") and data["errors"]==0 and not data["overflow"],"Invalid solve ledger")
    steps=data["steps"]; frames=data["presentations"]; processes=data["processes"]
    si={key:i for i,key in enumerate(data["step_columns"])}
    fi={key:i for i,key in enumerate(data["presentation_columns"])}
    need(len(si)==17 and len(fi)==7 and all(len(row)==17 for row in steps),"Ledger shape changed")
    need([row[si["m1_tick"]] for row in steps]==list(range(1,len(steps)+1)),"Missing/duplicated M1 step")
    start=data["m1_start"]; end=data["m1_end"]
    need(start["m1_tick"]==m1["sample_start"]["tick"] and end["m1_tick"]==m1["sample_end"]["tick"],"M1 measurement anchors disagree")
    need(end["m1_tick"]==len(steps)==data["step_count"] and end["m1_tick"]-start["m1_tick"]==m1["physics_ticks"],"Last step missing or measurement count wrong")
    need(start["step_count"]==start["m1_tick"] and end["step_count"]==len(steps),"Anchor row boundaries drifted")
    for index,row in enumerate(steps):
        need(row[si["dispatch_count"]]==1,"Expected one original Battle dispatch per step")
        route=row[si["route"]]
        need(route in (0,1,2),"Unknown dispatch route")
        need(row[si["solve_calls"]]==(1 if route==0 else 0) and row[si["stage_mask"]]==(15 if route==0 else 0),"Buffered dispatch/complete solve coverage mismatch")
        need(row[si["physics_signal_us"]]<=row[si["observer_us"]]<=row[si["collected_us"]],"Same-clock physics anchors reversed")
        need(row[si["collection_physics_id"]] in (row[si["physics_id"]],row[si["physics_id"]]+1),"Step collected at unrelated physics boundary")
        if index: need(row[si["physics_id"]]==steps[index-1][si["physics_id"]]+1,"Engine physics ID skipped/repeated")
        need(all(row[si[key]]>=0 for key in ("snapshot_us","profile_cells_us","pairs_us","publish_us")),"Negative span")
        if not data["timed"]: need(sum(row[13:])==0,"Clockless mode unexpectedly has solve timing")
    need(len(frames)==data["presentation_count"]==m1["frames"]==len(m1["raw_frame_ms"]),"Presentation row count drifted")
    cursor=start["step_count"]; stamp=start["us"]; linked=0
    process_ids={}
    for row in processes:
        need(len(row)==3 and row[1] not in process_ids,"Duplicate process signal or wrong shape")
        process_ids[row[1]]=row
    for index,frame in enumerate(frames):
        need(len(frame)==7 and frame[fi["start_us"]]==stamp and frame[fi["end_us"]]>=stamp,"M1 presentation timestamp chain broke")
        need(math.isclose((frame[fi["end_us"]]-stamp)/1000,m1["raw_frame_ms"][index],abs_tol=1e-8),"M1 raw interval differs from same-clock presentation anchor")
        a=frame[fi["step_begin_index"]];z=frame[fi["step_end_index"]]
        need(a==cursor and a<=z<=len(steps),"Frame step ranges overlap/skip")
        need(frame[fi["m1_tick"]]==z,"M1 tick at presentation differs from completed step range")
        pid=frame[fi["process_id"]]
        need(pid in process_ids,"Presentation lacks its process signal anchor")
        need(stamp<=process_ids[pid][0]<=frame[fi["end_us"]],"Process signal outside its presentation interval")
        for row in steps[a:z]:
            need(row[si["process_id"]]==pid,"Physics step belongs to another process frame")
            need(stamp<=row[si["physics_signal_us"]]<=row[si["observer_us"]]<=frame[fi["end_us"]],"Physics step outside exact same-clock frame interval")
            linked+=1
        cursor=z;stamp=frame[fi["end_us"]]
    need(cursor==len(steps) and linked==m1["physics_ticks"] and end["us"]>=stamp,"Final physics/presentation tail not accounted")
    selected=steps[start["m1_tick"]:end["m1_tick"]]
    def summary(rows):
        count=sum(row[si["route"]]==0 for row in rows)
        totals={key:sum(row[si[key]] for row in rows) for key in ("snapshot_us","profile_cells_us","pairs_us","publish_us")}
        total=sum(totals.values())
        return {"physics_steps":len(rows),"buffered_solve_calls":count,
            "dispatch_counts":{str(route):sum(row[si["route"]]==route for row in rows) for route in (0,1,2)},
            "stage_total_us":totals,"mean_us_per_buffered_solve":{key:value/count if count and data["timed"] else None for key,value in totals.items()},
            "mean_us_per_all_physics_steps":{key:value/len(rows) if rows and data["timed"] else None for key,value in totals.items()},
            "share_of_observed_complete_solve":{key:value/total if total and data["timed"] else None for key,value in totals.items()}}
    return {"analysis_valid":True,"mode":data["mode"],"all_measurement":summary(selected),
        "first_up_to_600_steps":summary(selected[:600]),"first600_complete":len(selected)>=600,
        "same_clock_m1_frame_links_verified":True,"normal_fps_available":False,"acceptance_eligible":False,
        "performance_claim":False,"next_action":"stop after timed/clockless preflight; root reviews overhead and profile_cells budget before any longer run or optimization"}
