"""Prepare fixed actor registration against bounded existing wooden handle regions.

No PNG writes, cart motion, per-frame fitting, runtime adoption or contact acceptance.
"""
from pathlib import Path
import copy, hashlib, json, shutil
import numpy as np
from PIL import Image

R=Path(__file__).resolve().parents[2]
Q=Path(__file__).resolve().parent
B=Path('D:/CodexEvidence/shuihu/chao_gai_registered_body_scale_v2_20261018')
E=Path('D:/CodexEvidence/shuihu/chao_gai_shaft_contact_v3_20261018')

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f: f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')

def bounded_fit(a,b,max_t):
    candidates=[]
    t=np.linalg.lstsq(a,b,rcond=None)[0]
    if np.all(t>=0) and np.all(t<=max_t): candidates.append(t)
    for fixed in [0,1]:
        free=1-fixed
        for edge in [0.,max_t]:
            v=np.zeros(2);v[fixed]=edge
            v[free]=np.clip(np.dot(a[:,free],b-a[:,fixed]*edge)/np.dot(a[:,free],a[:,free]),0,max_t)
            candidates.append(v)
    return min(candidates,key=lambda v:np.linalg.norm(a@v-b))

def main():
    assert not E.exists(),'Never overwrite a prepared candidate'
    binding=json.loads((B/'prepared_binding.json').read_text())
    assert all(sha(B/'prepared'/x['path'])==x['sha256'] for x in binding['frozen'])
    data=json.loads((B/'prepared/inputs.json').read_text())
    # Approximate manually inspected centres along real, existing bare wooden shafts.
    # Only their first 45 percent may be used; no hand target can move into the cargo.
    segments={'se': [[[52,194],[158,276]],[[171,141],[271,211]]],
              'sw': [[[1086,155],[987,230]],[[1200,198],[1100,278]]]}
    cart_pixels=np.asarray(Image.open(R/data['cart_source']))
    for d,segs in segments.items():
        reg=data['registration'][d];grips=np.array(reg['manual_idle_source_grips'],dtype=float)
        ref=reg['constant_reference_all_phases'];cart=data['cart_poses'][d]
        points=np.array(segs,dtype=float);start=points[:,0];vectors=points[:,1]-start
        wanted=(grips[1]-grips[0])*cart['virtual_canvas_reference']/ref
        matrix=np.column_stack((-vectors[0],vectors[1]))
        ts=bounded_fit(matrix,wanted-(start[1]-start[0]),.45)
        targets=start+ts[:,None]*vectors
        pixels=[]
        for x,y in targets:
            rgba=cart_pixels[int(round(y)),int(round(x))].tolist();assert rgba[3]>=128,(d,x,y,rgba)
            pixels.append(rgba)
        normalized=(targets-np.array(cart['pivot_native']))/cart['virtual_canvas_reference']
        pivot=np.mean(grips,axis=0)-np.mean(normalized,axis=0)*ref
        residual=(grips-pivot)/ref-normalized
        for v in data['views'][d].values():
            v['actor_pose']['pivot_native']=pivot.tolist()
        reg.update(manual_cart_targets=targets.tolist(),constant_pivot_all_phases=pivot.tolist(),
            target_selection={'method':'Bounded least-squares against two manually annotated existing shaft segments, using idle grips only. Same actor transform for all five phases; no per-frame contact fitting.',
                              'segments':segs,'max_fraction':.45,'fractions':ts.tolist(),
                              'source_rgba_at_targets':pixels,'estimated_pair_residual_per_body_size':residual.tolist(),
                              'source_annotation_uncertainty_pixels':3,'actual_contact_accepted':False})
        reg.pop('source_residuals_after_translation',None)
        reg.pop('desired_grips_in_idle_source_coordinates',None)
        # The stored pre-v3 shift is historical; the new pivot above is authoritative.
        reg['historical_shift_native_v2']=reg.pop('constant_actor_shift_native')
    data['scope']+=' Front idle targets lie on bounded opaque wood, not mandatory shaft tips; source landmark uncertainty and actual contact remain open.'
    E.mkdir(parents=True);P=E/'prepared';P.mkdir()
    for row in binding['frozen']:
        src=B/'prepared'/row['path'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(src,dst);assert sha(src)==sha(dst)==row['sha256']
    (P/'inputs.json').unlink();save(P/'inputs.json',data)
    frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}
            for p in sorted(P.rglob('*')) if p.is_file()]
    save(E/'prepared_binding.json',{'prepared':True,'native_executed':False,'project':str(P),
        'frozen':frozen,'preparer_sha256':sha(Path(__file__)),'body_scale_binding_sha256':sha(B/'prepared_binding.json'),
        'png_count':len(data['textures']),'pixel_writes':False,'registration':data['registration'],
        'source_hashes':binding['source_hashes'],'native_old_corner_failures_not_relaxed':True,'production_adopted':False})
    for src,dst in [(P/'inputs.json',Q/'shaft_v3_inputs.json'),(E/'prepared_binding.json',Q/'shaft_v3_prepared_binding.json')]:shutil.copyfile(src,dst)
    print(json.dumps({d:data['registration'][d]['target_selection'] for d in segments}))

if __name__=='__main__':main()
