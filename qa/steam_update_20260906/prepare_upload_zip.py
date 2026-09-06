"""Zip only the verified EXE for Steamworks HTTP Depot upload; never uploads."""
from pathlib import Path
import hashlib,json,zipfile
BASE=Path(__file__).resolve().parent
build=json.loads((BASE/'build_receipt.json').read_text(encoding='utf8'))
verification=json.loads((BASE/'package_verification.json').read_text(encoding='utf8'))
review=json.loads((BASE/'visual_review.json').read_text(encoding='utf8'))
assert verification['passed'] and review['passed']
exe=Path(build['executable']);assert hashlib.sha256(exe.read_bytes()).hexdigest()==build['sha256']
target=BASE/'windows'/'LiangshanHeroes-Windows-20260906.zip'
assert not target.exists(),'Refusing to overwrite a previous upload archive'
with zipfile.ZipFile(target,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    output.write(exe,arcname='LiangshanHeroes.exe')
with zipfile.ZipFile(target,'r') as archive:
    assert archive.namelist()==['LiangshanHeroes.exe']
    assert archive.testzip() is None
    member=archive.getinfo('LiangshanHeroes.exe')
    assert member.file_size==exe.stat().st_size
    with archive.open('LiangshanHeroes.exe') as stream:
        inside=hashlib.file_digest(stream,'sha256').hexdigest()
    assert inside==build['sha256']
r={'passed':True,'kind':'steam_http_depot_single_executable_zip','source_commit':build['source_commit'],
   'executable':str(exe),'executable_size_bytes':exe.stat().st_size,'executable_sha256':inside,
   'executable_sha1':hashlib.sha1(exe.read_bytes()).hexdigest(),
   'zip':str(target),'zip_size_bytes':target.stat().st_size,'zip_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
   'zip_members':['LiangshanHeroes.exe'],'crc_verified':True,'inner_sha256_matches_export':True,
   'steam_app_id':5088120,'windows_depot_id':5088121,'uploaded':False}
(BASE/'upload_zip_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(r,ensure_ascii=False,indent=2))
