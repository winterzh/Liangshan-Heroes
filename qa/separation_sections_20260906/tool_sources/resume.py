"""Verify the failed private import; --run alone permits one 600s import + 2x10s.

Never rewrites the failed attempt's evidence or copies caches into live production.
The old private project is reused only after reconstruction against its original tar.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tarfile

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def need(ok,message):
    if not ok: raise RuntimeError(message)


def file_sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as stream:
        for raw in iter(lambda:stream.read(1024*1024),b''): digest.update(raw)
    return digest.hexdigest()


def load_module(path):
    namespace={'__name__':'separation_resume_helper','__file__':str(path)}
    exec(compile(path.read_text(encoding='utf-8-sig'),str(path),'exec'),namespace)
    return namespace


def frozen_failure(contract):
    failed=HERE/contract['failed_run']
    need(failed.resolve().is_relative_to((HERE/'runs').resolve()),'Failed run escaped diagnostic runs')
    for name,value in contract['failed_record_sha256'].items():
        need(file_sha(failed/name)==value,'Original failure evidence changed: '+name)
    old=json.loads((failed/'receipt.json').read_text(encoding='utf-8'))
    process=json.loads((failed/'setup/import_process.json').read_text(encoding='utf-8'))
    need(old['complete'] is False and old['lock_released'] is True and old['stages']==[], 'Only the frozen failed import can resume')
    need(process['child_exit_confirmed'] is True and 'TimeoutExpired' in process['exception'],'Original import exit was not confirmed')
    need(old['live_before']==old['live_after'],'Original run did not preserve its live sources')
    return failed


def expected_sources(archive,contract,launcher,import_lf=None):
    """Read the original tar; never extract, copy or trust the partial project here."""
    need(file_sha(archive)==contract['base_tar_sha256'],'Frozen base.tar changed')
    expected={}; seen=set()
    original=contract['original_pins']
    with tarfile.open(archive,'r:') as tar:
        need(tar.pax_headers.get('comment')==contract['base'],'Git archive commit marker disagrees')
        for entry in tar:
            name=entry.name.rstrip('/')
            path=PurePosixPath(name)
            need(name and not path.is_absolute() and path.as_posix()==name and
                 all(part not in ('','..','.') for part in path.parts) and
                 ':' not in name and '\\' not in name,'Unsafe archive member')
            need(path.parts[0] in launcher['ALLOW'] and '.godot' not in path.parts,'Unexpected archived root/cache')
            need(name.casefold() not in seen,'Duplicate/case-colliding archive member')
            seen.add(name.casefold())
            need(entry.isdir() or entry.isfile(),'Archive link/special member rejected')
            if entry.isdir(): continue
            stream=tar.extractfile(entry)
            need(stream is not None,'Unreadable archive member')
            with stream: raw=stream.read()
            need(len(raw)==entry.size,'Truncated archive member')
            expected[name]=launcher['sha'](raw)
            if name.endswith('.import') and import_lf is not None:
                import_lf[name]=launcher['sha'](raw.replace(b'\r\n',b'\n'))
            if name in original['source_lf_sha256']:
                need(launcher['sha'](launcher['lf'](raw))==original['source_lf_sha256'][name], 'Frozen critical source disagrees: '+name)
    need(set(original['source_lf_sha256'])<=set(expected),'Archive lacks frozen critical sources')
    for generated,destination in contract['generated_private_paths'].items():
        raw=(HERE/'generated'/generated).read_bytes()
        need(launcher['sha'](raw)==original['generated_raw_sha256'][generated], 'Original generated probe changed: '+generated)
        need(generated in ('battle_instrumented.gd.txt','crowd_instrumented.gd.txt') or destination not in expected,'Generated insertion overwrites archived source')
        expected[destination]=launcher['sha'](raw)
    return expected


def verify_project(project,expected,allowed,launcher,previous=None,import_lf=None):
    actual=launcher['manifest'](project)
    import_lf=import_lf or {}
    bad=[name for name,value in expected.items() if actual.get(name)!=value and
         not (name.endswith('.import') and name in import_lf and actual.get(name)==import_lf[name])]
    need(not bad,'Private source/metadata differs from exact reconstructed original: '+str(bad[:8]))
    created=set(actual)-set(expected)
    need(created<=set(allowed),'Unexpected private source-side addition')
    for name in created:
        need(launcher['generated_uid']((project/name).read_bytes()),'Invalid declared generated UID: '+name)
    if previous is not None:
        need(all(actual.get(name)==value or (name.endswith('.import') and name in import_lf and
             value==expected.get(name) and actual.get(name)==import_lf[name])
             for name,value in previous.items()),'Import modified pre-existing source or generated UID')
    return actual


def cache_changes(before,after):
    changes={name:{'before':before.get(name),'after':after.get(name)} for name in sorted(set(before)|set(after)) if before.get(name)!=after.get(name)}
    need(all(name.startswith('shader_cache/') for name in changes),'Imported resource/class/UID/non-shader cache drift')
    return changes


def native_executable(value,launcher):
    safe=launcher['module'](HERE/'frozen/process_safety.py');safe['ROOT']=ROOT
    path=Path(safe['resolve_godot'](value))
    if path.name.lower().endswith('_console.exe'):
        path=path.with_name(path.name[:-len('_console.exe')]+'.exe')
    need(path.is_file() and path.suffix.lower()=='.exe' and not path.name.lower().endswith('_console.exe'),'A real non-console Godot executable is required')
    need(not path.is_symlink() and not getattr(path.lstat(),'st_file_attributes',0)&0x400,'Godot executable is a reparse path')
    return str(path.resolve()),safe


def protected_profile(project):
    config=(project/'project.godot').read_text(encoding='utf-8')
    need(not re.search(r'(?m)^config/(use_custom_user_dir|custom_user_dir_name)\s*=',config),'Custom user directory needs review')
    names=re.findall(r'(?m)^config/name="([^"\r\n]+)"\s*$',config)
    need(len(names)==1 and not any(c in names[0] for c in '/\\'),'Cannot determine original player directory')
    need(bool(os.environ.get('APPDATA')),'Windows APPDATA is required')
    folder=Path(os.environ['APPDATA'])/'Godot/app_userdata'/names[0]
    return {'directory':str(folder),'files':{name:file_sha(folder/name) if (folder/name).is_file() else None
        for name in ('settings.cfg','campaign.cfg','screen.cfg')}}


def preflight(args,launcher,pins,contract):
    launcher['verify_draft'](pins)
    need(contract['base']==launcher['BASE']==contract['original_pins']['base'],'Wrong frozen base')
    failed=frozen_failure(contract)
    import_lf={}
    expected=expected_sources(failed/'base.tar',contract,launcher,import_lf)
    derived={name+'.uid':name for name in expected if name.endswith('.gd') and name+'.uid' not in expected}
    allowed=json.loads((failed/'allowed_import_uid_sources.json').read_text(encoding='utf-8'))
    need(derived==allowed,'Original missing-UID declaration does not match reconstructed scripts')
    project=failed/'project'
    current=verify_project(project,expected,allowed,launcher,import_lf=import_lf)
    exe,safe=native_executable(args.godot,launcher)
    player=protected_profile(project)
    frozen_failure(contract)
    return failed,project,expected,allowed,current,exe,safe,player,import_lf


def run(args,launcher,pins,contract):
    # Preflight is repeated inside our exclusive slot; the default plan is not authority.
    exe,safe=native_executable(args.godot,launcher)
    safe['require_exclusive_godot']()
    output=HERE/'resume_runs'/datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output.mkdir(parents=True,exist_ok=False)
    lock=launcher['LOCK']; need(not lock.exists(),'Shared Godot/source slot occupied')
    before=launcher['live_pins'](pins)
    receipt={'base':contract['base'],'failed_run':contract['failed_run'],'complete':False,'lock_released':False,'stages':[],
        'live_before':before,'live_source_mutated_by_runner':False,'performance_claim':False,'import_timeout_seconds':600,
        'old_failure_is_performance_evidence':False,'runner_sources':{name:file_sha(HERE/name) for name in ('resume.py','launch.py','analyze.py','resume_contract.json','pins.json')}}
    player=None; source_frozen=None; cache_frozen=None; project=None; expected=None; current=None
    with lock.open('x',encoding='utf-8') as stream: stream.write(str(output)+'\n')
    try:
        failed,project,expected,allowed,current,exe,safe,player,import_lf=preflight(args,launcher,pins,contract)
        receipt['protected_player_before']=player
        receipt['executable']=exe;receipt['executable_sha256']=file_sha(Path(exe))
        receipt['base_tar_sha256']=contract['base_tar_sha256']
        launcher['save'](output/'expected_sources.json',expected)
        launcher['save'](output/'import_metadata_policy.json',{name:{'original_raw':expected[name],
            'exact_crlf_to_lf':value,'before_resume_raw':current[name]} for name,value in import_lf.items()})
        launcher['save'](output/'source_before_resume_import.json',current)
        launcher['save'](output/'cache_before_resume_import.json',launcher['manifest'](project/'.godot',exclude_godot=False))
        safe['ROOT']=project
        helper=launcher['module'](project/'tools/run_polish_performance.py')
        setup=output/'setup';setup.mkdir()
        env,_=launcher['private_environment'](helper,setup)
        launcher['import_project'](safe,exe,project,env,setup,timeout=600)
        source_frozen=verify_project(project,expected,allowed,launcher,previous=current,import_lf=import_lf)
        launcher['save'](output/'source_after_completed_import.json',source_frozen)
        launcher['save'](output/'generated_uid_receipt.json',{name:{'script':allowed[name],
            'script_sha256':expected[allowed[name]],'uid_sha256':source_frozen[name]}
            for name in sorted(set(source_frozen)-set(expected))})
        cache_frozen=launcher['manifest'](project/'.godot',exclude_godot=False)
        need('global_script_class_cache.cfg' in cache_frozen and any(name.startswith('imported/') for name in cache_frozen),'Successful import lacks required script/resource cache')
        launcher['save'](output/'cache_after_completed_import.json',cache_frozen)

        def guard(stage):
            frozen_failure(contract)
            need(protected_profile(project)==player,'Real player files changed during private diagnostic')
            need(file_sha(Path(exe))==receipt['executable_sha256'],'Godot executable changed')
            need(all(file_sha(HERE/name)==value for name,value in receipt['runner_sources'].items()),'Resume runner/contract source drift')
            now=launcher['manifest'](project/'.godot',exclude_godot=False)
            launcher['save'](output/('cache_'+stage+'.json'),now)
            changes=cache_changes(cache_frozen,now)
            launcher['save'](output/('shader_cache_'+stage+'.json'),{'relative_to':'cache_after_completed_import.json','changes':changes})

        launcher['measure_pair'](safe,exe,project,output,pins,before,source_frozen,receipt,validate_extra=guard)
        receipt['complete']=True
    except BaseException as exc:
        receipt['exception']=type(exc).__name__+': '+str(exc)
        raise
    finally:
        try:
            safe['require_exclusive_godot']()
            receipt['live_after']=launcher['live_pins'](pins)
            need(receipt['live_after']==before,'Live source drift; retain lock without restoration')
            frozen_failure(contract)
            receipt['old_failure_records_unchanged']=True
            if player is not None:
                receipt['protected_player_after']=protected_profile(project)
                need(receipt['protected_player_after']==player,'Real player files changed; retain lock')
            if expected is not None:
                final=verify_project(project,expected,allowed,launcher,previous=current,import_lf=import_lf)
                launcher['save'](output/'source_final.json',final)
                if source_frozen is not None: need(final==source_frozen,'Frozen completed-import source drift')
                if cache_frozen is not None:
                    final_cache=launcher['manifest'](project/'.godot',exclude_godot=False)
                    launcher['save'](output/'cache_final.json',final_cache)
                    launcher['save'](output/'shader_cache_final.json',{'relative_to':'cache_after_completed_import.json','changes':cache_changes(cache_frozen,final_cache)})
            need(lock.read_text(encoding='utf-8').strip()==str(output),'Shared lock ownership changed')
            lock.unlink();receipt['lock_released']=True
        except BaseException as exc:
            receipt['cleanup_error']=type(exc).__name__+': '+str(exc)
        launcher['save'](output/'receipt.json',receipt)
        print(json.dumps({'output':str(output),'complete':receipt['complete'],'lock_released':receipt['lock_released']}))
    return 0 if receipt['complete'] and receipt['lock_released'] else 2


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true');parser.add_argument('--godot')
    args=parser.parse_args()
    need(os.name=='nt','Private APPDATA policy is Windows-only')
    launcher=load_module(HERE/'launch.py')
    pins=json.loads((HERE/'pins.json').read_text(encoding='utf-8'))
    contract=json.loads((HERE/'resume_contract.json').read_text(encoding='utf-8'))
    if args.run: return run(args,launcher,pins,contract)
    failed,project,expected,allowed,current,exe,safe,player,import_lf=preflight(args,launcher,pins,contract)
    metadata={name:{'original_raw':expected[name],'exact_crlf_to_lf':value,'observed_raw':current[name]} for name,value in import_lf.items()}
    launcher['save'](HERE/'resume_import_policy.json',metadata)
    plan={'schema':1,'godot_run':False,'verified_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'failed_run':str(failed),'private_project':str(project),'base_tar_sha256':contract['base_tar_sha256'],
        'reconstructed_files':len(expected),'observed_files':len(current),'allowed_uid_count':len(allowed),
        'existing_generated_uid_count':len(set(current)-set(expected)), 'source_matches':True,
        'import_crlf_to_lf_count':sum(current[name]!=expected[name] for name in import_lf),
        'import_metadata_policy_sha256':file_sha(HERE/'resume_import_policy.json'),
        'executable':exe,'executable_sha256':file_sha(Path(exe)),'protected_player':player,
        'future_import_timeout_seconds':600,'future_measurements':['timed/fixed/10s','clockless/fixed/10s'],
        'cache_policy':'Reuse partial cache only for re-import. Freeze all cache after successful import; only shader_cache changes may occur during rendered diagnostics.',
        'performance_claim':False,'old_failure_records_unchanged':True}
    launcher['save'](HERE/'resume_plan.json',plan)
    print(json.dumps(plan,ensure_ascii=False))
    return 0


if __name__=='__main__': sys.exit(main())
