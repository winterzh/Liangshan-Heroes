from pathlib import Path
import hashlib, json, re
BASE = Path(__file__).resolve().parents[1] / '.godot/steam_update_20260907'
build = json.loads((BASE/'build_receipt.json').read_text(encoding='utf8'))
capture = json.loads((BASE/'visual/package_visual_capture.json').read_text(encoding='utf8'))
assert capture['passed'] and capture['mounted_pack_sha256'] == build['sha256']
assert not (BASE/'visual_review.json').exists()
notes = [
 'Opened actual 1280x720 viewport PNG. Full title, six menu entries, labels, background, fullscreen control and v1.8 badge render without blocked controls.',
 'Opened actual 1280x720 defense viewport PNG. Hall, gates, wall, units, resources, minimap and introduction render. Black region is fog; empty unit panel has no selected unit. Short startup FPS label is not performance evidence.'
]
rows=[]
for image, note in zip(capture['captures'], notes):
    p=Path(image['path'])
    digest=hashlib.sha256(p.read_bytes()).hexdigest()
    assert digest == image['sha256']
    rows.append({'path':p.relative_to(BASE).as_posix(), 'sha256':digest, 'result':note})
review={'passed':True, 'reviewer':'Codex root', 'review_method':'Opened both actual current embedded-PCK Vulkan viewport PNGs using view_image',
 'source_commit':build['source_commit'], 'executable_sha256':build['sha256'], 'human_playtest':False, 'captures':rows,
 'scope':'Package visual startup completeness only; no full campaign, 30 waves, long-duration or performance acceptance.'}
(BASE/'visual_review.json').write_text(json.dumps(review,indent=2)+'\n',encoding='utf8')
logs=[BASE/name for name in ['import.log','export.log','contract.console.log','smoke_driver.console.log','visual.console.log']]
logs+=list((BASE/'smoke').glob('*.log'))
errors=[]
for p in logs:
    for line in p.read_text(encoding='utf8',errors='strict').splitlines():
        if re.search(r'SCRIPT ERROR|Parse Error|ERROR:|WARNING:|Failed loading resource|Assertion failed',line):
            errors.append({'path':p.relative_to(BASE).as_posix(),'line':line})
assert not errors, errors
(BASE/'strict_log_review.json').write_text(json.dumps({'passed':True,'source_commit':build['source_commit'],'executable_sha256':build['sha256'],'logs_checked':[p.relative_to(BASE).as_posix() for p in logs],'errors':errors},indent=2)+'\n',encoding='utf8')
print(json.dumps({'visual_review':True,'logs':len(logs),'errors':len(errors)}))
