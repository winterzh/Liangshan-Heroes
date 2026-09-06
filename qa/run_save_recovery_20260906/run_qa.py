"""R01 tiny private-project QA. Default verifies source; --run owns one Godot child.
Reuses only the exact tested disk runner's process/exit helper, not its catalog.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
LOCK=ROOT/'.godot/redraw_rejection_source.lock'
PROJECT_NAME='RunSaveRecovery R01'
COPIES={'store_original.gd':'qa/store_original.gd','store_r01.gd':'qa/store_r01.gd','qa_driver.gd':'qa/qa_driver.gd'}


def need(ok,message):
    if not ok:raise RuntimeError(message)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def save(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def module(path):
    ns={'__name__':'r01_process_helper','__file__':str(path)}
    exec(compile(path.read_text(encoding='utf-8'),str(path),'exec'),ns)
    return ns
def verify(pins,private=None):
    for name,value in pins['raw_sha256'].items():need(sha((HERE/name).read_bytes())==value,'R01 source changed: '+name)
    need(sha((HERE.parent/'run_save_store/run_save_store.gd').read_bytes())==pins['original_store_sha256'],'Original store changed')
    need(sha((HERE.parent/'run_save_store/run_qa.py').read_bytes())==pins['original_process_runner_sha256'],'Original process runner changed')
    if private:
        for name,value in private['private_sources'].items():need(sha((Path(private['private_project'])/name).read_bytes())==value,'Private executable source changed')
def snapshot(directory):
    rows={}
    def failed(error):raise error
    for current,dirs,names in os.walk(directory,onerror=failed,followlinks=False):
        for name in dirs+names:
            p=Path(current)/name
            need(not p.is_symlink() and not getattr(p.lstat(),'st_file_attributes',0)&0x400,'Unexpected fixture link')
        for name in dirs:rows[(Path(current)/name).relative_to(directory).as_posix()]={'kind':'directory'}
        for name in names:
            p=Path(current)/name;raw=p.read_bytes()
            rows[p.relative_to(directory).as_posix()]={'kind':'file','bytes':len(raw),'sha256':sha(raw)}
    return rows
def prepare(pins):
    run_id=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out=HERE/'runs'/run_id;out.mkdir(parents=True,exist_ok=False)
    project=out/'project';project.mkdir(); hashes={}
    for name,destination in COPIES.items():
        target=project/destination;target.parent.mkdir(parents=True,exist_ok=True)
        raw=(HERE/name).read_bytes();target.write_bytes(raw);hashes[destination]=sha(raw)
    raw=('config_version=5\n[application]\nconfig/name="'+PROJECT_NAME+'"\nconfig/features=PackedStringArray("4.6")\n').encode()
    (project/'project.godot').write_bytes(raw);hashes['project.godot']=sha(raw)
    (project/'scratchpad/run_save_store/fixtures').mkdir(parents=True)
    user=out/'private_profile/appdata/Godot/app_userdata'/PROJECT_NAME
    for path in [user,out/'private_profile/localappdata',out/'private_profile/temp']:path.mkdir(parents=True,exist_ok=False)
    prepared={'schema':1,'run_id':run_id,'run_root':str(out),'private_project':str(project),'private_sources':hashes,
        'private_user':str(user),'pins':pins,'godot_run':False,'originals_modified':False}
    save(out/'preparation.json',prepared)
    return prepared
def run(args,pins,prepared):
    helper=module(HERE/'process_runner_original.py')
    value=args.godot or os.environ.get('GODOT_PATH','')
    if not value and (ROOT/'godot.local.txt').is_file():value=(ROOT/'godot.local.txt').read_text(encoding='utf-8-sig').strip()
    exe=Path(value)
    need(value and exe.is_file() and not re.search(r'[._-]console\.exe$',exe.name,re.I),'Explicit actual non-console Godot executable required')
    exe=exe.resolve();helper['no_links'](exe);helper['exclusive']()
    out=Path(prepared['run_root']);need(not LOCK.exists(),'Shared Godot slot occupied')
    result={'complete':False,'lock_released':False,'godot_run':False,'originals_modified':False,'recovery_mutations_implemented':False,'source_pins':pins,
        'engine_sha256':sha(exe.read_bytes())}
    with LOCK.open('x',encoding='utf-8') as stream:stream.write(str(out)+'\n')
    try:
        verify(pins,prepared)
        manifest={'schema':1,'run_id':prepared['run_id'],'phase':'single','report':str(out/'report.json'),
            'source_sha256':prepared['private_sources'],'private_user':prepared['private_user']}
        path=out/'manifest.json';save(path,manifest);manifest_sha=sha(path.read_bytes())
        result['godot_run']=True
        process=helper['run_process'](str(exe),prepared,path,manifest,args.timeout)
        verify(pins,prepared);need(sha(path.read_bytes())==manifest_sha,'Manifest changed')
        report=json.loads((out/'report.json').read_text(encoding='utf-8'))
        need(report.get('passed') is True and report.get('failures')==[] and len(report.get('checks',[]))>=25 and
             all(row.get('passed') is True for row in report['checks']),'Missing/failed real R01 checks')
        need(report['run_id']==prepared['run_id'] and report['process_id']==process['pid'] and report['manifest_sha256']==manifest_sha,'Report provenance mismatch')
        need(Path(report['actual_user_dir']).resolve()==Path(prepared['private_user']).resolve(),'Actual private profile mismatch')
        need(report['source_sha256']==prepared['private_sources'],'Runtime source pins mismatch')
        final={}
        for record in report['records']:
            need(record['before']==record['after'],'Read-only call changed directory')
            directory=Path(record['directory']).resolve()
            boundary=(Path(prepared['private_project'])/'scratchpad/run_save_store/fixtures').resolve()
            need(boundary in directory.parents,'Snapshot escaped fixture boundary')
            final[str(directory)]=record['after']
        for directory,expected in final.items():need(snapshot(Path(directory))==expected,'Independent actual fixture snapshot differs')
        result.update(complete=True,checks=len(report['checks']),readonly_calls=len(report['records']),final_fixture_count=len(final),report_sha256=sha((out/'report.json').read_bytes()))
    except BaseException as error:
        result['error']=type(error).__name__+': '+str(error)
        raise
    finally:
        try:
            helper['exclusive']();verify(pins,prepared)
            need(LOCK.read_text(encoding='utf-8').strip()==str(out),'Shared lock ownership changed')
            LOCK.unlink();result['lock_released']=True
        except BaseException as error:result['cleanup_error']=type(error).__name__+': '+str(error)
        save(out/'receipt.json',result);print(json.dumps({'run':str(out),'complete':result['complete'],'lock_released':result['lock_released']}))
    return 0 if result['complete'] and result['lock_released'] else 2
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--run',action='store_true')
    parser.add_argument('--godot');parser.add_argument('--timeout',type=int,default=120);args=parser.parse_args()
    need(15<=args.timeout<=240,'Bounded 15..240 second timeout required')
    pins=json.loads((HERE/'pins.json').read_text(encoding='utf-8'));verify(pins)
    if not args.prepare and not args.run:
        print(json.dumps({'source_verified':True,'godot_run':False,'ready_for_private_prepare':True}));return 0
    prepared=prepare(pins)
    if not args.run:print(json.dumps({'prepared':prepared['run_root'],'godot_run':False}));return 0
    return run(args,pins,prepared)


if __name__=='__main__':sys.exit(main())
