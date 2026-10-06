"""Add a separate 52-check Shi Xiu identity fixture; retain the prior 44-check run."""
from pathlib import Path
import ast
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;H=ROOT/'qa/zhu_wounded_20261005/harness'
for suffix in ('py','gd','tscn'):
    src=H/f'unit_motion_huang_xin_v4.{suffix}'
    text=src.read_text(encoding='utf-8').replace('huang_xin','shi_xiu').replace('Huang Xin','Shi Xiu')
    text=text.replace('unit_motion_shi_xiu_v4','unit_motion_shi_xiu_identity_v4')
    if suffix=='py':
        text=text.replace("slot='shi_xiu_passing_v4'", "slot='shi_xiu_identity_footclear_v4'")
        text=text.replace("mp = ROOT/f'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_passing_v4.json'", "mp = ROOT/'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_footclear_v4.json'")
        text=text.replace("assert m['identity_key']=='shi_xiu' and m['character']=='zhu_wounded_v4_shi_xiu_gait_passing'", "assert m['character']=='zhu_wounded_v4_shi_xiu_gait_footclear'")
        text=text.replace('texture_bootstrap_shi_xiu_walk_passing_v4_run.json','texture_bootstrap_walk_footclear_v4_run.json')
        ast.parse(text)
    dest=H/f'unit_motion_shi_xiu_identity_v4.{suffix}'
    if dest.exists():assert dest.read_text(encoding='utf-8')==text
    else:dest.write_text(text,encoding='utf-8')
print('Separate Shi Xiu fixture prepared: same native footclear resource, additional per-frame identity assertions; not executed')
