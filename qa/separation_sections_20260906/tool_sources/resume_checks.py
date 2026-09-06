"""Small temporary-file refusal checks. No engine or actual child processes."""
import io
import json
from pathlib import Path
import tarfile
import tempfile

HERE=Path(__file__).resolve().parent


def module(path):
    namespace={'__name__':'resume_static','__file__':str(path)}
    exec(compile(path.read_text(encoding='utf-8'),str(path),'exec'),namespace)
    return namespace


def main():
    resume=module(HERE/'resume.py'); launch=module(HERE/'launch.py'); rows=[]
    def check(label,operation,reject=False):
        try: operation()
        except RuntimeError as exc:
            if not reject: raise
            rows.append({'label':label,'passed':True,'expected':'reject','observed':str(exc)})
        else:
            if reject: raise AssertionError('Accepted forbidden case: '+label)
            rows.append({'label':label,'passed':True,'expected':'accept'})
    with tempfile.TemporaryDirectory(prefix='resume_check_',dir=HERE) as temp:
        root=Path(temp);project=root/'project';(project/'scripts').mkdir(parents=True)
        content={'scripts/a.gd':b'extends RefCounted\n','scripts/a.gd.uid':b'uid://b\n','scripts/b.gd':b'extends Node\n'}
        for name,raw in content.items(): (project/name).write_bytes(raw)
        expected={name:launch['sha'](raw) for name,raw in content.items()}
        allowed={'scripts/b.gd.uid':'scripts/b.gd'}
        (project/'scripts/b.gd.uid').write_bytes(b'uid://c\n')
        operation=lambda:resume['verify_project'](project,expected,allowed,launch)
        check('exact source plus declared canonical UID',operation)
        baseline=operation()
        for label,path,raw in [('source byte drift','scripts/b.gd',b'changed'),('existing UID rewritten','scripts/a.gd.uid',b'uid://d\n')]:
            saved=(project/path).read_bytes();(project/path).write_bytes(raw)
            try: check(label,operation,True)
            finally: (project/path).write_bytes(saved)
        extra=project/'scripts/extra.gd.uid';extra.write_bytes(b'uid://e\n')
        try: check('undeclared new UID',operation,True)
        finally: extra.unlink()
        missing=project/'scripts/a.gd';saved=missing.read_bytes();missing.unlink()
        try: check('missing required source',operation,True)
        finally: missing.write_bytes(saved)
        uid=project/'scripts/b.gd.uid';uid.write_bytes(b'uid://not-valid!\n')
        check('invalid declared UID bytes',operation,True)
        uid.write_bytes(b'uid://f\n')
        check('previous partial-import UID changed on second import',lambda:resume['verify_project'](project,expected,allowed,launch,baseline),True)
        uid.write_bytes(b'uid://c\n')
        metadata=project/'scripts/texture.png.import'
        original=b'[remap]\r\nuid="uid://b"\r\npath="res://.godot/imported/a.ctex"\r\n[params]\r\ncompress/mode=0\r\n'
        normalized=original.replace(b'\r\n',b'\n')
        metadata.write_bytes(original)
        with_metadata={**expected,'scripts/texture.png.import':launch['sha'](original)}
        permitted={'scripts/texture.png.import':launch['sha'](normalized)}
        previous=launch['manifest'](project)
        metadata.write_bytes(normalized)
        check('existing import exact CRLF to LF',lambda:resume['verify_project'](project,with_metadata,allowed,launch,previous,permitted))
        normalized_previous=launch['manifest'](project)
        for label,raw in [('import parameter change',normalized.replace(b'mode=0',b'mode=1')),
                          ('import UID change',normalized.replace(b'uid://b',b'uid://c')),
                          ('import path change',normalized.replace(b'a.ctex',b'b.ctex'))]:
            metadata.write_bytes(raw)
            check(label,lambda:resume['verify_project'](project,with_metadata,allowed,launch,previous,permitted),True)
        metadata.write_bytes(original)
        check('already LF metadata cannot revert to CRLF',lambda:resume['verify_project'](project,with_metadata,allowed,launch,normalized_previous,permitted),True)
        metadata.unlink()
        source=project/'scripts/a.gd';source.write_bytes(b'extends RefCounted\r\n')
        check('non-import line-ending drift still rejected',operation,True)
        source.write_bytes(content['scripts/a.gd'])
        cache={'imported/a.ctex':'one','global_script_class_cache.cfg':'class','uid_cache.bin':'uid'}
        check('unchanged imported cache',lambda:resume['cache_changes'](cache,dict(cache)))
        check('only new and updated shader cache allowed',lambda:resume['cache_changes']({**cache,'shader_cache/a':'old'},{**cache,'shader_cache/a':'new','shader_cache/b':'added'}))
        check('imported resource cache mutation',lambda:resume['cache_changes'](cache,{**cache,'imported/a.ctex':'changed'}),True)
        check('new unclassified cache file',lambda:resume['cache_changes'](cache,{**cache,'unknown.bin':'added'}),True)
        check('UID cache removed',lambda:resume['cache_changes'](cache,{name:value for name,value in cache.items() if name!='uid_cache.bin'}),True)
        def tar_case(name,members):
            archive=root/name
            with tarfile.open(archive,'w',format=tarfile.PAX_FORMAT,pax_headers={'comment':launch['BASE']}) as tar:
                for member in members:
                    info=tarfile.TarInfo(member);info.size=1;tar.addfile(info,io.BytesIO(b'x'))
            contract={'base':launch['BASE'],'base_tar_sha256':resume['file_sha'](archive),
                'original_pins':{'source_lf_sha256':{},'generated_raw_sha256':{}},'generated_private_paths':{}}
            return archive,contract
        archive,contract=tar_case('good.tar',['scripts/a.gd'])
        check('tar source reconstructed without extraction',lambda:resume['expected_sources'](archive,contract,launch))
        wrong={**contract,'base_tar_sha256':'0'*64}
        check('original archive raw hash drift',lambda:resume['expected_sources'](archive,wrong,launch),True)
        for label,names in [('tar parent traversal',['../scripts/a.gd']),('tar duplicate source',['scripts/a.gd','scripts/a.gd']),('tar case collision',['scripts/a.gd','scripts/A.gd'])]:
            archive,contract=tar_case(str(len(rows))+'.tar',names)
            check(label,lambda:resume['expected_sources'](archive,contract,launch),True)
    receipt={'schema':1,'passed':True,'checks':len(rows),'results':rows,'godot_run':False,'real_subprocesses_started':0,
        'temporary_fixtures_removed':True,'failed_run_modified':False,
        'inputs':{name:resume['file_sha'](HERE/name) for name in ('resume.py','launch.py','resume_contract.json')}}
    launch['save'](HERE/'resume_static_receipt.json',receipt)
    print(json.dumps({key:value for key,value in receipt.items() if key not in ('results','inputs')}))


if __name__=='__main__': main()
