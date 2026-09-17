"""Zip only the verified EXE for Steamworks HTTP Depot upload; never uploads."""
from pathlib import Path
import hashlib,json,zipfile
BASE=Path(__file__).resolve().parent
build=json.loads((BASE/'build_receipt.json').read_text(encoding='utf8'))
verification=json.loads((BASE/'package_verification.json').read_text(encoding='utf8'))
review=json.loads((BASE/'visual_review.json').read_text(encoding='utf8'))
assert verification['passed'] and review['passed']
assert review['executable_sha256'] == build['sha256']
assert verification['sha256'] == build['sha256']
assert verification['source_commit'] == build['source_commit']
assert review['source_commit'] == build['source_commit']
assert verification['overlay_commit'] == review['overlay_commit'] == build['overlay_commit']
assert verification['source_manifest_sha256'] == review['source_manifest_sha256'] == build['source_manifest_sha256']
toggle = json.loads((BASE/'toggle_package_receipt.json').read_text(encoding='utf8'))
assert toggle['passed'] and toggle['checks'] == 115 and toggle['executable_sha256'] == build['sha256']
assert review['toggle_review_passed'] and review['toggle_report_sha256'] == toggle['report_sha256']
toggle_report = json.loads((BASE/'toggle/report.json').read_text(encoding='utf8'))
assert toggle_report['passed'] and toggle_report['checks'] == 115
assert hashlib.sha256((BASE/'toggle/report.json').read_bytes()).hexdigest() == toggle['report_sha256']
for sample in toggle_report['samples']:
    path = Path(sample['png'])
    assert path.resolve().parent == (BASE/'toggle').resolve()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == sample['sha256']
visual=json.loads((BASE/'visual/package_visual_capture.json').read_text(encoding='utf8'))
assert visual['passed'] and visual['mounted_pack_sha256'] == build['sha256']
assert len(review['captures']) == len(visual['captures']) == 2
for entry, original in zip(review['captures'], visual['captures']):
    path=BASE/entry['path']
    assert path.resolve().parent == (BASE/'visual').resolve()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'] == original['sha256']
exe=Path(build['executable']);assert hashlib.sha256(exe.read_bytes()).hexdigest()==build['sha256']
target=BASE/'windows'/'LiangshanHeroes-Windows-mission-panel-20260907.zip'
assert not target.exists(),'Refusing to overwrite a previous upload archive'
with zipfile.ZipFile(target,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    output.write(exe,arcname='LiangshanHeroes.exe')
with zipfile.ZipFile(target,'r') as archive:
    assert archive.namelist()==['LiangshanHeroes.exe']
    assert archive.testzip() is None
    member=archive.getinfo('LiangshanHeroes.exe')
    assert member.file_size==exe.stat().st_size
    with archive.open('LiangshanHeroes.exe') as stream:
        inside=hashlib.sha256(stream.read()).hexdigest()
    assert inside==build['sha256']
r={'passed':True,'kind':'steam_http_depot_single_executable_zip','source_commit':build['source_commit'],
   'overlay_commit':build['overlay_commit'],'source_tree_sha256':build['source_tree_sha256'],'source_manifest_sha256':build['source_manifest_sha256'],
   'executable':str(exe),'executable_size_bytes':exe.stat().st_size,'executable_sha256':inside,
   'executable_sha1':hashlib.sha1(exe.read_bytes()).hexdigest(),
   'zip':str(target),'zip_size_bytes':target.stat().st_size,'zip_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
   'zip_members':['LiangshanHeroes.exe'],'crc_verified':True,'inner_sha256_matches_export':True,
   'steam_app_id':5088120,'windows_depot_id':5088121,'uploaded':False}
(BASE/'upload_zip_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(r,ensure_ascii=False,indent=2))
