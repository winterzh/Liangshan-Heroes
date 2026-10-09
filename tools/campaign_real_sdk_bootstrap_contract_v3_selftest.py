"""CPU/own-file contract regression corpus, never native or SDK evidence."""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import uuid

from campaign_real_sdk_bootstrap_contract_v3 import (
    ContractError, decode_descriptor, isolated_environment, no_links,
    read_descriptor, validate_descriptor,
)


def run(work_root: Path) -> dict:
    no_links(work_root)
    root = Path(__file__).resolve().parents[1]
    assert work_root.is_absolute() and not work_root.resolve().is_relative_to(root.resolve())
    run_root = work_root / ('contract_' + uuid.uuid4().hex)
    no_links(run_root)
    run_root.mkdir(parents=True, exist_ok=False)
    profile = run_root / 'profile'
    profile.mkdir()
    for key in ('appdata', 'localappdata', 'temp', 'tmp'):
        (profile / key).mkdir()
    # This fake binary is ONLY data for physical SHA counterexamples. Never Popen.
    executable = run_root / 'synthetic_not_executable.bin'
    executable.write_bytes(b'CPU_ONLY_FAKE_EXPORT_BYTES\n')
    exe_sha = hashlib.sha256(executable.read_bytes()).hexdigest()
    identity = {
        'ok': True, 'code': 'OK', 'identity_schema': 1, 'identity_scope': 'installed_inputs',
        'content_version': 'source-v1:' + 'a'*64, 'source_sha256': 'a'*64,
        'engine_binary_sha256': exe_sha, 'source_mode': False, 'save_eligible': True,
        'save_code': 'OK', 'rules_sha256': 'b'*64, 'file_count': 1, 'total_bytes': 1,
        'provider_sha256': 'c'*64, 'optional_content': [
            {'path': p, 'present': False, 'bytes': 0, 'sha256': ''}
            for p in ('content/units.json', 'content/abilities.json')],
    }
    user = profile / 'appdata' / 'Godot' / 'app_userdata' / 'synthetic_contract_fixture'
    nonce = uuid.uuid4().hex
    descriptor = {
        'schema': 'campaign_real_sdk_bootstrap_descriptor_v2', 'case': 'bootstrap_only',
        'nonce': nonce, 'private_user_directory': str(user), 'executable': str(executable),
        'executable_sha256': exe_sha, 'installed_identity': identity,
        'expected_account': '1', 'normal_startup_account_side_effects_acknowledged': True,
        'private_windows_roots': {k:str(profile/k.lower()) for k in ('APPDATA','LOCALAPPDATA','TEMP','TMP')},
    }
    def encode(value):
        return (json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
    args = dict(expected_nonce=nonce, expected_account='1', executable=executable,
                executable_sha256=exe_sha, user_directory=user, installed_identity=identity, profile=profile)
    checks = []
    def rejects(label, callback):
        try:
            callback()
        except (ContractError, OSError):
            checks.append({'label': label, 'rejected': True})
        else:
            raise AssertionError('unexpected acceptance: '+label)
    raw = encode(descriptor)
    path = run_root / 'descriptor.json'
    path.write_bytes(raw)
    value, original = read_descriptor(path, hashlib.sha256(raw).hexdigest())
    assert original == raw and value == descriptor
    validate_descriptor(value, **args)
    rejects('duplicate root key', lambda: decode_descriptor(raw[:-2]+b',"case":"bootstrap_only"}\n'))
    rejects('duplicate nested key', lambda: decode_descriptor(raw.replace(b'"file_count": 1',b'"file_count": 1, "file_count": 1')))
    rejects('malformed utf8', lambda: decode_descriptor(b'{"schema":"\xff"}'))
    rejects('utf8 BOM', lambda: decode_descriptor(b'\xef\xbb\xbf'+raw))
    rejects('NaN', lambda: decode_descriptor(raw.replace(b'"file_count": 1',b'"file_count": NaN')))
    rejects('Infinity', lambda: decode_descriptor(raw.replace(b'"file_count": 1',b'"file_count": Infinity')))
    rejects('overflowed JSON exponent', lambda: decode_descriptor(raw.replace(b'"file_count": 1',b'"file_count": 1e999')))
    rejects('escaped unpaired surrogate', lambda: decode_descriptor(raw.replace(b'"case": "bootstrap_only"',b'"case": "\\ud800"')))
    rejects('over budget', lambda: decode_descriptor(b' ' * 1048577))
    rejects('deep JSON nesting', lambda: decode_descriptor(b'['*2000+b'0'+b']'*2000))
    rejects('overlong JSON integer', lambda: decode_descriptor(raw.replace(b'"file_count": 1',b'"file_count": '+b'1'*5000)))
    rejects('wrong original descriptor pin', lambda: read_descriptor(path, '0'*64))
    for label, key, new in [
        ('unknown field','extra',0),('other case','case','cloud_retry'),
        ('side effect numeric','normal_startup_account_side_effects_acknowledged',1),
        ('nonce differs','nonce','f'*32),('owner numeric','expected_account',1),
        ('owner differs','expected_account','2'),('wrong binary SHA','executable_sha256','0'*64),
        ('outside user directory','private_user_directory',str(run_root / 'ordinary')),
    ]:
        bad = deepcopy(descriptor);bad[key] = new
        rejects(label, lambda bad=bad: validate_descriptor(bad, **args))
    for label, key, new in [
        ('identity schema bool','identity_schema',True),('source mode','source_mode',True),
        ('file count bool','file_count',True),('file count fractional','file_count',1.5),
        ('empty source SHA','source_sha256',''),('wrong identity engine','engine_binary_sha256','0'*64),
        ('source version drift','content_version','source-v1:'+'d'*64),
        ('optional rows incomplete','optional_content',[]),
    ]:
        bad=deepcopy(descriptor);bad['installed_identity'][key]=new
        rejects(label, lambda bad=bad: validate_descriptor(bad, **args))
    for label,new in [('missing private root',{}),('outside private roots',{'APPDATA':str(run_root/'outside'),'LOCALAPPDATA':str(profile/'localappdata'),'TEMP':str(profile/'temp'),'TMP':str(profile/'tmp')})]:
        bad=deepcopy(descriptor);bad['private_windows_roots']=new
        rejects(label,lambda bad=bad:validate_descriptor(bad,**args))
    bad=deepcopy(descriptor);bad['installed_identity']['optional_content'][0]['present']=1
    rejects('optional present numeric',lambda: validate_descriptor(bad,**args))
    inherited={'Path':'synthetic_path','screenshot_dir':'autostart','STEAM_DISABLED':'1',
               'LSH_OLD_DESCRIPTOR':'old','CAMPAIGN_QA':'1','OTHER_TEST':'x','TEMP':'outside'}
    env=isolated_environment(inherited,profile=profile,user_directory=user,
                             descriptor_path=path,descriptor_sha256=hashlib.sha256(raw).hexdigest())
    assert env['Path']=='synthetic_path' and 'STEAM_DISABLED' not in env
    assert all(key.upper() not in ('SCREENSHOT_DIR','CAMPAIGN_QA','OTHER_TEST','LSH_OLD_DESCRIPTOR') for key in env)
    assert all(env[key]==str(profile/key.lower()) for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'))
    rejects('case alias environment',lambda: isolated_environment({'Path':'a','PATH':'b'},profile=profile,user_directory=user,descriptor_path=path,descriptor_sha256='a'*64))
    rejects('private userdata outside profile',lambda: isolated_environment({},profile=profile,user_directory=run_root/'ordinary',descriptor_path=path,descriptor_sha256='a'*64))
    (profile/'temp'/'occupied.txt').write_bytes(b'owned corpus')
    rejects('nonempty private root',lambda: isolated_environment({},profile=profile,user_directory=user,descriptor_path=path,descriptor_sha256='a'*64))
    import _winapi
    target=run_root/'owned_junction_target'
    junction=run_root/'owned_dangling_junction'
    target.mkdir()
    _winapi.CreateJunction(str(target),str(junction))
    # Remove only this verified own empty target, never the junction or a tree.
    assert target.resolve().is_relative_to(run_root.resolve())
    no_links(target)
    target.rmdir()
    assert not junction.exists() and not junction.is_symlink()
    assert junction.lstat().st_file_attributes & 0x400
    rejects('actual Windows dangling junction',lambda: no_links(junction))
    rejects('child under actual dangling junction',lambda: no_links(junction/'missing_child'))
    executable.write_bytes(b'changed fake corpus bytes')
    rejects('physical binary drift',lambda: validate_descriptor(descriptor,**args))
    path.write_bytes(raw+b' ')
    rejects('physical descriptor drift',lambda: read_descriptor(path,hashlib.sha256(raw).hexdigest()))
    report={'schema':'real_sdk_bootstrap_contract_cpu_regression_v3','passed':True,
            'accepted_synthetic_shape_and_file_pin':True,'rejection_count':len(checks),
            'rejections':checks,'isolated_env_constructed_only':True,'actual_dangling_junction_fixture_retained':str(junction),
            'synthetic_account_and_binary_are_not_SDK_evidence':True,
            'native_started':False,'SDK_account_qualified':False,'overall_goal_qualified':False,
            'run':str(run_root)}
    (run_root/'report.json').write_bytes(encode(report))
    return report


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--work-root',required=True,type=Path)
    result=run(parser.parse_args().work_root)
    print(json.dumps(result,ensure_ascii=False))
