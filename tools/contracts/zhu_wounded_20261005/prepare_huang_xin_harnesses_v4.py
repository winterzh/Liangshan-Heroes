"""Create independent Huang Xin candidate helpers; keep prior producer inputs intact."""
from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
HARNESS = ROOT/'qa/zhu_wounded_20261005/harness'
for directory, names in ((HERE, ['prepare_yang_lin_walk_passing_v4.py','record_yang_lin_walk_passing_v4.py','record_yang_lin_unit_motion_v4.py']),
                         (HARNESS,['texture_bootstrap_yang_lin_v4.py','yang_lin_walk_preview_v4.py','yang_lin_walk_preview_v4.gd','unit_motion_yang_lin_v4.py','unit_motion_yang_lin_v4.gd','unit_motion_yang_lin_v4.tscn'])):
    for name in names:
        src=directory/name
        text=src.read_text(encoding='utf-8').replace('yang_lin','huang_xin').replace('Yang Lin','Huang Xin')
        text=text.replace("        if state=='walk_b' and d=='sw':name='huang_xin_walk_b2_sw_v4'\n",'')
        if name=='prepare_yang_lin_walk_passing_v4.py':
            text=text.replace("        j=read(HERE/f'jobs/{name}.json');", "        if d=='sw':name='huang_xin_idle_single2_sw_v4' if state=='idle' else f'huang_xin_{state}_idlefix_sw_v4'\n        if d=='ne' and state=='walk_b':name='huang_xin_walk_b2_ne_v4'\n        if d=='sw' and state=='passing_b':name='huang_xin_passing_b2_sw_v4'\n        j=read(HERE/f'jobs/{name}.json');")
        text=text.replace('Huang Xin alert mobile adult gait candidate','Huang Xin steady upright officer gait candidate')
        if name=='yang_lin_walk_preview_v4.gd':text=text.replace('zhu_wounded_v3_shi_xiu_gait','zhu_wounded_v4_huang_xin_gait_passing')
        if name=='yang_lin_walk_preview_v4.py':text=text.replace("manifest=json.loads(mp.read_text(encoding='utf-8'))\n", "manifest=json.loads(mp.read_text(encoding='utf-8'))\nassert manifest['identity_key']=='huang_xin' and manifest['character']=='zhu_wounded_v4_huang_xin_gait_passing'\n")
        if name=='unit_motion_yang_lin_v4.py':text=text.replace('m = read(mp)\n', "m = read(mp)\nassert m['identity_key']=='huang_xin' and m['character']=='zhu_wounded_v4_huang_xin_gait_passing'\n")
        text=text.replace('Alert broad-shouldered/narrow-waisted adult Huang Xin identity retained across four idle and sixteen true gait poses','Steady upright mature officer Huang Xin identity retained across four idle and sixteen true gait poses')
        text=text.replace('Leopard rosette coat, pale fur trim/sleeve cuffs and blue sash/headcloth/shin wraps remain identifiable','Ochre headband/scarf/sleeves, gold-riveted dark armor and ochre-wrapped boots remain identifiable')
        text=text.replace('Adult body-height metadata .78; mobile stance is art interpretation, spotted garment is retained project design rather than novel mandate','Adult body-height metadata .78 and steady officer stance are art interpretation; exact gold armor/ochre costume is retained project design rather than novel mandate')
        text=text.replace('Rear boot amplitude, exact planted foot anchors and coat hem/rosette and sash transitions require full continuous movement review','Rear boot amplitude, exact planted foot anchors and armor/scarf/hem transitions require full continuous movement review')
        text=text.replace('Alert broad shoulders/narrow waist, natural head alignment and flexible balanced bearing preserved at rest; original walking lean/breathing/squash/dust remain active','Steady upright officer bearing and natural mature proportions preserved at rest; original walking lean/breathing/squash/dust remain active')
        dest=directory/name.replace('yang_lin','huang_xin')
        if name.endswith('.py'): ast.parse(text)
        if dest.exists(): assert dest.read_text(encoding='utf-8')==text, 'Preserve reviewed existing helper: '+str(dest)
        else: dest.write_text(text,encoding='utf-8')
print('9 independent Huang Xin helpers prepared; no prior character producer changed')
