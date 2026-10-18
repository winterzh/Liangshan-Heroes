import collections,hashlib,json,pathlib,shutil
R=pathlib.Path('D:/AI项目/水浒/开发工程');B=pathlib.Path(__file__).parent;E=B/'iteration2';Q=R/'qa/ruan_xiaoqi_walk_grips_20261018'
G=E/'native/20261018_091212_6201aed6/evidence';O=pathlib.Path('D:/CodexEvidence/shuihu/ruan_xiaoqi_grip_20261018/native/20261018_071222_eae3155d/evidence')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
def cp(a,b):b.parent.mkdir(parents=True,exist_ok=True);assert not b.exists();shutil.copyfile(a,b)
r=load(G/'receipt.json');report=load(G/'visual/report.json');assert r['complete'] and r['lock_released'] and report['passed'] and not report['failures'];assert r['checks']==len(report['checks'])==1576 and r['screenshots']==len(report['screenshots'])==118
assert not r['source_changes'] and not r['private_source_changes'] and not r['source_owner_changes']
for row in r['pack_chain']:assert sha(row['path'])==row['sha256']
P=pathlib.Path(load(E/'prepared_pointer.json')['receipt']).parent;resource=load(P/'receipt.json');rr=load(P/'report.json');assert resource['state']=='complete' and resource['checks']==126 and resource['lock_released']
for row in resource['frozen']:assert sha(P/row['path'])==row['sha256']
for name in ['receipt.json','report.json','import.log','native.log']+rr['screenshots']:cp(P/name,Q/'resource_native/iteration2'/name)
save(Q/'resource_native/iteration2/direct_review.json',{'directly_seen':rr['screenshots'],'scope':'All four original native static comparison PNGs directly seen. Front B now retains its opposite support/trailing-leg contact rather than repeating A; no idle substituted. Prior6 body poses and fixed4cart retained. Exact fingers, head/sole-root and fully natural gait remain unaccepted.','resource_checks':126,'runtime_adopted_after_fresh_game_pass':True})
for p in sorted(G.iterdir()):
 if p.is_file() and p.suffix in ['.log','.json']:cp(p,Q/'game_native'/p.name)
cp(G/'visual/report.json',Q/'game_native/report.json')
direct=[f'cart_1280_push_walk_{d}_{i}.png' for d in ['se','sw','ne','nw'] for i in ([0,1,2,3] if d in ['se','sw'] else [1,2,3])]
direct += ['actual_push_walk_'+d+'.png' for d in ['se','sw','ne','nw']]
direct += ['parked_hurt_se.png','parked_attack_sw.png','parked_hurt_ne.png','parked_attack_nw.png','original_pickup.png','original_delivery_unloaded.png','original_defeat_drop.png']
direct += ['default_push_walk_'+d+'_2.png' for d in ['se','sw','ne','nw']]
direct += ['cart_960_push_walk_se_2.png','cart_1920_push_walk_sw_2.png','medium_passing_b_nw.png'];assert len(direct)==len(set(direct))==32
index=[]
for row in report['screenshots']:
 p=G/'visual'/row['path'];assert sha(p)==row['sha256'];index.append(dict(row,original_path=str(p),directly_seen=row['path'] in direct))
assert set(direct)<=set(x['path'] for x in index)
save(Q/'game_native/screenshots.json',index)
save(Q/'game_native/direct_review.json',{'reviewer':'primary agent, direct visual inspection','directly_seen_screenshots':direct,'count':32,'all_118_seen':False,'findings':['All fourteen changed walking poses directly checked in actual packed game at1280. Contact B front support/trailing leg differs from A; rear spare fist removed by occlusion.','Four actual directional movements, four parked hurt/attack representatives, original pickup/delivery/drop, default-camera B all four directions and960/1920/medium representatives viewed.','Fine finger/handle gaps and phase-to-phase head/feet/root displacement remain. Full anatomical gait not accepted.','Old oversized yellow selection ellipse still crosses head/body; damage/bar/name overlays and pickup/drop crowding remain. At960, high-zoom lower cart can overlap HUD.','Old three-goal and shoulder-carry/mixed texts remain; seven carts/eleven burdens and complete wine sequence not qualified. Generic QA defeat/drop is not a new canonical death outcome.','Screenshot FPS varies during capture and is not a performance acceptance result.'],'complete_art_accepted':False})
for name in ['cart_1280_push_walk_se_2.png','cart_1280_push_walk_sw_2.png','cart_1280_push_walk_ne_1.png','cart_1280_push_walk_nw_3.png','actual_push_walk_sw.png','original_delivery_unloaded.png']:cp(G/'visual'/name,Q/'screenshots'/name)
old_ref=load(O/'texture_references.json');new_ref=load(G/'texture_references.json');common=set(old_ref)&set(new_ref);assert len(common)==170 and all(old_ref[k]==new_ref[k] for k in common)
m=load(R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json');pairs=[]
for row in m['sources'].values():
 if row['candidate_origin'].startswith('assets/characters/ruan_xiaoqi_walk_grips_20261018/'):
  assert new_ref[row['path']]==rr['texture_references'][row['candidate_origin']];pairs.append({'source':row['candidate_origin'],'runtime':row['path'],'native_reference':new_ref[row['path']]})
assert len(pairs)==6
ca=collections.Counter(x['name'] for x in load(O/'visual/report.json')['checks']);cb=collections.Counter(x['name'] for x in report['checks']);removed=ca-cb;added=cb-ca;prefixes={'PNG absent in mounted base+patch PCK','PCK texture loads','native pixels and mipmaps exact','native texture dimensions'}
assert len(removed)==40 and len(added)==24 and all(x.split(' assets/')[0] in prefixes for x in list(removed)+list(added))
save(Q/'native_texture_continuity.json',{'old_references':180,'new_references':176,'retained_native_references_exact':170,'retained_differences':[],'new_source_runtime_pairs_exact':pairs,'checks_old':1592,'checks_new':1576,'removed_texture_checks':dict(removed),'added_texture_checks':dict(added),'nontexture_check_multiset_unchanged':True,'reason':'Ten superseded active body atlases removed from reference set, six replacements added; each texture has four native/PCK checks. No pose/gameplay checks removed and validator source unchanged.'})
before=load(E/'before_adoption/assets/direction4/level1_ruan_xiaoqi_layered_20261018.json');changed={x['pose'] for x in load(E/'candidate_changes.json')};assert len(changed)==14
for name,v in before['poses'].items():
 if name not in changed:assert m['poses'][name]==v,name
assert before['canonical_cart_geometry']==m['canonical_cart_geometry']
for p in (E/'before_adoption').rglob('*'):
 if p.is_file():cp(p,Q/'adoption/before'/p.relative_to(E/'before_adoption'))
cp(E/'applied_walk_grips.json',Q/'adoption/applied_walk_grips.json')
for p in (E/'prepared_integration_archive').rglob('*'):
 if p.is_file():cp(p,Q/'adoption/prepared_archive'/p.relative_to(E/'prepared_integration_archive'))
baseline=load(R/'qa/ruan_xiaoqi_grip_20261018/runtime_inventory.json');expected={'assets/characters/ruan_xiaoqi_layer_fixes_20261018/prompt_set.json','assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'}|set(load(E/'applied_walk_grips.json')['changed_resources']);diff=[x['path'] for x in baseline if sha(R/x['path'])!=x['sha256']];assert set(diff)==expected
pres=[]
for n in ['preservation/protected_preflight.json','preservation/unrelated_before.json']:
 rows=load(R/'qa/ruan_xiaoqi_grip_20261018'/n)
 for row in rows:assert sha(R/row['path'])==row['sha256'],row['path']
 cp(R/'qa/ruan_xiaoqi_grip_20261018'/n,Q/n);pres.append({'inventory':n,'unchanged':len(rows),'differences':[]})
save(Q/'adoption/preservation_after.json',{'old_inventory_files':25,'intentionally_changed_files':diff,'unchanged_old_inventory_files':19,'new_runtime_files':load(E/'applied_walk_grips.json')['new_runtime_files'],'other_inventories':pres,'unchanged_poses':10,'fixed_cart_geometry_equal':True,'gameplay_scripts_and_validators_unchanged':True})
names={x['path'] for x in baseline}|set(m['resources'])|{p.relative_to(R).as_posix() for p in (R/'assets/characters/ruan_xiaoqi_layered_20261018').iterdir() if p.is_file()}|{p for row in m['sources'].values() for p in [row['path'],row['path']+'.import']}
save(Q/'runtime_inventory.json',[{'path':n,'sha256':sha(R/n)} for n in sorted(names)])
save(Q/'adoption/current_adoption.json',{'runtime_adopted':True,'changed_poses':sorted(changed),'retained_body_poses':6,'retained_cart_poses':4,'source_pngs_selected':6,'source_document':'assets/characters/ruan_xiaoqi_walk_grips_20261018/prompt_set.json','source_document_sha256':sha(R/'assets/characters/ruan_xiaoqi_walk_grips_20261018/prompt_set.json'),'manifest_sha256':sha(R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'),'real_game_receipt':str(G/'receipt.json'),'real_game_receipt_sha256':sha(G/'receipt.json'),'checks':1576,'screenshots':118,'directly_seen':32,'frozen_sources':len(r['source_files']),'canonical_files':r['generated_identity']['identity']['file_count'],'identity_source_sha256':r['generated_identity']['identity']['source_sha256'],'pack_chain_count':len(r['pack_chain']),'new_patch_bytes':r['pack_bytes'],'new_patch_sha256':r['pack_sha256'],'complete_gait_accepted':False,'all_art_complete':False,'wheel_component_runtime_adopted':False})
cp(Q/'native_gate.json',Q/'historical_gate_before_adoption.json')
save(Q/'native_gate.json',{'state':'complete_runtime_adopted','resource_receipt':str(P/'receipt.json'),'resource_checks':126,'runtime_adopted':True,'actual_game_receipt':str(G/'receipt.json'),'actual_game_checks':1576,'actual_game_screenshots':118,'directly_seen':32,'full_art_complete':False,'complete_gait_accepted':False,'resume_warning':'Both resource batches are now complete and must never be rerun with run-existing. A new game run needs a new outside work directory, this current complete receipt and a retained source commit, serial lane and prior-input archive. Do not apply any old candidate again.','unadopted_art_in_identity':'Isolated wheel body/rim/spoke source files are frozen canonical inputs too; their presence in the game identity does not qualify their unadopted animation.'})
print(json.dumps({'actual_game_checks':1576,'screenshots':118,'directly_seen':32,'frozen':len(r['source_files']),'canonical':r['generated_identity']['identity']['file_count'],'runtime_inventory':len(names),'retained_native_textures':170,'new_native_pairs':6,'changed_poses':14,'unchanged':10,'protected':pres[0]['unchanged'],'unrelated':pres[1]['unchanged']}))
