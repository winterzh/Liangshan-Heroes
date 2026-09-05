"""Verify the isolated Steam default download and launch its actual release EXE."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess

QA = Path(__file__).resolve().parent
DOWNLOAD = Path(os.environ['LIANGSHAN_SERVER_DOWNLOAD'])
UPLOAD = Path(os.environ['LIANGSHAN_UPLOAD_EXE'])
EXPECTED_SHA = 'b333e117755c0a33fbbc5731fd3768514a68fce21c5e45dc730f38dd138bbfc1'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

if __name__ == '__main__':
    acf_path = DOWNLOAD / 'steamapps/appmanifest_5088120.acf'
    acf = acf_path.read_text(encoding='utf8')
    def value(key):
        matches = re.findall(r'"'+re.escape(key)+r'"\s+"([^"\r\n]+)"', acf)
        assert len(matches) == 1, (key, matches)
        return matches[0]
    assert value('StateFlags') == '4'
    assert value('buildid') == '25136463'
    assert value('TargetBuildID') == '25136463'
    assert '"7280684617482783161"' in acf
    assert value('UpdateResult') == '0'
    exe = DOWNLOAD / 'LiangshanHeroes.exe'
    assert exe.stat().st_size == UPLOAD.stat().st_size == 278050128
    assert sha(exe) == sha(UPLOAD) == EXPECTED_SHA
    env = os.environ.copy()
    for key in ('SMOKE_TEST','LEVEL','SKIRMISH','SKIRMISH_AI','SCREENSHOT_DIR','DEFENSE_HARD_FIX_TEST','FINAL_CLEANUP_TEST'):
        env.pop(key,None)
    env['APPDATA'] = os.environ.get('LIANGSHAN_SERVER_TEST_DATA', str(QA / 'server_download_user_data'))
    command = [str(exe),'--headless','--max-fps','60','--quit-after','180','--log-file',str(QA/'server_main_menu.log')]
    completed = subprocess.run(command,cwd=str(DOWNLOAD),env=env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    output = (completed.stdout + completed.stderr).decode('utf8','replace')
    (QA/'server_main_menu.console.log').write_text(output,encoding='utf8')
    errors = re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$',output,re.M)
    assert completed.returncode == 0 and not errors, (completed.returncode,errors)
    report = {'passed':True,'app_id':5088120,'build_id':25136463,'depot_id':5088121,
              'manifest_id':'7280684617482783161','state_flags':4,'update_result':0,'target_build_id':25136463,
              'download_root':str(DOWNLOAD),'executable':str(exe),'size_bytes':exe.stat().st_size,
              'sha256':sha(exe),'upload_sha256':sha(UPLOAD),'sha256_matches_upload':True,
              'main_menu_exit_code':completed.returncode,'log_errors':errors,'command':command,
              'local_steam_client_verified':False,'formal_release_executed':False,'announcement_published':False}
    (QA/'server_download_verified.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report,ensure_ascii=False))
