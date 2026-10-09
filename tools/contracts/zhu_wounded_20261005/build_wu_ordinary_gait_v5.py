"""Build a candidate manifest from native Wu Song phases, without raster edits."""
from pathlib import Path
import argparse,hashlib,json,re,copy
from PIL import Image
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--import-receipt',type=Path)
args=ap.parse_args()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
original=read(ROOT/'assets/direction4/ordinary_wu_song_20261006_traits_v4.json')
lineage=read(HERE/'generation_wu_song_v4.json')
graph={j['key']:copy.deepcopy(j) for j in lineage['jobs']}
known={j['repository_path']:j['key'] for j in graph.values() if j['repository_path']}
for gp in ['generation_qin_ming_walk_passing_v4.json','generation_wang_ying_walk_passing_v4.json']:
    for j in read(HERE/gp)['jobs']:
        if j.get('method') in ['godot_3d_pose_reference','orthographic_geometry_diagram']:
            if j['key'] in graph:assert graph[j['key']]['sha256']==j['sha256']
            graph[j['key']]=copy.deepcopy(j);known[j['repository_path']]=j['key']
def ancestor(path):
    if path in known:return known[path]
    p=ROOT/path; jp=HERE/'jobs'/('wu_song_'+p.stem+'.json')
    j=read(jp);assert j['output']==path and sha(p)==j['output_sha256']
    req=ROOT/j['request']; assert sha(req)==j['request_sha256']; request=read(req)
    refs=[]
    for r in j['references']:
        assert sha(ROOT/r['path'])==r['sha256'];refs.append(ancestor(r['path']))
    key=jp.stem
    graph[key]={'key':key,'method':'built_in_imagegen','generation_id':j['generation_id'],
        'repository_path':path,'sha256':sha(p),'prompt':request['prompt'],'request':j['request'],
        'request_sha256':sha(req),'references':refs,'transparent_background':True,
        'selected':True,'native_pixel_edits':False}
    known[path]=key;return key
m=copy.deepcopy(original);m['character']='character_traits_v5_wu_song_gait';m['identity_key']='wu_song'
m['revision']='character_traits_v5';m['candidate_only']=True;m['continuous_gait_qualified']=False
m['states']={'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']}
m['scope']='Ordinary armed Wu Song upright idle and separately authored four-heading/four-phase walk candidate. Actual motion, combat/UI and original production qualification remain open.'
m['resources']=[f"assets/anim/{m['character']}_{s}_{d}.tres" for s in ['idle','walk'] for d in ['se','sw','ne','nw']]
receipt=read(args.import_receipt) if args.import_receipt else None
dimensions={c['path']:c for c in receipt['dimensions']['checks']} if receipt else {}
if receipt:assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed']
seed=ROOT/(m['sources']['idle']['path']+'.import');seed_text=seed.read_text(encoding='utf-8')
selection=[]
for s in ['walk_a','passing_a','walk_b','passing_b']:
    for d in ['se','sw','ne','nw']:
        state=s+'_'+d
        variant=state+('3' if state=='walk_b_sw' else '2' if state=='walk_b_nw' else '')
        path=f'assets/characters/wu_song_traits_20261006/{variant}_v5.png'
        p=ROOT/path; job=ancestor(path)
        with Image.open(p) as im:
            assert im.mode=='RGBA' and im.size==(1254,1254)
            alpha=im.getchannel('A');mask=alpha.point(lambda v:255 if v>16 else 0);box=mask.getbbox()
            assert box and min(box[0],box[1],im.width-box[2],im.height-box[3])>=4
            body_height=box[3]-box[1]
            # Read-only estimate. Neither sampling nor this pivot is gait qualification.
            feet=mask.crop((0,box[3]-int(body_height*.23),im.width,box[3])).getbbox();assert feet
            pivot=[(feet[0]+feet[2])/2,box[3]-4]
            zero=alpha.histogram()[0]/(im.width*im.height)
        verified=False
        if receipt:
            check=dimensions[path];assert check['passed'] and [check['width'],check['height']]==[1254,1254]
            assert any(c['path']==path and c['before_sha256']==sha(p)==c['after_sha256'] for c in receipt['source_files'])
            verified=True
        m['sources'][state]={'path':path,'sha256':sha(p),'job':job,'mode':'RGBA','native_size':[1254,1254],
            'imported_size':[1254,1254],'import_limit':1536,'import_dimensions_verified':verified,
            'import_dimension_status':'independently verified native dimensions' if verified else 'expected pending independent Godot import',
            'full_atlas':True,'alpha_zero_fraction':zero}
        m['poses'][state]={'source':state,'region_raw':[0,0,1254,1254],'region':[0,0,1254,1254],'margin':[0,0,0,0],
            'virtual_size_imported':1254,'pivot':pivot,'draw_offset_px':[627-pivot[0],1254*.82-pivot[1]],
            'draw_scale':round(1254*.78/body_height,6)}
        selection.append({'pose':state,'source':path,'bounds':list(box),'initial_pivot':pivot,
                          'foot_anchor_status':'Lower-silhouette estimate; actual planted-foot continuity still needs motion review'})
        desc=Path(str(p)+'.import')
        if not desc.exists():
            old_path=m['sources']['idle']['path'];old_md5=hashlib.md5(('res://'+old_path).encode()).hexdigest()
            new_md5=hashlib.md5(('res://'+path).encode()).hexdigest()
            text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(old_path,path).replace(Path(old_path).name+'-'+old_md5,p.name+'-'+new_md5)
            desc.write_bytes(text.encode('utf-8'))
used={v['job'] for v in m['sources'].values()}
for j in graph.values():j['selected']=j['key'] in used
write(ROOT/'assets/direction4/ordinary_wu_song_20261006_gait_v5.json',m)
write(HERE/'generation_wu_song_gait_v5.json',{'original_reference':lineage['original_reference'],'jobs':list(graph.values()),
    'scope':'Exact retained ancestry, native geometric producers and new ordinary Wu Song walk candidates; no production routing'})
write(ROOT/'qa/zhu_wounded_20261005/wu_song_gait_sampling_v5.json',{'selection':selection,'native_sources':17,'poses':20,
    'rejected':['walk_b_sw_v5.png','walk_b_sw2_v5.png','walk_b_nw_v5.png'],'direct_static_review':'Corrected opposing support and facing observed; native references and full images directly viewed.',
    'runtime_qualified':False,'production_qualified':False})
print(json.dumps({'native_sources':len(m['sources']),'poses':len(m['poses']),'import_verified':bool(receipt),'resources':len(m['resources']),'production_qualified':False}))
