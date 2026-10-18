"""Freeze source/visual scope and verify production remains unchanged."""
from pathlib import Path
import ast,datetime,hashlib,json,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];W=R/'qa/yang_lin_walk_sources_20261019'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def save(folder,name,data):
    with (folder/name).open('x',encoding='utf-8') as stream:stream.write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
prior=R/'qa/yang_lin_canon_sources_20261019/canon_basis.json'
basis=json.loads(prior.read_text(encoding='utf-8'));book=R/basis['primary_text']
assert sha(book)==basis['primary_text_sha256']
for quote in basis['quotes']:assert quote in book.read_text(encoding='utf-8')
counts={}
for folder in [W,Q]:
    originals=[]
    for metadata in sorted(folder.glob('source_*.json')):
        row=json.loads(metadata.read_text(encoding='utf-8'))
        if not isinstance(row,dict) or 'file' not in row:continue
        path=folder/row['file'];assert sha(path)==row['sha256']==sha(Path(row['generated_original']))
        args=json.loads((folder/row['exact_tool_arguments']).read_text(encoding='utf-8'))
        assert hashlib.sha256(args['prompt'].encode()).hexdigest()==row['prompt_sha256']
        for ref in row['references']:assert sha(Path(ref['path']))==ref['sha256']
        with Image.open(path) as im:
            assert im.mode=='RGBA' and im.size==(1254,1254) and im.getchannel('A').getextrema()==(0,255)
        originals.append(row)
    counts[folder.name]=len(originals)
    save(folder,'prompt_set.json',{'mode':'builtin_imagegen','originals':originals,
         'selected_for_production':[],'production_adopted':False,'native_accepted':False,'full_goal_complete':False})
    save(folder,'canon_basis.json',{'prior_identity_evidence':prior.relative_to(R).as_posix(),'prior_sha256':sha(prior),
         'primary_text':basis['primary_text'],'primary_text_sha256':sha(book),'quotes':basis['quotes'],
         'scope':'Human Yang Lin and one iron pen-barrel spear. Clothing and precise gait/layer topology are game art interpretations, not literal book instructions.',
         'avoid':['No animal transformation, magic, ninja weapons, new plot or casualty.',
                  'Modular clothing/torso layers are technical animation inputs, not an injury/amputation state.',
                  'Do not arm rescued/bound variants or qualify current skill descriptions from this batch.']})
assert sorted(counts.values())==[5,7],counts
save(W,'visual_assessment.json',{'reviewed_originals':sorted(p.relative_to(W).as_posix() for p in (W/'native_originals').glob('*.png')),
     'contact_a_v1':'First contact reference only. Requested anatomical-right-leading label was not independently established.',
     'passing_a_v1':'Front silhouettes narrow, but rear views remain extended/contact-like; full passing not accepted.',
     'contact_b_v1':'Does not establish opposite leg attachment in all views; rejected as opposite contact.',
     'contact_b_se_v2_sw_v2':'Some cloth/leg redraw visible, but trustworthy hip-to-knee alternation remains unproven.',
     'contact_b_ne_v2_ne_v3':'Rear redraw, including debug-guide attempt, still does not establish requested swapped hip/leg chains.',
     'debug_guide':'ne_pose_guide_v1.png is a browser anatomy overlay used only as generation support, never production art.',
     'decision':'Whole-figure sources are not a qualified walking cycle. Continue with separate left/right modular legs.',
     'walking_cycle_accepted':False,'production_adopted':False,'native_accepted':False})
save(Q,'visual_assessment.json',{'reviewed_originals':['native_originals/'+k+'.png' for k in ['torso_v1','thighs_v1','shins_v1','boots_v1','boots_v2']],
     'reviewed_browser_frames':{v:[f'browser_rig_{v}/phase_{i:02d}.png' for i in range(4)] for v in ['v1','v2','v3']},
     'v1':'Four frames reviewed; torso too large/long relative to legs, not accepted.',
     'v2':'Fixed uniform torso scale .75 improves proportion; old boot shaft creates overlapping blue tube/cap at ankle, not accepted.',
     'v3':'Low boots remove extra shaft and improve ankle overlap. Independent leg identities/half-cycle control are visible in static comparison, not a final natural gait acceptance.',
     'limits':['Strict raw alpha-edge source preparation failed and remains failed; faint source pixels are not cleaned or masked.',
               'Only four static phases were rendered per variant; no continuous real-time or human-playtest acceptance.',
               'Manual source joint/sole anchors retain about15source-pixel uncertainty; no physical contact claim.',
               'Knee/cap seams, silhouette, depth ordering, carried-spear clearance, gait amplitude and foot sliding still require work.',
               'Stride/cycle must be matched to actual Unit speed/draw scale before movement acceptance.',
               'No native Godot import, ordinary Unit, rescued/bound regression, HUD/codex, package or performance acceptance.'],
     'next_comparison_candidate':'browser_rig_v3 only; no production selection',
     'walking_cycle_accepted':False,'production_adopted':False,'native_accepted':False})
for version in ['v1','v2','v3']:
    archive=Q/('browser_rig_'+version);receipt=json.loads((archive/'receipt.json').read_text(encoding='utf-8'))
    assert len(receipt['frames'])==4 and receipt['geometric_samples']==128
    for i,frame in enumerate(receipt['frames']):
        assert sha(archive/f'phase_{i:02d}.png')==frame['png_sha256']
        assert sha(archive/f'phase_{i:02d}.svg')==frame['svg_sha256'] and frame['exit_code']==0
    save(archive,'archive_index.json',[{'file':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(archive.iterdir()) if p.is_file()])
replay=Path('D:/CodexEvidence/shuihu/yang_lin_leg_rig_sources_20261019/replay_v3_phase0/receipt.json')
replay_data=json.loads(replay.read_text(encoding='utf-8'));assert replay_data['png_byte_identical_to_frozen']
shutil.copyfile(replay,Q/'static_replay_receipt.json')
groups={}
for name,manifest in [('runtime129','qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json'),
                      ('protected16','qa/tribute_cart_wheel_unit_20261018/protected_next.json'),
                      ('foreign81','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json')]:
    rows=json.loads((R/manifest).read_text(encoding='utf-8'))
    for row in rows:assert sha(R/row['path'])==row['sha256'],row['path']
    groups[name]={'manifest':manifest,'files':len(rows),'changes':0}
assert [groups[k]['files'] for k in ['runtime129','protected16','foreign81']]==[129,16,81]
assert sha(R/'scripts/hud.gd')=='e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save(Q,'preservation.json',{'checked_at':datetime.datetime.now().isoformat(),'groups':groups,
     'hud_sha256':sha(R/'scripts/hud.gd'),'production_changed':False})
syntax=[]
for folder in [W,Q]:
    for path in folder.rglob('*.py'):
        ast.parse(path.read_text(encoding='utf-8'),filename=str(path))
        syntax.append({'path':path.relative_to(R).as_posix(),'sha256':sha(path)})
save(Q,'python_syntax.json',{'files':syntax,'scope':'Python AST only; not Godot or native acceptance.'})
print(json.dumps({'originals':counts,'browser_frames_reviewed':12,'preserved':groups,'production_adopted':False,'native_accepted':False}))
