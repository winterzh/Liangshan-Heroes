"""Freeze a fresh full source with exactly two candidate routing changes."""
from pathlib import Path
import datetime,hashlib,importlib.util,json,shutil,sys,uuid
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
shared,running=common.load_helpers(R)
spec=importlib.util.spec_from_file_location('wu_gait_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not E.exists();E.mkdir(parents=True)
art=(R/'scripts/campaign_art.gd').read_bytes()
needle=b'\tif key == "chao_gai": return "res://assets/anim/chao_gai_layered_20261018_%s_%s.tres" % [state, direction]'
assert art.count(needle)==1
ending=b'\r\n' if b'\r\n' in art else b'\n'
art=art.replace(needle,needle+ending+b'\tif key == "wu_yong": return "res://assets/anim/wu_yong_layered_20261018_%s_%s.tres" % [state, direction]')
unit=(R/'scripts/unit.gd').read_bytes();needle=b'key not in ["ruan_xiaoqi", "chao_gai"]';assert unit.count(needle)==1
unit=unit.replace(needle,b'key not in ["ruan_xiaoqi", "chao_gai", "wu_yong"]')
unit=unit.replace(b'Only the exact opt-in Ruan7 or Chao actor atlas',b'Only the exact opt-in Ruan7, Chao or Wu actor atlas')
files=[]
for name,raw in [('scripts/unit.gd',unit),('scripts/campaign_art.gd',art)]:
    p=E/'candidate'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
    (Q/('candidate_'+Path(name).name+'.txt')).write_bytes(raw)
    files.append({'path':name,'before_sha256':sha(R/name),'candidate_sha256':sha(p)})
save(E/'integration_candidate.json',{'applied':False,'files':files});save(Q/'integration_candidate.json',{'applied':False,'files':files})
driver=(R/'qa/chao_gai_hand_contact_20261018/unit_driver.gd.txt').read_text()
driver=driver.replace('chao_gai','wu_yong').replace('Chao','Wu Yong').replace('CHAO_ART','WU_ART')
driver=driver.replace('["liu_tang","wu_yong","gongsun_sheng","ruan_xiaoer","ruan_xiaowu","ruan_xiaoqi"]','["liu_tang","chao_gai","gongsun_sheng","ruan_xiaoer","ruan_xiaowu","ruan_xiaoqi"]')
needle='\tvar old_idle: Array='
addition='''	# Other adopted owners must retain their own exact family and reject Wu frames.
	for owner in ["chao_gai","ruan_xiaoqi"]:
		var other=b.find_unit(owner);check(is_instance_valid(other),"existing owner unit "+owner)
		if not is_instance_valid(other):continue
		var had_meta: bool=other.has_meta("carrying_tribute");var prior_meta=other.get_meta("carrying_tribute",null)
		other.set_meta("carrying_tribute",0)
		for d in ["se","sw","ne","nw"]:
			var own_frames: Array=art.unit_anim_frames(owner,"push_walk",d,"hn_"+owner)
			var wu_frames: Array=art.unit_anim_frames("wu_yong","push_walk",d,"hn_wu_yong")
			check(own_frames.size()==4 and CampaignArt.native_tribute_push_path(owner,"hn_"+owner,"push_walk",d).contains(owner+"_layered_20261018"),"other owner route unchanged "+owner+d)
			check(not own_frames.is_empty() and other._campaign_tribute_layered_frame(own_frames[0]),"other owner accepts own actor "+owner+d)
			check(not wu_frames.is_empty() and not other._campaign_tribute_layered_frame(wu_frames[0]),"other owner rejects Wu actor "+owner+d)
		if had_meta:other.set_meta("carrying_tribute",prior_meta)
		else:other.remove_meta("carrying_tribute")
'''
assert driver.count(needle)==1;driver=driver.replace(needle,addition+needle)
(E/'unit_driver.gd').write_text(driver,encoding='utf-8');(Q/'unit_driver.gd.txt').write_text(driver,encoding='utf-8')
bootstrap='extends SceneTree\nfunc _initialize()->void:\n\tvar runner=load("'+str(E/'unit_driver.gd').replace('\\','/')+'").new()\n\troot.add_child.call_deferred(runner)\n'
(E/'bootstrap.gd').write_text(bootstrap,encoding='utf-8');(Q/'unit_bootstrap.gd.txt').write_text(bootstrap,encoding='utf-8')
manifest=json.loads((R/'assets/direction4/level1_wu_yong_layered_20261018.json').read_text())
preview=json.loads(Path(json.loads((E.parent/'latest.json').read_text())['receipt']).with_name('report.json').read_text())
refs={}
for name,row in manifest['sources'].items():
    found=[v for k,v in preview['texture_references'].items() if k==('original:cart_only' if name=='cart_only' else 'new:'+next(phase for phase,source in json.loads((Q/'candidate_selection.json').read_text())['selected'].items() if source==row['candidate_origin']))]
    assert len(found)==1;refs[row['path']]=found[0]
save(E/'runtime_inputs.json',{'native_refs':refs});save(Q/'runtime_inputs.json',{'native_refs':refs})
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
P=R/'.godot/wu_yong_gait_unit'/stamp/'project';identity.no_links(P);P.mkdir(parents=True)
O=E/'preparation';O.mkdir()
receipt={'prepared':False,'native_executed':False,'project':str(P),'output':str(O),'candidate_files':files,'preparer_sha256':sha(Path(__file__))}
try:
    root=identity.snapshot(R);save(O/'root_before.json',root)
    for name,present in root['directories'].items():
        if present and not name.startswith('@file/'):(P/name).mkdir(parents=True,exist_ok=True)
    for row in root['files']:
        src=R/row['path'];dst=P/row['path'];assert sha(src)==row['sha256'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(dst)==row['sha256']
    for row in files:shutil.copyfile(E/'candidate'/row['path'],P/row['path'])
    receipt['native_provenance']=shared.install_native(P);receipt['seed']=identity.seed(P)
    prepared=identity.snapshot(P);save(O/'before_import.json',prepared)
    assert identity.snapshot(R)==root
    receipt.update(prepared=True,root_unchanged=True,root_source_sha256=root['source_sha256'],copied_root_files=len(root['files']),copied_root_bytes=root['total_bytes'])
except BaseException as error:receipt['error']=repr(error)
finally:save(O/'receipt.json',receipt)
assert receipt['prepared'],receipt
save(E/'prepared_current.json',{'receipt':str(O/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['prepared','project','copied_root_files','error']}))
