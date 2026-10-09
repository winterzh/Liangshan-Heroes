"""Keep v15a mechanics, reject stale atmosphere capture geometry and prepare sibling."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';H=QA/'harness'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_continuous_gait_v15a_b3766d7b'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    rp=RUN/'receipt.json';r=read(rp)
    assert r['complete'] and r['lock_released'] and r['root_input_drift']==r['private_input_drift']==0
    assert r['private_runtime_patches']==0 and r['result']['checks']==301 and r['result']['passed'] and len(r['result']['screenshots'])==70
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    p=QA/'ordinary_continuous_gait_mechanical_v15a.json';assert not p.exists();shutil.copy2(rp,p);assert sha(p)==sha(rp)
    directory=QA/'ordinary_continuous_gait_rejected_v15a_frames';directory.mkdir(exist_ok=False);views=[]
    for name in ['wu_song_idle_1440x960','wu_song_idle_1920x1080']:
        row=next(x for x in r['result']['screenshots'] if x['name']==name);src=Path(row['path']);assert sha(src)==row['sha256']
        dst=directory/src.name;shutil.copy2(src,dst);views.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    review={'passed':False,'mechanical_passed':True,'checks':301,'captures':70,'receipt_sha256':sha(rp),'viewed_rejection':views,
        'findings':['All eight continuous cases: actual subject physics kept enabled, original stats/portrait, four correct directional gait resources and eight samples with normal movement.',
            'Directly viewed all first four continuous frames for each actor/direction and six desktop idle sizes. Wu resized idle views show a partial rectangular atmosphere tint boundary, so overall visual/UI qualification is rejected.',
            'Sampler calls center_camera_cell/force_update_scroll after atmosphere process. Existing production _refresh_run_capture_presentation refreshes derived atmosphere geometry at snapshot boundaries; sibling will use that helper without stopping subject physics or changing production scripts.'],
        'scope':'Mechanical continuous sampling qualified only. Complete seamless visual/UI proof remains open until geometry-correct capture. No long performance or device qualification.'}
    p=QA/'ordinary_continuous_gait_visual_review_v15a.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    src=H/'ordinary_continuous_gait_v15a.gd';text=src.read_text(encoding='utf-8')
    old='\tb.center_camera_cell(b.map.world_to_cell(u.position));u.queue_redraw()'
    assert text.count(old)==1
    new='''\tb.center_camera_cell(b.map.world_to_cell(u.position));u.queue_redraw()
\t# The manual QA camera jump occurs after the last atmosphere callback.
\t# Refresh only derived presentation geometry using the existing production helper.
\tb._refresh_run_capture_presentation()
\tvar atmosphere_proof: Array=[]
\tfor layer in b.get_children():
\t\tif not layer.has_method("_fit_viewport") or not layer.has_method("set_phase"):continue
\t\tvar screen_transform: Transform2D=layer.screen.get_global_transform_with_canvas()
\t\tcheck(screen_transform.is_equal_approx(Transform2D.IDENTITY),"atmosphere covers viewport origin "+label)
\t\tcheck(layer.rect.size==root.get_visible_rect().size,"atmosphere covers full resized viewport "+label)
\t\tatmosphere_proof.append({"transform":str(screen_transform),"rect_size":str(layer.rect.size),"subject_physics_enabled":u.is_physics_processing()})'''
    text=text.replace(old,new).replace('"subject_paused":false,"scope":"Normal rendered motion between two observations;',
        '"subject_paused":false,"derived_presentation_refreshed":true,"atmosphere":atmosphere_proof,"scope":"Normal rendered motion between two observations;')
    text=text.replace('ordinary_continuous_gait_v15a','ordinary_continuous_gait_v15b')
    p=H/'ordinary_continuous_gait_v15b.gd';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    text=(H/'run_ordinary_continuous_gait_v15a.py').read_text(encoding='utf-8').replace('ordinary_continuous_gait_v15a','ordinary_continuous_gait_v15b')
    p=H/'run_ordinary_continuous_gait_v15b.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'mechanical_checks':301,'captures':70,'overall_visual_passed':False,'v15b_prepared':True,'production_changed':False}))
if __name__=='__main__':main()
