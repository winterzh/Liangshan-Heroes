from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;N=Q/'native_sw_rig_v2';N.mkdir()
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019/prepared_sw_rig_v2');E.mkdir()
old=json.loads((Q/'native_sw_v1/prepared_binding.json').read_text());P=Path(old['project'])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in old['files']:
    src=P/row['path'];assert sha(src)==row['sha256'];dst=E/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
data=old['inputs'];data['scope']='SW rigid-piece leg diagnostic. Original source columns retained; LIVE passing A uses original-texture body clipping, rigid upper/lower foreleg and fixed source chest cover. Original PNG bytes retained. No gait/anatomy/Unit/production/performance qualification.'
data['rig']={'texture':'horse_passing_a_sw_v3','shoulder':[877,401],'knee':[900,490],'hoof':[935,588],'target':[948,548],'body_cut':[[860,408],[902,408],[913,445],[935,480],[957,523],[974,563],[990,660],[890,660],[891,572],[889,530],[875,485],[860,440]],'upper_piece':[[856,398],[905,398],[925,448],[946,482],[950,520],[890,525],[872,480],[855,440]],'lower_piece':[[883,470],[938,470],[962,520],[977,565],[976,610],[901,615],[888,570],[884,530]],'chest_cover':[840,350,100,88]}
(E/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(Q/'native_sw_v1/preview.gd.txt').read_text()
driver=driver.replace('\troot.add_child(stage)','\tvar rig: Dictionary=stage.prepare_rig()\n\tcheck(float(rig.upper_length_error)<.001 and float(rig.lower_length_error)<.001,"two bone segment lengths retained")\n\tcheck(float(rig.hoof_target_error)<.001,"manual hoof anchor reaches target")\n\tcheck(float(rig.body_area_partition_error)<.1 and int(rig.body_polygons)>0,"source body clip partitions exact quadrant area")\n\tcheck(float(rig.piece_edge_length_error)<.001,"rigid painted piece edge lengths retained")\n\troot.add_child(stage)',1)
driver=driver.replace('"texture_references":refs,','"texture_references":refs,"rig_diagnostics":stage.rig_info,',1)
needle='\t\tvar rr: Array=data.textures[key].selected_region;';assert driver.count(needle)==1
driver=driver.replace(needle,'\t\tif use_rig and key==String(data.rig.texture):paint_rig();return\n'+needle,1)
driver=driver.replace('\t\t\tvar selected: int=','\t\t\tuse_rig=i==4\n\t\t\tvar selected: int=',1)
driver=driver.replace('"LIVE PROCESS / "','"LIVE + RIGID LEG / "').replace('"FIXED PHASE / "','"RAW SOURCE / "')
driver=driver.replace('SW source comparison only. Horse/rider PNG bytes unchanged; runtime rein uses original painted leather material.','SW rigid-piece diagnostic. LIVE passing A uses original painted upper/lower leg pieces; body and chest cover are original texture.')
driver+='\n'+(Q/'rig_sw_pieces.gd.txt').read_text()
(N/'preview.gd.txt').write_text(driver,encoding='utf-8',newline='\n');(E/'preview.gd').write_text(driver,encoding='utf-8',newline='\n')
(N/'run.py').write_text((Q/'native_sw_v1/run.py').read_text().replace('native_sw_v1','native_sw_rig_v2'),encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(E).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(E.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(E),'files':files,'inputs':data,'native_executed':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'prepared':True,'files':len(files),'source_png_changed':False}))
