"""Record actual nonlethal standing-hurt review before production adoption."""
from pathlib import Path
import hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_hurt_pilot_v13_772dbc1b'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    rp=RUN/'receipt.json';r=read(rp)
    assert r['complete'] and r['lock_released'] and r['candidate_hurt_routes_verified']
    assert r['root_input_drift']==r['private_input_drift_except_declared_patch']==0
    assert r['result']['passed'] and r['result']['checks']==369 and len(r['result']['screenshots'])==48
    for row in r['source_files']+r['candidate_inputs']+r['new_inputs']:assert sha(ROOT/row['path'])==row['sha256']
    event=next(x for x in r['result']['runtime'] if x.get('case')=='real_counter_hit' and x.get('actor')=='lin_chong' and x.get('direction')=='sw')['observation']
    assert event['before_hp']>event['after_hp']>0 and event['frame_directional'] and event['authored_hurt_frames']==1
    assert event['source'].endswith('death_sw2_v10.png') and event['region']=='[P: (0.0, 0.0), S: (627.0, 720.0)]'
    target=QA/'ordinary_hurt_pilot_qualified_v13.json';assert not target.exists();shutil.copy2(rp,target)
    names=['lin_chong_sw_idle','lin_chong_sw_hurt','lin_chong_sw_walk','lin_chong_ne_hurt','lin_chong_nw_hurt','wu_song_sw_hurt']
    directory=QA/'ordinary_hurt_pilot_review_v13_frames';directory.mkdir(exist_ok=False);viewed=[]
    for name in names:
        row=next(x for x in r['result']['screenshots'] if x['name']==name);src=Path(row['path']);assert sha(src)==row['sha256']
        dst=directory/src.name;shutil.copy2(src,dst);assert sha(dst)==row['sha256'];viewed.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    dump(QA/'ordinary_hurt_pilot_visual_review_v13.json',{'passed':True,'hurt_qualified':True,'pilot_receipt':str(rp),'pilot_receipt_sha256':sha(rp),
        'checks':369,'captures':48,'viewed':viewed,'actual_nonlethal_sw_hurt':event,'production_default_adopted':False,
        'findings':['Lin SW idle/hurt/recovered walk directly viewed: left-facing standing recoil, complete spear/boots/adult body, original HUD and portrait retained.',
                    'Actual original enemy counterhit lowers HP while hero remains alive; standing first pose selected, no lying-corpse substitution.',
                    'Other inspected directions and Wu retain previous native appearance. Original stats/skills and unaffected/story route guards passed.'],
        'scope':'Sampled original actor combat/standing-hurt transition qualification only. Contact/freeze/phase/fog/zoom fixtures. Not continuous/multi-size UI, natural full chapter/save/performance/export/platform or full-goal completion.'})
    print(json.dumps({'checks':369,'captures':48,'hurt_qualified':True,'before_hp':event['before_hp'],'after_hp':event['after_hp']}))

if __name__=='__main__':main()
