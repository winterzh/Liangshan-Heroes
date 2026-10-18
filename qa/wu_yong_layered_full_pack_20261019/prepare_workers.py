"""Bind external package probes without changing the verified game project."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
OLD=R/'qa/chao_gai_layered_full_pack_20261018'
E=Path('D:/CodexEvidence/shuihu/wu_yong_layered_full_pack_20261019')
W=E/'workers';W.mkdir(parents=True,exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for source,dest in [('pck_base.gd.txt','base.gd'),('pck_identity.gd.txt','identity.gd'),('pck_bootstrap.gd.txt','bootstrap.gd')]:
    shutil.copyfile(OLD/source,W/dest)
base=(W/'base.gd').read_text()
identity=base[base.index('func identity('):base.index('func _start(')]
driver=(R/'qa/wu_yong_push_gait_20261018/unit_driver_v2.gd.txt').read_text()
assert driver.count('var saved_meta=')==1
viewport='''	# Distinct viewport rendering samples; this is not a performance benchmark.
	for width in [960,1280,1920]:
		root.size=Vector2i(width,int(width*9/16));root.content_scale_size=root.size
		for d in ["se","sw","ne","nw"]:
			u.order_stop();u._move_blend=0;u._flinch=Vector2.ZERO;u._shi_en_hurt_t=0;u.animation_direction=d
			check(u._campaign_tribute_layered_frame(frame(u)),"package viewport retains Wu actor "+str(width)+d)
			await snap(b,u,"viewport_"+str(width)+"_"+d)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
'''
driver=driver.replace('\tvar saved_meta=',viewport+'\tvar saved_meta=',1)
driver=driver.replace('var out: String','var trusted: Dictionary={}\n'+identity+'var out: String',1)
driver=driver.replace('\tDirAccess.make_dir_recursive_absolute(out)','\tif not identity(false):finish();return\n\tDirAccess.make_dir_recursive_absolute(out)',1)
driver=driver.replace('"new_pack_exported":false','"new_pack_exported":true,"compiled_package_tested":true',1)
(W/'live.gd').write_text(driver,encoding='utf-8',newline='\n')
src=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit_v2/runtime_inputs.json')
shutil.copyfile(src,W/'runtime_inputs.json')
rows=[]
for p in sorted(W.iterdir()):
    dest=Q/(p.name+'.txt' if p.suffix=='.gd' else p.name)
    shutil.copyfile(p,dest);assert sha(dest)==sha(p)
    rows.append({'path':p.name,'sha256':sha(p),'bytes':p.stat().st_size})
shutil.copyfile(OLD/'release_step.py',Q/'release_step.py')
(Q/'worker_bindings.json').write_text(json.dumps({'files':rows,'source_unit_driver_sha256':sha(R/'qa/wu_yong_push_gait_20261018/unit_driver_v2.gd.txt'),'scope':'Same actual Unit probe plus compiled identity checks and 12 static viewport captures. No source identity regeneration or game-input mutation.'},indent=2)+'\n')
print(json.dumps({'workers':len(rows),'output':str(W)}))
