"""Extract the verified six-member ZIP into a new ASCII SteamPipe directory."""
from pathlib import Path
import hashlib,json,zipfile
HERE=Path(__file__).resolve().parent
proof=json.loads((HERE/'candidate_delivery.json').read_bytes())
assert proof['complete'] and proof['member_count']==6
archive=Path(proof['archive']['upload_copy'])
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
assert sha(archive)==proof['archive']['sha256']
root=Path('D:/CodexTemp/lsh_rel_20261028/steampipe')
root.mkdir(exist_ok=False);content=root/'content';content.mkdir();(root/'output').mkdir()
members={r['path']:r for r in proof['members']}
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist())==set(members) and len(z.namelist())==6
    for name,row in members.items():
        assert '/' not in name and '\\' not in name
        target=content/name
        with z.open(name) as src,target.open('xb') as dst:
            import shutil
            shutil.copyfileobj(src,dst)
        assert target.stat().st_size==row['bytes'] and sha(target)==row['sha256']
depot='"DepotBuildConfig"\n{\n "DepotID" "5088121"\n'
for name in sorted(members):
    depot+=' "FileMapping" { "LocalPath" "'+name+'" "DepotPath" "'+name+'" "recursive" "0" }\n'
depot+='}\n'
(root/'depot_5088121.vdf').write_text(depot,encoding='ascii')
for preview in (True,False):
    text='"AppBuild"\n{\n "AppID" "5088120"\n "Desc" "2026-10-28 Huangnigang transport and mission UI | source 47168f00"\n'
    text+=' "BuildOutput" "'+(root/'output').as_posix()+'"\n "ContentRoot" "'+content.as_posix()+'"\n'
    text+=' "Preview" "'+('1' if preview else '0')+'"\n "SetLive" ""\n "Depots" { "5088121" "'+(root/'depot_5088121.vdf').as_posix()+'" }\n}\n'
    (root/('app_preview.vdf' if preview else 'app_upload.vdf')).write_text(text,encoding='ascii')
record={'complete':True,'scope':'local SteamPipe mapping preparation only','source_head':proof['source_head'],
 'archive_sha256':proof['archive']['sha256'],'ascii_root':str(root),'files':proof['members'],
 'member_count':6,'set_live':'','uploaded':False,'preview_passed':False,
 'vdfs':[{'name':p.name,'sha256':sha(p)} for p in sorted(root.glob('*.vdf'))]}
(HERE/'steampipe_mapping_prepared.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
print(json.dumps({'complete':True,'files':6,'root':str(root)}))
