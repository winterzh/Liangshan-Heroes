from pathlib import Path
import hashlib,json,re,subprocess
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;P=E/'candidate'
assert not P.exists() or not any(P.iterdir())
P.mkdir(exist_ok=True);records=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(name):return (R/name).read_text(encoding='utf-8')
def save(name,text):
 p=P/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8',newline='\n')
 records.append({'path':name,'before_sha256':sha(R/name) if (R/name).exists() else None,'candidate_sha256':sha(p)})
def replace(text,old,new):assert text.count(old)==1,(old[:90],text.count(old));return text.replace(old,new)
def function(text,name,new):
 match=re.search(r'^func '+re.escape(name)+r'\(',text,re.M)
 if not match:return text.rstrip()+'\n\n'+new.rstrip()+'\n'
 after=re.search(r'^(?:func |class )',text[match.start()+1:],re.M)
 end=match.start()+1+after.start() if after else len(text)
 return text[:match.start()]+new.rstrip()+'\n\n'+text[end:]
name='scripts/levels/level1_huangnigang.gd';base=read(name)
base=replace(base,'for i in range(3):\n\t\tvar bundle: Unit = b.spawn_at','for i in range(_tribute_load_count()):\n\t\tvar bundle: Unit = b.spawn_at')
label_line=re.search(r'^\t\tbundle\.display_name = .+$',base,re.M).group(0)
old_label_expression=label_line.split('=',1)[1].strip().replace('[i]','[index]')
base=replace(base,label_line,'\t\tbundle.display_name = _tribute_load_name(i)')
base+='\n\nfunc _tribute_load_count() -> int: return 3\nfunc _tribute_load_name(index: int) -> String: return '+old_label_expression+'\n'
save(name,base)
name='scripts/levels/level1_huangnigang_short.gd';short=read(name)
short=replace(short,'const WU_STATION :=','const Transport=preload("res://scripts/huangnigang_transport.gd")\nconst LOAD_REST_CELLS: Array[Vector2i]=[Vector2i(25,18),Vector2i(27,18),Vector2i(29,18),Vector2i(31,18),Vector2i(25,20),Vector2i(27,20),Vector2i(29,20),Vector2i(25,19),Vector2i(27,17),Vector2i(29,17),Vector2i(31,17)]\nconst CART_EXIT_CELLS: Array[Vector2i]=[Vector2i(5,16),Vector2i(7,17),Vector2i(5,19),Vector2i(7,20),Vector2i(5,22),Vector2i(7,23),Vector2i(5,25)]\nconst WU_STATION :=')
short=replace(short,'func story_contract_version() -> int: return 2','func story_contract_version() -> int: return 3')
methods=(E/'short_transport_methods.gd.txt').read_text(encoding='utf-8')
starts=list(re.finditer(r'^func (\w+)\(',methods,re.M))
for index,match in enumerate(starts):
 end=starts[index+1].start() if index+1<len(starts) else len(methods)
 short=function(short,match.group(1),methods[match.start():end])
# Keep the existing force response and actor/convoy behavior; replace only cargo
# registration/count prose, not the noncanonical branch's combat decisions.
parent=read('scripts/levels/level1_huangnigang.gd');m=re.search(r'^func _begin_force_route\(',parent,re.M);after=re.search(r'^func ',parent[m.start()+1:],re.M);force=parent[m.start():m.start()+1+after.start()]
force=replace(force,'可由任一活着的七星或白胜到担旁挑走三担；搬运者倒下时纲担会原地落下，可换人接力。','七星按车旁标记将十一担财物装入七辆江州车。原负责者倒下时，幸存七星可接力推车；白胜仍为同行卖酒人。')
force=replace(force,'for i in range(3):','for i in range(Transport.CART_COUNT):');short=function(short,'_begin_force_route',force)
short=replace(short,'if st==WITHDRAW and delivered==3:','if st==WITHDRAW and delivered==Transport.LOAD_COUNT:')
short=short.replace('后续酒计和三担搬运仍由你分人配合。','后续酒计、弃枣装车与七车十一担的撤出仍由你分人配合。')
short=short.replace('本关将原著十一担财物合为三担搬运。','十一担财物保留各自编号，七星将弃枣后用原来的七辆江州车装运。')
short=short.replace('药入酒桶之后，分人挑担，莫再生枝节。','药入酒桶之后，弃枣装车，遮盖了推走，莫再生枝节。')
short=short.replace('倒下；幸存者仍可接力搬担。','倒下；幸存七星仍可接力推车。').replace('所有同伴倒下，无人能够带走纲担。','七星全部倒下，无人能够推出剩余江州车。')
short=replace(short,'func process(b, delta: float) -> void:\n','func process(b, delta: float) -> void:\n\tfor index in range(jujube_carts.size()):\n\t\tif is_instance_valid(jujube_carts[index]):jujube_carts[index].visible=not bool(cargo_ready.get(index,false))\n')
short=short.replace('只选中未挑担的同伴；搬运仍由你右键下令。','只选中未推车的同伴；按车旁七星姓名分别下令。')
save(name,short)
name='scripts/run_campaign_level_state.gd';text=read(name)
text=replace(text,'const SCHEMA :=','const Transport=preload("res://scripts/huangnigang_transport.gd")\nconst SCHEMA :=')
text=replace(text,'"level1": {"bundles": 3}','"level1": {"bundles": Transport.LOAD_COUNT}')
text=replace(text,'else key < 0 or key > 2','else key < 0 or key >= Transport.CART_COUNT')
text=replace(text,'key < 0 or key > 2: return _bad("CARGO_INDEX")','key < 0 or key >= Transport.CART_COUNT: return _bad("CARGO_INDEX")')
text=replace(text,'if level_id == "level1" and (values.delivered < 0 or values.delivered > 3): return false','if level_id == "level1" and (values.delivered < 0 or values.delivered > Transport.LOAD_COUNT or not Transport.valid_loaded(values.cargo_ready) or values.cargo_plan not in ["", "free"]): return false')
save(name,text)
name='scripts/run_unit_graph.gd';text=read(name)
text=replace(text,'"level1_unit_graph_v1"','"level1_unit_graph_v2"')
text=replace(text,'"actors": refs.actors if refs.has("actors") else [], "cargo": refs.cargo}','"actors": refs.actors if refs.has("actors") else [], "cargo": refs.cargo,\n\t\t\t"cart_loaded": checked.value.values.cargo_ready, "delivered_loads": checked.value.values.delivered}')
save(name,text)
name='scripts/run_unit_state.gd';text=read(name)
text=replace(text,'const HG_BUNDLE_COUNT := 3','const Transport=preload("res://scripts/huangnigang_transport.gd")\nconst HG_BUNDLE_COUNT := Transport.LOAD_COUNT')
text=replace(text,'"level1_unit_state_v1"','"level1_unit_state_v2"')
text=replace(text,'["cart", "yang", "bundles", "convoy", "actors", "cargo"]','["cart", "yang", "bundles", "convoy", "actors", "cargo", "cart_loaded", "delivered_loads"]')
text=replace(text,'\t\t_huang_roles = roles.duplicate(true)','\t\tif not Transport.valid_loaded(roles.cart_loaded) or typeof(roles.delivered_loads)!=TYPE_INT or roles.delivered_loads<0 or roles.delivered_loads>Transport.LOAD_COUNT: _scope_error="LEVEL1_TRANSPORT_VALUES";return\n\t\t_huang_roles = roles.duplicate(true)')
text=replace(text,'if pending[id].key != "treasure_cart": _scope_error = "LEVEL1_ROLE_ID"; return','if index!=0 or id!=roles.cart or pending[id].key != "treasure_cart": _scope_error = "LEVEL1_ROLE_ID"; return')
old=read(name);a=old.index('func validate_level1_membership(');prefix=old[a:old.index('\tvar carried := {}',a)]
membership=prefix+'''\tvar carried: Dictionary={};var carried_keys: Dictionary={};var delivered: Array=[];var active_loads: Array=[]
\tfor index in _huang_roles.cargo:
\t\tvar carrier: Variant=_huang_roles.cargo[index]
\t\tif not Transport.is_cart(index) or not states.has(carrier) or carrier not in _huang_roles.actors or not active.has(carrier):return _failure("LEVEL1_CARRIER_REFERENCE")
\t\tvar actor: Dictionary=states[carrier]
\t\tif typeof(actor.metadata.get("carrying_tribute"))!=TYPE_INT or actor.metadata.carrying_tribute!=index or actor.values.hp<=0 or actor.values._dying or actor.values.story_outcome!="":return _failure("LEVEL1_CARRIER_STATE")
\t\tcarried[index]=carrier;carried_keys[index]=actor.values.key
\t\tif actor.values.key!=Transport.owner(index):
\t\t\tfor owner_id in _huang_roles.actors:
\t\t\t\tif states.has(owner_id) and states[owner_id].values.key==Transport.owner(index) and states[owner_id].values.hp>0 and not states[owner_id].values._dying and states[owner_id].values.story_outcome=="":return _failure("LEVEL1_CART_OWNER")
\tfor index in range(HG_BUNDLE_COUNT):
\t\tvar id: Variant=_huang_roles.bundles[index]
\t\tif not states.has(id):return _failure("LEVEL1_LOAD_REFERENCE")
\t\tif active.has(id):active_loads.append(index)
\t\tif index<Transport.CART_COUNT and _huang_roles.cart_loaded.has(index) and states[id].values.faction==0:delivered.append(index)
\t\telif states[id].values.faction!=1:return _failure("LEVEL1_LOAD_FACTION")
\tvar expected: Dictionary=Transport.ledger(_huang_roles.cart_loaded,carried_keys,delivered,true)
\tif not expected.ok or expected.delivered_loads!=_huang_roles.delivered_loads:return _failure("LEVEL1_TRANSPORT_LEDGER")
\tvar checked_membership: Dictionary=Transport.validate_membership(_huang_roles.cart_loaded,carried_keys,delivered,active_loads,expected.empty_carts,true)
\tif not checked_membership.ok:return _failure("LEVEL1_TRANSPORT_MEMBERSHIP")
\tvar stowed: Dictionary={}
\tfor index in expected.stowed_loads:stowed[_huang_roles.bundles[index]]=true
\tfor id: String in states:
\t\tif states[id].metadata.has("carrying_tribute"):
\t\t\tvar index: Variant=states[id].metadata.carrying_tribute
\t\t\tif not Transport.is_cart(index) or _huang_roles.cargo.get(index)!=id:return _failure("LEVEL1_ORPHAN_CARRIER")
\tfor id: String in _chapter_roles:
\t\tvar state: Dictionary=states[id];var value: Dictionary=state.values
\t\tif stowed.has(id):
\t\t\tif active.has(id) or state.node.visible or state.node.activation.mode!=Node.PROCESS_MODE_DISABLED or value.hp<=0 or value._dying:return _failure("LEVEL1_CARRIED_MEMBERSHIP",id)
\t\t\tif typeof(state.metadata.get("tribute_process_mode"))!=TYPE_INT or state.metadata.tribute_process_mode<0 or state.metadata.tribute_process_mode>4:return _failure("LEVEL1_CARRIED_PROCESS_MODE",id)
\t\telif active.has(id)!=(value.hp>0 and not value._dying) or state.metadata.has("tribute_process_mode"):return _failure("LEVEL1_ROLE_ACTIVE_MEMBERSHIP",id)
\treturn {"ok":true,"complete_world":false,"root_and_effect_validation_required":true}
'''
text=function(text,'validate_level1_membership',membership);save(name,text)
name='scripts/run_official_restore_profile.gd';save(name,replace(read(name),'"campaign_level1_v1"','"campaign_level1_v2"'))
name='scripts/run_level1_world_factory.gd';save(name,read(name).replace('three named bundle refs','eleven distinct load refs and seven cart groups'))
name='scripts/huangnigang_transport.gd';save(name,read(name))
patch=[]
for record in records:
 name=record['path'];old=read(name);new=(P/name).read_text(encoding='utf-8')
 import difflib
 patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
(E/'integration_candidate.patch').write_text(''.join(patch),encoding='utf-8')
(E/'integration_candidate.json').write_text(json.dumps({'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),'files':records,'applied':False,'actual_level_tested':False,'full_save_chain_tested':False,'breaking_profile_boundary':'New HG/unit graph/unit component profile IDs. Old three-target slots are not silently mapped to guessed eleven-load progress; retain old files and validate rejection before player entry.','required_next':['native compile of exact candidate','real11-load deployment and7-cart visibility conservation','seven owners/weighted delivery/duplicate rejection/drop-and-relay','new snapshot capture/restore and malformed graph negatives','old3-target/profile rejection without overwrite','four-language actualUI and source/current179 native preservation','fresh real exported PCK identity and scoped sync']},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'candidate_files':len(records),'applied':False,'actual_level_tested':False}))
