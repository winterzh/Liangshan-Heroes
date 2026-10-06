"""Prepare a phase-capture runner using the frozen production wrapper protocol."""
from pathlib import Path
import ast,hashlib,json
ROOT=Path(__file__).resolve().parents[3];H=ROOT/'qa/zhu_wounded_20261005/harness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    src=H/'run_ordinary_continuous_gait_v15b.py';text=src.read_text(encoding='utf-8')
    text=text.replace('ordinary_continuous_gait_v15b','ordinary_skill_clearance_v16').replace('expected_captures\':70','expected_captures\':112')
    old="len(result['screenshots'])==70";assert text.count(old)==1;text=text.replace(old,"len(result['screenshots'])==112")
    text=text.replace("out=run/'gait'","out=run/'skills'").replace("('gait',[","('skills',[")
    text=text.replace('>1200:reason=', '>1800:reason=')
    old='Actual original actors and normal continuous movement, no subject physics or animation freeze; existing terrain placement, nonparticipants frozen, fog off and camera zoom fixtures. Three desktop window sizes. Not continuous skill/death, natural chapter/save/performance/export or Android qualification.'
    new='Seven active abilities, four headings, actual normal-clock mid/late cast physics phases, late phase at three desktop sizes. Original actors restored legally to level6 and learned rank1; actor frozen only after reaching requested phase for native views. Clear-terrain contact placement, frozen nonparticipants, fog-off/camera and derived atmosphere refresh fixtures. Not continuous cast playback, natural leveling, full chapter/save/performance/export or Android qualification.'
    assert old in text;text=text.replace(old,new)
    text=text.replace('Frozen current production continuous gait and three desktop viewport sizes.','Frozen current production mid/late skill phases and three desktop viewport sizes.')
    ast.parse(text);p=H/'run_ordinary_skill_clearance_v16.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'prepared':True,'expected_captures':112,'parent':src.relative_to(ROOT).as_posix(),'parent_sha256':sha(src),'runner_sha256':sha(p),'executed':False}))
if __name__=='__main__':main()
