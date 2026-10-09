"""Prepare six frozen files and Preview/upload VDFs after the collector passes."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT=Path('D:/AI项目/水浒/开发工程')
QA=ROOT/'qa/steam_release_20261009'
BASE=Path(__file__).parent
delivery=json.loads((QA/'candidate_delivery.json').read_bytes())
assert delivery['complete'] is True and delivery['source_head']=='6d3bab21189a1bd74d22a88238e9474fe22f98cb'
archive=BASE/'transfer/LiangshanHeroes_Steam_candidate.zip'
assert archive.is_file()
sha=lambda raw:hashlib.sha256(raw).hexdigest()
assert archive.stat().st_size==delivery['archive']['bytes'] and sha(archive.read_bytes())==delivery['archive']['sha256']
members={r['path']:r for r in delivery['members']}
names={'LiangshanHeroes.exe','libgodotsteam.windows.template_release.x86_64.dll','steam_api64.dll','steam_stats_reader.dll','GODOTSTEAM_LICENSE.txt','STEAM_STATS_READER_GODOT_CPP_LICENSE.txt'}
assert set(members)==names
content=BASE/'transfer/content'
content.mkdir(exist_ok=False)
with zipfile.ZipFile(archive) as package:
    assert len(package.namelist())==6 and set(package.namelist())==names
    for name in sorted(names):
        raw=package.read(name);row=members[name]
        assert len(raw)==row['bytes'] and sha(raw)==row['sha256']
        assert hashlib.sha1(raw).hexdigest()==row['sha1']
        with (content/name).open('xb') as out:out.write(raw)
pipe=BASE/'pipe';pipe.mkdir(exist_ok=False)
mappings='\n'.join('    "FileMapping" { "LocalPath" "%s" "DepotPath" "." "Recursive" "0" }'%name for name in sorted(names))
depot='"DepotBuild"\n{\n    "DepotID" "5088121"\n'+mappings+'\n}\n'
(pipe/'depot_5088121.vdf').write_text(depot,encoding='ascii')
for mode,preview in [('preview','1'),('upload','0')]:
    text='"AppBuild"\n{\n    "AppID" "5088120"\n    "Desc" "2026-10-09 Local save validation and scenery maintenance | source 6d3bab21"\n    "Preview" "'+preview+'"\n    "ContentRoot" "'+content.as_posix()+'"\n    "BuildOutput" "'+(BASE/('output_'+mode)).as_posix()+'"\n    "Depots"\n    {\n        "5088121" "'+(pipe/'depot_5088121.vdf').as_posix()+'"\n    }\n}\n'
    (pipe/('app_'+mode+'.vdf')).write_text(text,encoding='ascii')
record={'schema':'company_steam_pipe_transport_preparation_v1','complete':True,'source_head':delivery['source_head'],
        'archive_sha256':delivery['archive']['sha256'],'content':str(content),'members':delivery['members'],
        'preview_vdf':str(pipe/'app_preview.vdf'),'upload_vdf':str(pipe/'app_upload.vdf'),
        'uploaded':False,'default_switched':False,'credentials_in_VDF':False}
with (BASE/'transport_preparation.json').open('x',encoding='utf-8') as out:json.dump(record,out,ensure_ascii=False,indent=2);out.write('\n')
print(json.dumps({'prepared_members':6,'uploaded':False,'content':str(content)}))
