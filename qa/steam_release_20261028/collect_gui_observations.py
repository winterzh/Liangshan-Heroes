"""Archive named OS-input observations; never infer a playthrough from exit 0."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
run=ROOT/'.godot/steam_release_20261028/gui_101022_4032b476'
proof=json.loads((run/'receipt.json').read_bytes())
assert proof['complete'] and all(proof[k] for k in ('source_unchanged','players_unchanged','exe_unchanged','child_exit_confirmed','lock_released'))
dest=HERE/'gui_101022_4032b476'
dest.mkdir(exist_ok=False)
rows=[]
names=['receipt.json','launch.json','gui.console.log','gui.godot.log']
names += ['screenshots/'+p.name for p in sorted((run/'screenshots').glob('*.png'))]
for name in names:
    src=run/name; target=dest/name;target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(src,target)
    assert src.read_bytes()==target.read_bytes()
    rows.append({'path':target.relative_to(HERE).as_posix(),'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
record={'source_head':proof['source_head'],'candidate_exe_sha256':proof['exe_sha256'],
 'execution':'actual embedded-PCK release EXE, ordinary OS input; no gameplay driver',
 'scoped_interaction_passed':True,
 'observed':['main menu and eight-chapter menu','Huangnigang intro and deployment','F-key hero selection','right-click Liu Tang answer order and completion','Bai Sheng natural arrival and wine unloading','task view/select controls and task scroll','F11 fullscreen','Escape pause with task tooltip visible','normal quit confirmation and process exit'],
 'attempts':[{'result':'in-game defeat','reason':'Automation left the game running while editing the Steam announcement; rest timeout caused force route, then heroes fell. Result screen explicitly recorded the timeout. Retained as observed, not counted as a gameplay pass.'},{'result':'stopped normally while paused in wine phase','reason':'Scoped menu/input observations complete; no full manual wine/cargo completion claimed.'}],
 'manual_wine_and_seven_cart_completion_passed':False,'full_human_playthrough_passed':False,
 'transport_logic_evidence':'Existing Huangnigang production targeted PCK route and nine-phase suite, recorded separately; not relabelled as ordinary EXE playthrough.',
 'files':rows}
(HERE/'gui_observations.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'scoped_interaction_passed':True,'manual_full_route_passed':False,'files':len(rows)}))
