"""Archive exact native evidence and state its narrow acceptance boundary."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
batches=[('actual_registration',Path('D:/CodexEvidence/shuihu/wu_yong_semantic_hand_registration_20261018')),
         ('actual_idle_v2b',Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2b_20261018')),
         ('actual_idle_v2c',Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2c_20261018'))]
archive=[]
for name,base in batches:
    receipt_path=Path(json.loads((base/'latest.json').read_text())['receipt']);P=receipt_path.parent
    receipt=json.loads(receipt_path.read_text());assert receipt['complete'] and receipt['lock_released'] and not receipt.get('error')
    dest=Q/name;dest.mkdir()
    files=[p for p in sorted(P.iterdir()) if p.is_file() and p.name!='preview.gd.uid']
    for src in files:
        dst=dest/(src.name+'.txt' if src.name.endswith('.gd') else src.name)
        shutil.copyfile(src,dst);assert sha(src)==sha(dst)
        archive.append({'original':str(src),'archive':dst.relative_to(Q).as_posix(),'sha256':sha(dst),'bytes':dst.stat().st_size})
    save(dest/'binding.json',{'original_project':str(P),'original_receipt':str(receipt_path),'actual_native_checks':receipt['native_checks'],'original_source_frozen':receipt['frozen']})
save(Q/'archive_index.json',archive)
review={'native_registration':{'checks':43,'captures':8,'complete':True,'directly_viewed':['compare_se.png','compare_sw.png','compare_ne.png','compare_nw.png'],'not_directly_viewed':['grid_se.png','grid_sw.png','grid_ne.png','grid_nw.png']},
    'idle_edit_v2b':{'checks':19,'captures':4,'complete':True,'directly_viewed':['idle_repair_ne.png','idle_repair_nw.png'],'display_limitation':'Unclipped enlarged panels can overpaint adjacent panels; superseded by v2c. Original outputs retained.'},
    'idle_edit_v2c':{'checks':19,'captures':4,'complete':True,'directly_viewed':['idle_repair_se.png','idle_repair_sw.png','idle_repair_ne.png','idle_repair_nw.png'],'png_and_registration_changes_from_v2b':0},
    'observations':['Old rear-view far hands visibly rest near the lower back rather than reaching forward; one-point zero residual never proved a two-hand grip.','New rear idle hides the far fist and bends the arm forward. Near hand also moved upward in the source, so fixing the near grip translates the torso/feet downward in the composite.','Front new idle is visually close but is not byte-identical to old front cells.','Rear far hands remain occluded; target green crosses are derived from fixed cart coordinates, not measured hidden hands.','All five old phase sources share a fixed directional reference from the adopted unladen merchant. No phase-specific fitting and no local PNG pixel writes.'],
    'physical_two_hand_contact_accepted':False,'whole_gait_accepted':False,'actual_game_unit_tested':False,'compiled_package_tested':False,'production_adopted':False,
    'next':'Validate/correct idle-to-walk torso/feet continuity and rear far-arm reach for all four walking phases; then actual Unit and compiled-package checks before adoption.',
    'preservation':{'current_runtime_manifest':'qa/chao_gai_layered_full_pack_20261018/runtime_after_adoption.json','runtime_files':106,'protected_files':16,'unrelated_untracked_files':81,'hud_unchanged':True},
    'canon':'Chapter16 bare-chested jujube merchants and pu-dao remain the chapter basis. Chapter14 refined fair face/long beard and chapter15 straw sandals support identity. Grey clothes, black cloth, exact push poses are art interpretation. No new weapon, magic, plot or historical injury.'}
save(Q/'visual_review.json',review)
save(Q/'native_gate.json',{'native_registration_executed':True,'native_registration_checks':43,'latest_idle_comparison_checks':19,'latest_idle_comparison_captures':4,'native_import_and_rgba_checks_passed':True,'visual_grip_accepted':False,'whole_animation_accepted':False,'production_adopted':False,'latest':'actual_idle_v2c/receipt.json','review':'visual_review.json','old_preparation_remains_unexecuted':'qa/wu_yong_layered_sources_20261018/native_prepared_binding.json'})
print(json.dumps({'archived_files':len(archive),'archived_bytes':sum(r['bytes'] for r in archive),'production_adopted':False}))
