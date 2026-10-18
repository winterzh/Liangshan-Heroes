"""Fixed torso-scale refinement; preserve v1 executed source and screenshots."""
from pathlib import Path
import ast
source=Path(__file__).with_name('render_rig_v1.py').read_text(encoding='utf-8')
old="matrix=[1,0,0,1,*delta];torso_region=region('torso',direction)"
new="torso_scale=.75;delta=sub(center,mul(torso_hip[direction],torso_scale))\n    matrix=[torso_scale,0,0,torso_scale,*delta];torso_region=region('torso',direction)"
assert old in source
source=source.replace(old,new)
source=source.replace("archive=Q/'browser_rig_v1'", "archive=Q/'browser_rig_v2'")
source=source.replace('杨林双腿分层首轮','杨林双腿分层比例调整')
source=source.replace("'boot_points':boot_points,'thigh_length':100", "'boot_points':boot_points,'torso_uniform_scale':.75,'thigh_length':100")
source=source.replace("'fixed_thigh_shin_lengths':[100,100]", "'fixed_thigh_shin_lengths':[100,100],'torso_uniform_scale':.75")
ast.parse(source)
exec(compile(source,__file__,'exec'))
