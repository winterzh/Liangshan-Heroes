"""Low-boot overlap comparison; fixed scale and old evidence retained."""
from pathlib import Path
import ast
source=Path(__file__).with_name('render_rig_v1.py').read_text(encoding='utf-8')
source=source.replace('preview_sources_v2.json','preview_sources_v3.json')
old="matrix=[1,0,0,1,*delta];torso_region=region('torso',direction)"
new="torso_scale=.75;delta=sub(center,mul(torso_hip[direction],torso_scale))\n    matrix=[torso_scale,0,0,torso_scale,*delta];torso_region=region('torso',direction)"
assert old in source;source=source.replace(old,new)
boot_points={'right':{'se':{'ankle':[132,373],'sole':[164,478]},'sw':{'ankle':[517,373],'sole':[475,478]},
                      'ne':{'ankle':[774,396],'sole':[806,462]},'nw':{'ankle':[1126,396],'sole':[1086,461]}},
             'left':{'se':{'ankle':[132,915],'sole':[166,1011]},'sw':{'ankle':[518,915],'sole':[477,1011]},
                     'ne':{'ankle':[774,942],'sole':[805,1008]},'nw':{'ankle':[1125,943],'sole':[1087,1008]}}}
assert '\ndef region(' in source
source=source.replace('\ndef region(', '\nboot_points='+repr(boot_points)+'\ndef region(')
source=source.replace("archive=Q/'browser_rig_v1'", "archive=Q/'browser_rig_v3'")
source=source.replace('杨林双腿分层首轮','杨林双腿分层低靴调整')
source=source.replace("'boot_points':boot_points,'thigh_length':100", "'boot_points':boot_points,'torso_uniform_scale':.75,'thigh_length':100")
source=source.replace("'fixed_thigh_shin_lengths':[100,100]", "'fixed_thigh_shin_lengths':[100,100],'torso_uniform_scale':.75")
ast.parse(source)
exec(compile(source,__file__,'exec'))
