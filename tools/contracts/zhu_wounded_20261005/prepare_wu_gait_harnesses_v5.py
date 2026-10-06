"""Create new adapters without changing any previously executed QA producer."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
HARNESS=ROOT/'qa/zhu_wounded_20261005/harness'
src=HARNESS/'texture_bootstrap_deng_fei_v4.py'
text=src.read_text(encoding='utf-8')
text=text.replace("'deng_fei_walk_passing_v4'),default=", "'deng_fei_walk_passing_v4','wu_song_gait_v5'),default=")
text=text.replace("('upright_soldier_v3','character_traits_v4')", "('upright_soldier_v3','character_traits_v4','character_traits_v5')")
text=text.replace("'source_files':[],'steps':[],'godot_sha256':sha(engine)}", "'source_files':[],'steps':[],'godot_sha256':sha(engine),'producer_parent_sha256':'"+hashlib.sha256(src.read_bytes()).hexdigest()+"'}")
text=text.replace("locked=False\ntry:", "locked=False;child=None\ntry:")
text=text.replace("relative=s['path']+suffix;src=repo/relative;dst=project/relative;", "relative=s['path']+suffix;src=repo/relative;assert suffix or sha(src)==s['sha256'];dst=project/relative;")
text=text.replace("assert 'uid=\"uid://' in dst.read_text();shutil.copyfile(dst,src)", "assert 'uid=\"uid://' in dst.read_text()\n   # Retain previously qualified ordinary idle descriptor bytes.\n   if src.name != 'idle_spacing_v4.png.import':shutil.copyfile(dst,src)")
old=""" while running_engine():
  print('WAIT natural idle before releasing own native-import lease',flush=True);time.sleep(15)
 r['engine_remaining']=running_engine()
 if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run) and (not r['engine_remaining'] or (not r['steps'] and r.get('failure',{}).get('message')=='Engine appeared before own import step')):shared.LOCK.unlink()
"""
new=""" if child is not None and child.poll() is None:
  child.terminate();child.wait(timeout=15)
 r['owned_engine_remaining']=child is not None and child.poll() is None
 r['engine_remaining']=running_engine()
 if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run) and not r['owned_engine_remaining']:shared.LOCK.unlink()
"""
assert old in text;text=text.replace(old,new)
dest=HARNESS/'texture_bootstrap_wu_gait_v5.py';assert not dest.exists();compile(text,str(dest),'exec');dest.write_bytes(text.encode('utf-8'))
print(json.dumps({'new_harness':dest.relative_to(ROOT).as_posix(),'parent_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'parent_unchanged':True}))
