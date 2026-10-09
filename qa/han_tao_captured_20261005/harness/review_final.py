from pathlib import Path
import json,hashlib
base=Path(__file__).parent
run=Path(json.loads((base/'final_run.json').read_text(encoding='utf-8'))['run'])
receipt=json.loads((run/'evidence/receipt.json').read_text(encoding='utf-8'))
report=json.loads((run/'evidence/han_tao/report.json').read_text(encoding='utf-8'))
assert receipt['complete'] and report['passed'] and report['checks']==105
notes={
 'han_opening':'Directly reviewed: original living Han in chapter is visible; old blue mounted body retained pending full normal-state batch. Not evidence of completed normal art.',
 'han_captured_se':'Directly reviewed: living red-armored kneeling captive, front wrists bound, no horse/weapon/blood. Cursor partially covers hands; body matrix supplies unobstructed hand review.',
 'han_captured_sw':'Directly reviewed: distinct facing, front bound hands, whole kneeling body visible and stable ground contact.',
 'han_captured_ne':'Directly reviewed: rear-right facing, red cape and helmet/shoulder identity visible, hands naturally hidden by body; no mirrored front view.',
 'han_captured_nw':'Directly reviewed: distinct rear-left facing, cape and bent lower legs visible, stable ground contact.',
 'han_capture_persistent':'Directly reviewed: same original captive remains visible beyond corpse lifetime, no fade or death squash.',
 'hu_retreated':'Directly reviewed: original Hu is absent after explicit retreat fixture, chapter retreat message visible; no natural victory/retreat-threshold claim.',
 'han_captured_matrix':'Directly reviewed: normal/2x display fixtures show all four independently sampled poses without UI/body overlap; consistent body heights/contact, front wrists tied, no horse or weapon.'
}
rows=[]
for row in report['screenshots']:
 p=Path(row['path']); assert p.resolve().is_relative_to((run/'evidence/han_tao').resolve())
 digest=hashlib.sha256(p.read_bytes()).hexdigest(); assert digest==row['sha256']
 assert row['name'] in notes
 rows.append({'name':row['name'],'path':'final/han_tao/'+p.name,'sha256':digest,'passed':True,'review_method':'direct native screenshot inspection','notes':notes[row['name']]})
assert len(rows)==len(notes)
review={'complete':True,'passed':True,'screenshots':rows,'production_source':'assets/characters/han_tao_captured_20261005/captured.png','native_source_review':'Directly reviewed unchanged 1254x1254 RGBA, four independent front/rear kneeling views, identity matches portraits4 top middle; no weapon/horse/blood, genuine alpha.','scope':'Captured appearance and local normal-damage story-state boundary only.','limitations':['Four facings are explicit display fixtures on the original captured actor; fog-disabled fixture sets initial foe visibility.','Original Xu normal attacks original full-HP Han; contact positioning, frozen nonparticipants/defender and normal level-one Q learning are explicit fixtures.','Adjacent actors have name/status text overlap at contact distance; bodies remain visible. This does not qualify whole-project label spacing or UI.','SE cursor obscures some hand detail; unobstructed native body matrix reviewed separately.','Normal mounted five-state identity remains unfinished; opening shows old blue costume.','Hu retreat is explicit resolve_story on original actor, not natural full-chapter victory.','No campaign continuation, long performance soak, fresh no-cache qualification, device/platform or published package claim; screenshot FPS is not a measurement.'],'failed_iteration':'review_iterations/continuation_20261005_070145_14bd79ed preserves invisible-actor failure; final fixture fixes visibility without production vision edits.'}
(base/'visual_review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print('VISUAL_REVIEW_COMPLETE: 8 directly inspected native screenshots')
