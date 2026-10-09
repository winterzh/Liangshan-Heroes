"""Correct standing Lin SW hurt using the shared hurt/death-recoil convention."""
from pathlib import Path
import copy,hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    parent_path=ROOT/'assets/direction4/ordinary_lin_chong_20261007_death_v10.json';parent=read(parent_path)
    source=copy.deepcopy(parent['sources']['sw2']);assert source['import_dimensions_verified'] and sha(ROOT/source['path'])==source['sha256']
    pose=copy.deepcopy(parent['poses']['fatal_sw']);pose['source']='sw2'
    family='character_traits_v12_lin_chong_hurt';resource='assets/anim/'+family+'_hurt_sw.tres'
    lines=['[gd_resource type="SpriteFrames" load_steps=3 format=3]','',
           '[ext_resource type="Texture2D" path="res://'+source['path']+'" id="sw2"]','',
           '[sub_resource type="AtlasTexture" id="recoil"]','atlas = ExtResource("sw2")',
           'region = Rect2('+', '.join(map(str,pose['region']))+')','margin = Rect2('+', '.join(map(str,pose['margin']))+')',
           'filter_clip = true','metadata/draw_offset_px = Vector2(%s, %s)'%tuple(pose['draw_offset_px']),
           'metadata/authored_direction4 = true','metadata/draw_scale = '+str(pose['draw_scale']),'','[resource]',
           'animations = [{','"frames": [{"duration": 1.0, "texture": SubResource("recoil")}],',
           '"loop": false,','"name": &"default",','"speed": 4.0','}]','']
    p=ROOT/resource;assert not p.exists();p.write_bytes('\n'.join(lines).encode('utf-8'))
    resources=[resource];preserved=[]
    for direction in ['se','ne','nw']:
        original='assets/anim/lin_chong_hurt_'+direction+'.tres';alias='assets/anim/'+family+'_hurt_'+direction+'.tres'
        assert not (ROOT/alias).exists();shutil.copy2(ROOT/original,ROOT/alias);assert sha(ROOT/original)==sha(ROOT/alias)
        resources.append(alias);preserved.append({'original':original,'alias':alias,'sha256':sha(ROOT/alias)})
    dump(ROOT/'assets/direction4/ordinary_lin_chong_20261007_hurt_v12.json',{
        'schema':'native_direction4_spriteframes_v1','revision':'character_traits_v5','character':family,'identity_key':'lin_chong',
        'candidate_only':True,'production_qualified':False,'runtime_hurt_qualified':False,'states':{'hurt':['recoil']},
        'sources':{'sw2':source},'poses':{'recoil_sw':pose},'resources':resources,'preserved_resources':preserved,
        'pose_parent':parent_path.relative_to(ROOT).as_posix(),'pose_parent_sha256':sha(parent_path),'selected_parent_pose':'fatal_sw',
        'scope':'One corrected standing SW hurt/recoil; existing Lin SW hurt and death first pose were the exact same old atlas region. Reuse only the new standing recoil, never a lying corpse. Other three hurt resources are exact aliases. Actual nonlethal counterhit and production qualification pending.'})
    print(json.dumps({'standing_hurt_poses':1,'resources':4,'unchanged_hurt_aliases':3,'new_native_images':0,'runtime_qualified':False}))

if __name__=='__main__':main()
