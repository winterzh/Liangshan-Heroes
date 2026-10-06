"""Create independent Deng Fei candidate helpers without changing earlier producers."""
from pathlib import Path
import ast
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;HARNESS=ROOT/'qa/zhu_wounded_20261005/harness'
for directory,names in ((HERE,['prepare_yang_lin_walk_passing_v4.py','record_yang_lin_walk_passing_v4.py','record_yang_lin_unit_motion_v4.py']),
                        (HARNESS,['texture_bootstrap_yang_lin_v4.py','yang_lin_walk_preview_v4.py','yang_lin_walk_preview_v4.gd','unit_motion_yang_lin_v4.py','unit_motion_yang_lin_v4.gd','unit_motion_yang_lin_v4.tscn'])):
    for name in names:
        text=(directory/name).read_text(encoding='utf-8').replace('yang_lin','deng_fei').replace('Yang Lin','Deng Fei')
        text=text.replace("        if state=='walk_b' and d=='sw':name='deng_fei_walk_b2_sw_v4'\n",'')
        if name=='prepare_yang_lin_walk_passing_v4.py':text=text.replace("        j=read(HERE/f'jobs/{name}.json');", "        if d=='sw' and state=='passing_b':name='deng_fei_passing_b4_sw_v4'\n        j=read(HERE/f'jobs/{name}.json');")
        text=text.replace('Deng Fei alert mobile adult gait candidate','Deng Fei rugged alert martial gait candidate')
        text=text.replace('Alert broad-shouldered/narrow-waisted adult Deng Fei identity retained across four idle and sixteen true gait poses','Rugged alert mature martial adult Deng Fei identity retained across four idle and sixteen true gait poses')
        text=text.replace('Leopard rosette coat, pale fur trim/sleeve cuffs and blue sash/headcloth/shin wraps remain identifiable','Full curly hair/beard, brown/brass armor and ragged scarf, rust hair tie/sash and ornate shin armor remain identifiable')
        text=text.replace('Adult body-height metadata .78; mobile stance is art interpretation, spotted garment is retained project design rather than novel mandate','Adult body-height metadata .78 and rugged alert martial stance are art interpretation; exact curly hair/brown armor/cloth are retained project design rather than novel mandates')
        text=text.replace('Rear boot amplitude, exact planted foot anchors and coat hem/rosette and sash transitions require full continuous movement review','Rear boot amplitude, exact planted foot anchors, curly hair/scarf/armor and rust sash transitions require full continuous movement review')
        text=text.replace('Alert broad shoulders/narrow waist, natural head alignment and flexible balanced bearing preserved at rest; original walking lean/breathing/squash/dust remain active','Rugged alert natural mature proportions and healthy upper back preserved at rest; original walking lean/breathing/squash/dust remain active')
        if name=='yang_lin_walk_preview_v4.gd':text=text.replace('zhu_wounded_v3_shi_xiu_gait','zhu_wounded_v4_deng_fei_gait_passing')
        if name=='yang_lin_walk_preview_v4.py':text=text.replace("manifest=json.loads(mp.read_text(encoding='utf-8'))\n", "manifest=json.loads(mp.read_text(encoding='utf-8'))\nassert manifest['identity_key']=='deng_fei' and manifest['character']=='zhu_wounded_v4_deng_fei_gait_passing'\n")
        if name=='unit_motion_yang_lin_v4.py':text=text.replace('m = read(mp)\n',"m = read(mp)\nassert m['identity_key']=='deng_fei' and m['character']=='zhu_wounded_v4_deng_fei_gait_passing'\n")
        if name=='unit_motion_yang_lin_v4.py':
            text=text.replace('import argparse, hashlib, json, os, shutil, subprocess, sys, time, uuid\n','import argparse, hashlib, json, os, shutil, subprocess, sys, time, uuid\nfrom merge_candidate_import_cache_v4 import merge_candidate_cache\n')
            a=text.index("shutil.copytree(prior/'.godot/imported'");b=text.index('native = shared.install_native(project)',a)
            text=text[:a]+"cache_policy = merge_candidate_cache(ROOT,m,prior,bootstrap/'project',project,imp)\n"+text[b:]
            text=text.replace("'unit_motion_deng_fei_v4.tscn']:","'unit_motion_deng_fei_v4.tscn','merge_candidate_import_cache_v4.py']:")
            text=text.replace("'cache_is_not_cold_import':True,'native_dependencies':native,","'cache_is_not_cold_import':True,'candidate_cache_precedence':cache_policy,'native_dependencies':native,")
        dest=directory/name.replace('yang_lin','deng_fei')
        if name.endswith('.py'):ast.parse(text)
        if dest.exists():assert dest.read_text(encoding='utf-8')==text, 'Preserve existing independently reviewed helper: '+str(dest)
        else:dest.write_text(text,encoding='utf-8')
print('9 independent Deng Fei candidate helpers prepared; earlier producer inputs unchanged')
