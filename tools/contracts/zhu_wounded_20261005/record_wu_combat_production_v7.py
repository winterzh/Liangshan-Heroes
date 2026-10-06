"""Retain actual default-route proof and scoped production appearance registry."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
pilot=Path(read(BASE/'ordinary_chapter_combat_v7_run.json')['run']);run=Path(read(BASE/'ordinary_chapter_combat_production_v7_run.json')['run'])
p=read(pilot/'receipt.json');r=read(run/'receipt.json')
assert p['complete'] and p['lock_released'] and p['result']['passed'] and p['result']['checks']==343
assert r['complete'] and r['lock_released'] and r['covered_default_routes_verified'] and r['private_runtime_patches']==0 and r['result']['checks']==367 and r['result']['passed']
assert not r['source_changes'] and not r['private_source_changes'] and r['candidate_input_drift']==0 and r['result']['engine_time_scale']==1.0 and len(r['result']['screenshots'])==48
for row in r['source_files']+r['candidate_inputs']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
shutil.copy2(pilot/'receipt.json',QA/'ordinary_chapter_combat_pilot_v7.json')
shutil.copy2(run/'receipt.json',QA/'ordinary_chapter_combat_production_v7.json')
boot=Path(read(BASE/'texture_bootstrap_wu_song_combat_v7_run.json')['run']);texture=read(boot/'receipt.json');assert texture['complete']
shutil.copy2(boot/'receipt.json',QA/'wu_combat_native_texture_v7.json')
viewed=['wu_song_se_idle','wu_song_se_windup','wu_song_se_attack','wu_song_se_attack_late','wu_song_se_hurt','wu_song_nw_attack','wu_song_nw_hurt','wu_song_ne_attack','wu_song_sw_hurt','lin_chong_se_idle','lin_chong_se_attack','lin_chong_nw_walk']
frames=QA/'ordinary_combat_production_review_frames_v7';frames.mkdir(exist_ok=True);images=[]
for name in viewed:
 src=run/'evidence'/(name+'.png');dest=frames/src.name;shutil.copy2(src,dest);assert sha(src)==sha(dest)
 images.append({'name':name,'path':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest),'native_bytes_unchanged':True})
routes={'wu_song':{'idle':'character_traits_v5_wu_song_gait','walk':'character_traits_v5_wu_song_gait','attack':'character_traits_v7_wu_song_combat','hurt':'character_traits_v7_wu_song_combat'},
 'lin_chong':{'idle':'character_traits_v5_lin_chong_gait','walk':'character_traits_v5_lin_chong_gait'}}
manifests=['assets/direction4/ordinary_wu_song_20261006_gait_v5.json','assets/direction4/ordinary_lin_chong_20261006_gait_v5.json','assets/direction4/ordinary_wu_song_20261007_combat_v7.json']
resources=[{'path':name,'sha256':sha(ROOT/name)} for path in manifests for name in read(ROOT/path)['resources']]
write(QA/'ordinary_character_default_routes_v7.json',{'current_default_routes_verified':True,'routes':routes,'resources':resources,
 'source_manifests':[{'path':path,'sha256':sha(ROOT/path),'status_note':'Immutable authoring candidate metadata retained; this scoped registry records actual current default adoption.'} for path in manifests],
 'production_scripts':[{'path':name,'sha256':sha(ROOT/name)} for name in ['scripts/art_db.gd','scripts/unit.gd']],
 'evidence':'qa/zhu_wounded_20261005/ordinary_chapter_combat_production_v7.json','evidence_sha256':sha(QA/'ordinary_chapter_combat_production_v7.json'),
 'scope':'Ordinary empty-variant Wu/Lin idle/walk and Wu attack/hurt default routing only; explicit story variants retain their own art. Existing unlisted actions remain. Not complete-character, continuous gait, all-chapter/save/performance/platform qualification.'})
write(QA/'ordinary_combat_production_visual_review_v7.json',{'covered_default_routes_verified':True,'pilot_checks':343,'production_checks':367,'captures_each':48,'normal_clock':1.0,'source_inputs':4904,'candidate_inputs':105,
 'root_and_private_input_drift':0,'private_production_patches':0,'viewed':images,
 'findings':['Wu SE/NW ordinary idle is upright with adult proportions; attack allows natural hip/knee movement.',
 'Wu actual NE/NW attack now uses separately authored rear frames, with both sabres belonging to the same character family.',
 'Northwest strike supporting-leg correction retains two visible boots inside the source cell; actual sampled attack/hurt and recovery keep the body identity.',
 'Lin sampled default idle/walk stays upright and existing spear attack remains directional; standard portraits, selected UI and real health/skill definitions remain.',
 'Sampled pose/static and actual command transitions accepted for these default states. Continuous cloth/foot/weapon review, skills/cast/death/fullUI and the full development audit remain open.'],
 'scope':r['scope'],'full_goal_qualified':False,'continuous_gait_qualified':False})
print(json.dumps({'pilot_checks':343,'production_checks':367,'captures_each':48,'native_import_checks':len(texture['dimensions']['checks']),'default_resources':len(resources),'review_frames':len(images),'private_runtime_patches':0}))
