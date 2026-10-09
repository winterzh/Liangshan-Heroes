"""Preserve exact single-change edit request for the rejected opposite contact."""
from pathlib import Path
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
dest = HERE / 'requests/lin_chong_walk_b_se2_v5.json'
assert not dest.exists()
args = {
    'transparent_background': True,
    'referenced_image_paths': [
        str(ROOT / 'assets/characters/lin_chong_traits_20261006/walk_a_se_v5.png'),
        str(HERE / 'guides/qin_ming_walk_b_se_geometry_v4.png'),
    ],
    'prompt': (
        'Edit the leg phase ONLY of reference1 Lin Chong. Keep his exact upright adult upper body, face, '
        'head/hair, blue scarf/robe, gold-edged steel armor, waist, arms and single low diagonal spear '
        'with red tassel unchanged, same elevated SE front-three-quarter view and transparent square '
        'canvas. Reference1 is contact A: its IMAGE-RIGHT leg is long and bears weight, its IMAGE-LEFT '
        'leg is bent back with a raised boot. We need the OPPOSITE contact B, not another A. '
        'Exchange those two LEG roles anatomically: IMAGE-LEFT leg must now extend FORWARD and DOWN '
        'to an unmistakable FLAT planted boot at the lowest ground level near lower-left; IMAGE-RIGHT '
        'leg bends slightly BACK with its boot low raised and trailing near upper-right. Both legs '
        'still attach to their own hip, never cross or twist. Reference2 is geometry ONLY: copy its '
        'RED IMAGE-LEFT extended flat support leg and BLUE IMAGE-RIGHT bent raised leg positions. '
        'Do not copy robot/colors/green platform/text. Natural adult knees, no deep squat, no hunch, '
        'no both feet flat, no missing leg. Adjust only lower robe drape as physically necessary '
        'for the opposite leg phase. Preserve one complete adult man and one spear, style, scale '
        'and generous transparent margins, native RGBA PNG<=1536. No floor/shadow/grid/background.'
    ),
}
dest.write_bytes((json.dumps(args, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
print(dest.relative_to(ROOT).as_posix())
