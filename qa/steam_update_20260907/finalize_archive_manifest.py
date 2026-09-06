"""Hash this build agent's explicit evidence allowlist; exclude parallel work."""
from pathlib import Path
import hashlib,json
BASE=Path(__file__).resolve().parent
NAMES='''README.md
build_progress.json
build_receipt.json
build_windows.py
contract.console.log
export.log
freeze_snapshot.py
import.log
package_contract.gd
package_contract.json
package_expected.json
package_verification.json
package_verification_progress.json
package_visual_capture.gd
prepare_upload_zip.py
run_package_smoke.py
smoke_driver.console.log
source_manifest.json
source_verification.json
upload_zip_receipt.json
verify_package.py
visual.console.log
visual_review.json
finalize_archive_manifest.py'''.splitlines()
paths=[BASE/name for name in NAMES]
paths += [BASE/'smoke'/(name+suffix) for name in ['level'+str(i) for i in range(1,9)]+['defense','cleanup','main_menu'] for suffix in ['.console.log','.godot.log']]
paths += [BASE/'smoke/package_smoke.json',BASE/'visual/package_main_menu_1280x720.png',BASE/'visual/package_liangshan_defense_1280x720.png',BASE/'visual/package_visual_capture.json']
rows=[{'path':p.relative_to(BASE).as_posix(),'size_bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(paths)]
r={'source_commit':'443e75e887afd76f9569cae17b0527a72408aedc','file_count':len(rows),'total_bytes':sum(row['size_bytes'] for row in rows),'files':rows,
   'excluded_directories':['source','project','userdata','windows'],
   'scope':'This build agent evidence only. Root task Git merge/Steam receipts are separate and may be archived by their owner.'}
(BASE/'archive_manifest.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'file_count':len(rows),'total_bytes':r['total_bytes']},ensure_ascii=False))
