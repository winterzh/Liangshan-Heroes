"""Derive a sibling death/shadow pilot for the reviewed Lin southwest correction."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
HERE=ROOT/'qa/zhu_wounded_20261005/harness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def replace_once(text,old,new):
    assert text.count(old)==1,old[:100]
    return text.replace(old,new)

def main():
    gd_source=HERE/'ordinary_death_production_v9.gd'
    py_source=HERE/'run_ordinary_death_production_v9.py'
    gd=gd_source.read_text(encoding='utf-8').replace('ordinary_death_production_v9','ordinary_death_pilot_v10')
    gd=replace_once(gd,'if row.key=="wu_song" and row.state=="death":',
                    'if row.state=="death" and (row.key=="wu_song" or (row.key=="lin_chong" and row.direction=="sw")):')
    gd=gd.replace('production Wu native directional death ','pilot native directional death '+ ' ')
    needle='\t\t\tif key=="wu_song":check(u._frame_directional and String(_snapshot(u).source).contains("_traits_20261006/"),"new Wu death uses own directional body")'
    gd=replace_once(gd,needle,needle+'\n\t\t\tif key=="lin_chong" and d=="sw":check(u._frame_directional and String(_snapshot(u).source).ends_with("death_sw2_v10.png"),"corrected Lin SW death uses own native source")')
    gd=gd.replace('## Current production scripts copied unchanged; original level-one lethal damage.',
                  '## Candidate Wu death and corrected Lin SW lookup only in private ArtDB; original level-one combat damage.')
    py=py_source.read_text(encoding='utf-8').replace('ordinary_death_production_v9','ordinary_death_pilot_v10')
    py=replace_once(py,'assert review[\'passed\'] and review[\'death_qualified\'] and review[\'skills_qualified\']',
                    "assert not review['passed'] and review['wu_death_sampled_qualified'] and not review['lin_sw_death_qualified'] and review['skills_mechanical_passed']")
    old="""    changed=[row['path'] for row in before if sha(ROOT/row['path'])!=row['sha256']]
    assert changed==['scripts/art_db.gd'],changed
    assert sha(ROOT/'scripts/art_db.gd')==pilot['private_patch']['patched_sha256']==sha(old/'scripts/art_db.gd')
    inputs=[dict(row,sha256=sha(ROOT/row['path'])) for row in before]
    assert all(sha(ROOT/row['path'])==row['sha256']==sha(old/row['path']) for row in inputs+existing+new)"""
    new="""    changed=[row['path'] for row in before if sha(ROOT/row['path'])!=row['sha256']]
    assert changed==[],changed
    assert sha(old/'scripts/art_db.gd')==pilot['private_patch']['patched_sha256']
    inputs=before
    assert all(sha(ROOT/row['path'])==row['sha256']==sha(old/row['path']) for row in inputs+existing+new if row['path']!='scripts/art_db.gd')
    manifest_path=ROOT/'assets/direction4/ordinary_lin_chong_20261007_death_v10.json';manifest=read(manifest_path)
    assert not manifest['production_qualified'] and len(manifest['poses'])==4 and len(manifest['preserved_resources'])==3
    paths=set(manifest['resources'])|{manifest_path.relative_to(ROOT).as_posix()}
    for row in manifest['sources'].values():
        assert row['import_dimensions_verified'] and sha(ROOT/row['path'])==row['sha256'];paths.update([row['path'],row['path']+'.import'])
    for row in manifest['preserved_resources']:assert sha(ROOT/row['original'])==sha(ROOT/row['alias'])==row['sha256']
    previous={row['path'] for row in inputs+existing+new}
    lin_inputs=[{'path':p,'sha256':sha(ROOT/p)} for p in sorted(paths) if p not in previous]
    new=new+lin_inputs
    boot=Path(read(args.work_root/'texture_bootstrap_lin_chong_death_v10_run.json')['run']);assert read(boot/'receipt.json')['complete']"""
    py=replace_once(py,old,new)
    py=replace_once(py,"'private_runtime_patches':0,'production_source_delta':changed,","'private_runtime_patches':1,'production_source_delta':changed,")
    py=py.replace("'private_runtime_patches':0}","'private_runtime_patches':1}")
    py=replace_once(py,"        shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)","""        shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)
        for src in (boot/'project/.godot/imported').iterdir():
            if not src.is_file():continue
            dst=project/'.godot/imported'/src.name
            if dst.exists():assert sha(dst)==sha(src)
            else:shutil.copy2(src,dst)
        art=project/'scripts/art_db.gd';text=art.read_text(encoding='utf-8')
        wu='"attack": "character_traits_v7_wu_song_combat", "hurt": "character_traits_v7_wu_song_combat"'
        lin='"idle": "character_traits_v5_lin_chong_gait", "walk": "character_traits_v5_lin_chong_gait"'
        assert text.count(wu)==text.count(lin)==1
        text=text.replace(wu,wu+', "death": "character_traits_v8_wu_song_death"').replace(lin,lin+', "death": "character_traits_v10_lin_chong_death"')
        art.write_bytes(text.encode('utf-8'))
        receipt['private_patch']={'path':'scripts/art_db.gd','original_sha256':sha(ROOT/'scripts/art_db.gd'),'patched_sha256':sha(art),'scope':'Wu ordinary death and Lin death family lookup only; Lin three other resources exact unchanged aliases. No gameplay patches.'}""")
    py=replace_once(py,"assert all(sha(ROOT/row['path'])==row['sha256']==sha(project/row['path']) for row in inputs+existing+new)",
                    "assert all(sha(ROOT/row['path'])==row['sha256'] for row in inputs+existing+new)\n        assert all(sha(project/row['path'])==row['sha256'] for row in inputs+existing+new if row['path']!='scripts/art_db.gd')\n        assert sha(art)==receipt['private_patch']['patched_sha256']")
    py=replace_once(py,'root_input_drift=0,private_input_drift=0,covered_default_death_routes_verified=True',
                    'root_input_drift=0,private_input_drift_except_declared_patch=0,private_patch_verified=True,candidate_death_routes_verified=True')
    py=py.replace('Current production scripts copied unchanged; ordinary Wu four-direction death adoption.',
                  'Private ArtDB death lookups for Wu four directions and corrected Lin SW; other scripts copied unchanged. Candidate only, no default adoption.')
    for name,text in [('ordinary_death_pilot_v10.gd',gd),('run_ordinary_death_pilot_v10.py',py)]:
        path=HERE/name;assert not path.exists();path.write_bytes(text.encode('utf-8'))
    out=ROOT/'qa/zhu_wounded_20261005/ordinary_death_pilot_preparation_v10.json';assert not out.exists()
    out.write_bytes((json.dumps({'parents':[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'executed':False} for p in [gd_source,py_source]],
                                'scope':'V9 prototypes were never executed. V10 sibling adds corrected Lin SW candidate and direct shadow checks; compilation/runtime qualification pending.'},indent=2)+'\n').encode('utf-8'))
    print('Prepared v10 sibling death/shadow pilot; execution requires completed Lin native import.')

if __name__=='__main__':main()
