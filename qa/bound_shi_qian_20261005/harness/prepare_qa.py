from pathlib import Path
import subprocess,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
p=repo/'scripts/campaign_art.gd';s=p.read_text(encoding='utf-8');assert 'const NATIVE_BOUND_VARIANTS := {"bound_qin_ming": "qin_ming"}' in s
s=s.replace('const NATIVE_BOUND_VARIANTS := {"bound_qin_ming": "qin_ming"}','const NATIVE_BOUND_VARIANTS := {"bound_qin_ming": "qin_ming", "bound_shi_qian": "shi_qian"}')
p.write_text(s,encoding='utf-8',newline='')
# Dedicated current-stage QA preserves older generic facing/animation semantics.
s=(repo/'tools/qin_ming_bound_qa.gd').read_text(encoding='utf-8').replace('bound_qin_ming','bound_shi_qian').replace('qin_ming','shi_qian').replace('Qin','Shi Qian').replace('qin_','shi_')
s=s.replace('level.prisoners[2]','level.prisoners[0]')
s=s.replace('ca.NATIVE_BOUND_VARIANTS=={"bound_shi_qian":"shi_qian"}','ca.native_bound_owner("bound_qin_ming")=="qin_ming"')
s=s.replace('registry isolated to Shi Qian and portrait owner retained','registry owns Shi Qian and preserves native Qin owner')
s=s.replace('"res://assets/characters/hero_portraits_aligned_20260926/shi_qian.png"','"res://assets/portraits18.png"')
s=s.replace('if p.key in ["shi_qian","shi_xiu"]: continue','if p.key in ["shi_qian","shi_xiu","qin_ming"]: continue')
s=s.replace(' and u._frame_directional,"same rescued actor resumes generic authored walk ',' and u._frame_directional==art.unit_anim_uses_directional_source("shi_qian","walk",d),"same rescued actor resumes existing generic walk/facing ')
s=s.replace('\t# Separate obsolete three-day compatibility fixture; not current rescue proof.\n\tawait _shi_bound_priority(b)\n\tart_runtime.append({"case":"legacy_shi_bind_release_compatibility","actor_injected":true,"scope":"old three-day appearance API only"})\n','')
# Regression: previously accepted native Qin and its UI must remain isolated.
needle='\tvar song = level.song\n'
extra='''\tvar qin = level.prisoners[2]
\tfor d in ART_DIRS:
\t\tvar qin_frames: Array = art.unit_anim_frames("qin_ming","idle",d,"bound_qin_ming")
\t\tcheck(qin_frames.size()==1 and _texture_source(qin_frames[0])=="res://assets/characters/qin_ming_bound_20261005/bound.png" and art.unit_anim_uses_directional_source("qin_ming","idle",d,"bound_qin_ming"),"native Qin captive route retained "+d)
\tcheck(_texture_source(qin.ui_portrait_texture())=="res://assets/characters/hero_portraits_aligned_20260926/qin_ming.png","Qin captive portrait retained")
'''
assert needle in s;s=s.replace(needle,extra+needle)
(repo/'tools/shi_qian_bound_qa.gd').write_text(s,encoding='utf-8',newline='\n')
s=(repo/'tools/run_qin_ming_bound_qa.py').read_text(encoding='utf-8').replace('qin_ming','shi_qian').replace('Qin','Shi Qian').replace('qin_current','shi_current').replace('qin_bound_current','shi_bound_current').replace('qin_rescued_current','shi_rescued_current')
s=s.replace("r['checks']>=95","r['checks']>=95")
(repo/'tools/run_shi_qian_bound_qa.py').write_text(s,encoding='utf-8',newline='\n')
# The Qin registry assertion should check ownership rather than ban future captives.
p=repo/'tools/qin_ming_bound_qa.gd';s=p.read_text(encoding='utf-8').replace('ca.NATIVE_BOUND_VARIANTS=={"bound_qin_ming":"qin_ming"}','ca.native_bound_owner("bound_qin_ming")=="qin_ming"');p.write_text(s,encoding='utf-8',newline='\n')
bootstrap=(base/'texture_bootstrap.py').read_text(encoding='utf-8').replace('import sys,json,subprocess,hashlib,shutil,uuid,os','import sys,json,subprocess,hashlib,shutil,uuid,os,time')
bootstrap=bootstrap.replace("if running_engine() or shared.LOCK.exists():raise RuntimeError('Shared engine/lock occupied')","while running_engine():\n print('WAIT natural shared-engine idle for native import',flush=True);time.sleep(15)\nif shared.LOCK.exists():raise RuntimeError('Shared QA lock occupied; inspect owner')")
bootstrap=bootstrap.replace("  if running_engine():raise RuntimeError('Engine appeared before own import step')","  while running_engine():\n   print('WAIT natural shared-engine idle before '+label,flush=True);time.sleep(15)")
bootstrap=bootstrap.replace(" r['engine_remaining']=running_engine()"," while running_engine():\n  print('WAIT natural idle before releasing own native-import lease',flush=True);time.sleep(15)\n r['engine_remaining']=running_engine()")
(base/'texture_bootstrap.py').write_text(bootstrap,encoding='utf-8')
print('Native Shi registry and current-RTS QA prepared; old generic walk unchanged')
