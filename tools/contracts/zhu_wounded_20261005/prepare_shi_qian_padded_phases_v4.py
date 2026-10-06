"""Preserve stricter cell-layout requests after native first-A boundary failure."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
for phase in ('walk_b','passing_a','passing_b'):
    source=HERE/f'requests/shi_qian_{phase}_traits_atlas_v4.json'
    request=json.loads(source.read_text(encoding='utf-8'))
    request['prompt']+='''\nCRITICAL CELL LAYOUT OVERRIDES ANY LARGER FIGURE FRAMING: on1254x1254 native canvas each cell is627square. Render each complete silhouette only450–470pixels tall, including headcloth and both boots. Top figures must be wholly within y80..550, bottom figures within y710..1180; keep at least70px clear padding at every cell edge. Center top-left at(313,313), top-right(940,313), bottom-left(313,940), bottom-right(940,940). No toe/cloth/hand crosses x627 or y627. All four complete bodies and their adult head/limb proportions remain unchanged internally; reduce their native rendered occupancy in each cell, not their leg length. This must match the spaced contact-A sheet's framing and retain its alert adult charcoal style.'''
    dest=HERE/f'requests/shi_qian_{phase}_padded_atlas_v4.json'
    if dest.exists():assert json.loads(dest.read_text(encoding='utf-8'))==request
    else:dest.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'stricter_phase_requests':3,'original_requests_preserved':True}))
