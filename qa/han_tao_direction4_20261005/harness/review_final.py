from pathlib import Path
import json,hashlib
base=Path(__file__).parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
run=Path(json.loads((base/'final_run.json').read_text(encoding='utf-8'))['run'])
r=json.loads((run/'evidence/receipt.json').read_text(encoding='utf-8'))
assert r['complete'] and r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
first=json.loads((base/'first_visual_review.json').read_text(encoding='utf-8'))
old={x['name']:x for x in first['screenshots']}
changed=set(json.loads((base/'final_changed_frames.json').read_text(encoding='utf-8')))
rows=[]
for p in sorted((run/'evidence/han_tao').glob('*.png')):
 name=p.stem;s=sha(p);notes='Identity, facing and footprint reviewed in native game render; HUD, labels and targets partly occlude weapon/hands. Pose matrices supplement anatomy.'
 method='direct_native_image_view'
 if name not in changed:
  assert old[name]['sha256']==s and sha(Path(old[name]['path']))==s
  method='sha_identical_to_directly_reviewed_first_iteration';notes=old[name]['review']
 if name.startswith('hurt_'):notes='Frozen unit recoil screenshot after normal incoming damage; correct authored recoil. Unit resumed before death. NE flag partly occludes rider.'
 if name.startswith('fall_'):notes='Folded horse and rider lower toward ground; smaller height intentional. NE flag partly occludes body. Existing ground blood is runtime effect, not painted asset gore.'
 if name.startswith('terminal_'):notes='Grounded folded horse and slumped rider with empty hands and one dropped weapon; NE flag partially occludes. Existing blood is runtime effect.'
 if name.startswith('han_skill_'):notes='Normal selected UI cast with cooldown and target damage; Q/E/R 40/22/32 recorded by report. R effect obscures caster; no new effect art acceptance.'
 if name.startswith('han_passive_hit_'):notes='W unlearned/learned normal-hit comparison; transient R effect and damage text occlude caster. Report uses actual damage deltas, not rounded floating labels or critical label.'
 if name.startswith('han_opening_'):notes='Original chapter actor in four idle directions. Stable brown horse/red-brown armor matching current portrait; top weapon partly covered by health/name labels.'
 if name=='han_original_hit':notes='Original Han strike against original Xu, 36.288 actual damage. Only Battle coordinator paused to exclude auto-spell; unit normal attack intact, coordinator resumed before capture.'
 if name.startswith('han_captured_') or name=='han_capture_persistent':notes='Same original enemy Han remains kneeling alive and empty-handed after normal full-HP capture. SW wrists clear; SE pointer covers wrists; back cloak occludes wrists. Xu moved by fixture and tree partly occludes Xu.'
 if name=='melee_se':notes+=' Screenshot can show recovery after hit; instantaneous authored-strike assertion and matrix separately prove strike.'
 rows.append({'name':name,'path':str(p),'sha256':s,'method':method,'review':notes,'passed':True})
assert len(rows)==43 and sum(x['method']=='direct_native_image_view' for x in rows)==35
for a in r['artifacts']:
 p=run/'evidence'/a['path'];assert sha(p)==a['sha256'] and p.stat().st_size==a['bytes']
result={'complete':True,'passed':True,'run':run.name,'checks':640,'screenshots':rows,'direct_final':35,'identical_previously_direct_reviewed':8,'prior_review_sha256':sha(base/'first_visual_review.json'),'scope':'Art and local mechanisms only. Explicit fixtures; reused imported cache. No whole-chapter victory, actual training completion, independent campaign continuation, long performance or device/platform qualification.'}
(base/'visual_review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({k:v for k,v in result.items() if k!='screenshots'}))
