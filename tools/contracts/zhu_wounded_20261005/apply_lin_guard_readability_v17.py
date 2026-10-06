"""After complete mechanics and actual visual rejection, edit only guard drawing."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';BASE=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    rp=BASE/'ordinary_skill_clearance_v16b_dc124f7f/receipt.json';r=read(rp)
    assert r['complete'] and r['lock_released'] and r['private_runtime_patches']==0 and r['root_input_drift']==r['private_input_drift']==0
    assert r['result']['passed'] and r['result']['checks']==761 and len(r['result']['screenshots'])==112
    review=read(QA/'ordinary_skill_clearance_visual_review_v16b.json')
    assert not review['passed'] and review['blocked_by']=='lin_guard_sprite_occlusion' and review['receipt_sha256']==sha(rp)
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    p=ROOT/'scripts/battle.gd';before=sha(p);data=p.read_bytes()
    old='''\t\tvar c := Color(col.r, col.g, col.b, 0.72 * fade * pulse)
\t\tdraw_arc(Vector2.ZERO, 25.0, -PI * 0.92, PI * 0.12, 26, c, 3.0)
\t\tdraw_arc(Vector2.ZERO, 31.0, -PI * 0.88, PI * 0.08, 26, Color(c.r, c.g, c.b, c.a * 0.45), 1.5)
\t\tfor a in [-2.55, -1.95, -1.35, -0.75, -0.15]:
\t\t\tvar d := Vector2(cos(a), sin(a))
\t\t\tdraw_line(d * 9.0, d * 35.0, c, 2.4)
\t\t\tdraw_colored_polygon(PackedVector2Array([d * 41.0, d.rotated(0.16) * 32.0, d.rotated(-0.16) * 32.0]),
\t\t\t\tColor(0.94, 0.97, 1.0, 0.9 * fade))'''
    new='''\t\t# Keep the guard cue around the feet instead of over the torso/head.
\t\t# Only drawing changes: the target, guard duration and damage rules stay intact.
\t\tvar origin := Vector2(0.0, 8.0)
\t\tvar c := Color(col.r, col.g, col.b, 0.34 * fade * pulse)
\t\tdraw_arc(origin, 25.0, -PI * 0.92, PI * 0.12, 26, c, 1.8)
\t\tdraw_arc(origin, 31.0, -PI * 0.88, PI * 0.08, 26, Color(c.r, c.g, c.b, c.a * 0.45), 1.0)
\t\tfor a in [-2.55, -1.95, -1.35, -0.75, -0.15]:
\t\t\tvar d := Vector2(cos(a), sin(a))
\t\t\tdraw_line(origin + d * 25.0, origin + d * 31.0, c, 1.5)
\t\t\tdraw_colored_polygon(PackedVector2Array([origin + d * 33.0, origin + d.rotated(0.12) * 27.0, origin + d.rotated(-0.12) * 27.0]),
\t\t\t\tColor(0.94, 0.97, 1.0, 0.36 * fade))'''
    old_bytes=old.encode('utf-8');new_bytes=new.encode('utf-8')
    if data.count(old_bytes)!=1:old_bytes=old_bytes.replace(b'\n',b'\r\n');new_bytes=new_bytes.replace(b'\n',b'\r\n')
    assert data.count(old_bytes)==1
    start=data.index(old_bytes);end=start+len(old_bytes)
    class_start=data.rfind(b'class LinGuardFx',0,start);assert class_start>=0 and b'func _draw()' in data[class_start:start]
    updated=data[:start]+new_bytes+data[end:];assert updated[:start]==data[:start] and updated[start+len(new_bytes):]==data[end:]
    p.write_bytes(updated)
    record={'applied':True,'path':'scripts/battle.gd','before_sha256':before,'after_sha256':sha(p),'producer_sha256':sha(Path(__file__)),
        'baseline_receipt_sha256':sha(rp),'rejected_visual_review_sha256':sha(QA/'ordinary_skill_clearance_visual_review_v16b.json'),
        'scope':'Only LinGuardFx._draw local geometry/color/line widths changed; class fields, ready/process, durations, damage/retaliation, Unit/Defs/ArtDB/resources and save schema unchanged.',
        'guard_visual_bounds_screen_units':{'highest_y':-25.0,'maximum_radius':33.0,'origin_y':8.0,'opaque_spokes_removed':True},
        'production_qualified':False,'next':'Fresh unchanged-production full phase/effect/source verification and actual visual review required.'}
    q=QA/'lin_guard_readability_patch_v17.json';assert not q.exists();q.write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'production_changed':['scripts/battle.gd'],'drawing_only':True,'qualified':False}))
if __name__=='__main__':main()
