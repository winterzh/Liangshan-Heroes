"""Correct depot destination semantics; preserve the rejected first mapping."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
proof=json.loads((HERE/'steampipe_mapping_prepared.json').read_bytes())
old=Path(proof['ascii_root']);root=old.parent/'steampipe_corrected';root.mkdir(exist_ok=False)
(root/'output').mkdir()
members=proof['files']
for row in members:
    p=old/'content'/row['path']
    with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256']
    assert p.stat().st_size==row['bytes']
depot='"DepotBuildConfig"\n{\n "DepotID" "5088121"\n'
for row in sorted(members,key=lambda r:r['path']):
    depot+=' "FileMapping" { "LocalPath" "'+row['path']+'" "DepotPath" "." "recursive" "0" }\n'
depot+='}\n';(root/'depot_5088121.vdf').write_text(depot,encoding='ascii')
for preview in (True,False):
    text='"AppBuild"\n{\n "AppID" "5088120"\n "Desc" "2026-10-28 Huangnigang transport and mission UI | source 47168f00"\n'
    text+=' "BuildOutput" "'+(root/'output').as_posix()+'"\n "ContentRoot" "'+(old/'content').as_posix()+'"\n'
    text+=' "Preview" "'+('1' if preview else '0')+'"\n "SetLive" ""\n "Depots" { "5088121" "'+(root/'depot_5088121.vdf').as_posix()+'" }\n}\n'
    (root/('app_preview.vdf' if preview else 'app_upload.vdf')).write_text(text,encoding='ascii')
record={'source_head':proof['source_head'],'rejected_build':'26260938','rejected_mapping':'DepotPath used a filename, producing filename/filename directories','rejected_build_activated':False,'corrected_vdf_root':str(root),'candidate_files_changed':False,'preview_semantic_acceptance_pending':True}
(HERE/'steampipe_mapping_correction.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
print(str(root))
