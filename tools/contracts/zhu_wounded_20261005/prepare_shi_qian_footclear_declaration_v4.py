"""Declare the unused old NE cell; preserve every runtime pose and native byte."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
original = ROOT / 'assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_v4.json'
dest = ROOT / 'assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_declared_v4.json'
m = json.loads(original.read_text(encoding='utf-8'))
assert len(m['sources']) == 15 and len(m['poses']) == 20
assert m['poses']['walk_a_ne']['source'] == 'shi_qian_walk_a_geometry_ne_v4'
m['sources']['shi_qian_walk_a_spacing_atlas_v4']['unused_regions'] = [{
    'region': [0, 627, 627, 627],
    'reason': 'Old NE contact A planted/swing foot insufficiently clear in actual Unit review; replaced by separately authored native walk_a_geometry_ne_v4.png. PNG retained untouched; other three atlas directions remain selected.'
}]
if dest.exists():
    assert json.loads(dest.read_text(encoding='utf-8')) == m
else:
    dest.write_text(json.dumps(m, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
check = json.loads(dest.read_text(encoding='utf-8'))
check['sources']['shi_qian_walk_a_spacing_atlas_v4'].pop('unused_regions')
assert check == json.loads(original.read_text(encoding='utf-8'))
print(json.dumps({'runtime_fields_identical': True, 'sources': 15, 'poses': 20}))
