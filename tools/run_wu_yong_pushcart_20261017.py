"""Full local PCK/GL WuYong pushcart acceptance, with optional verified QA-project reuse.

Default creates a fresh private project below checkout/.godot. Reuse explicitly
archives all previous canonical input bytes through verified Git blobs + a small
ZIP of non-Git inputs before changing the private candidate. The old pack remains
unchanged. This never edits the immutable source owner or identity generator.
"""
import argparse,hashlib,importlib.util,json,os,shutil,subprocess,time,traceback,uuid,zipfile
from pathlib import Path
import run_character_art_qa as common
ROOT=Path(__file__).resolve().parents[1]
SELF='tools/run_wu_yong_pushcart_20261017.py';SCRIPT='tools/wu_yong_pushcart_20261017.gd'
PROBE='tools/wu_yong_pushcart_identity_20261017.gd';REFERENCE='tools/shi_en_texture_reference_20261015.gd'
HELPER='tools/contracts/run_content_identity_20260907/build_identity.py'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,value):p.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())
def load_identity(helper):
    spec=importlib.util.spec_from_file_location('chao_actual_identity',helper);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def archive_previous(project,previous,identity,evidence,commit):
    identity.verify_generated(project,previous['generated_identity'])
    resolved=subprocess.check_output(['git','rev-parse',commit+'^{commit}'],cwd=ROOT).decode().strip()
    entries=subprocess.check_output(['git','ls-tree','-r','-z',resolved],cwd=ROOT).split(b'\0');tree={}
    for entry in entries:
        if entry:
            head,name=entry.split(b'\t',1);mode,kind,oid=head.split()
            if kind==b'blob':tree[name.decode('utf-8')]=oid.decode()
    zip_path=evidence/'prior_inputs_non_git.zip';rows=[];derived=project/identity.DERIVED
    with zipfile.ZipFile(zip_path,'x',zipfile.ZIP_DEFLATED) as z:
        for row in previous['generated_identity']['identity']['files']:
            name=row['path'];p=project/name;raw=p.read_bytes();assert hashlib.sha256(raw).hexdigest()==row['sha256'] and len(raw)==row['bytes']
            oid=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest();record=dict(row)
            if tree.get(name)==oid:record['git']={'commit':resolved,'blob':oid}
            else:
                entry='files/'+name;z.writestr(entry,raw);record['zip_entry']=entry
            rows.append(record)
        raw=derived.read_bytes();assert sha(derived)==previous['generated_identity']['derived']['sha256'];z.writestr('derived/'+identity.DERIVED,raw)
    oids=sorted({row['git']['blob'] for row in rows if 'git' in row})
    proc=subprocess.run(['git','cat-file','--batch-check'],input=('\n'.join(oids)+'\n').encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,cwd=ROOT,env=os.environ|{'GIT_NO_LAZY_FETCH':'1'},check=True)
    checks=proc.stdout.decode().splitlines();assert len(checks)==len(oids) and all(x.split()[1]=='blob' for x in checks)
    with zipfile.ZipFile(zip_path) as z:
        for row in rows:
            if 'zip_entry' in row:assert hashlib.sha256(z.read(row['zip_entry'])).hexdigest()==row['sha256']
        assert hashlib.sha256(z.read('derived/'+identity.DERIVED)).hexdigest()==previous['generated_identity']['derived']['sha256']
    manifest={'git_commit':resolved,'files':rows,'directories':previous['generated_identity']['identity']['directories'],
      'derived':previous['generated_identity']['derived'],'zip_path':str(zip_path),'zip_sha256':sha(zip_path),
      'restore':'Reconstruct into a fresh private project under the same real source owner: use each verified Git blob or ZIP entry at its exact path, recreate recorded directories and restore archived derived constant. Verify all SHA256 before reimport; the old pack is retained. Current reused project becomes a new candidate and is not the original source tree in place.'}
    save(evidence/'prior_inputs_restore.json',manifest)
    return {'restore_manifest':str(evidence/'prior_inputs_restore.json'),'restore_manifest_sha256':sha(evidence/'prior_inputs_restore.json'),
      'zip_sha256':sha(zip_path),'zip_bytes':zip_path.stat().st_size,'git_commit':resolved,'git_files':sum('git' in x for x in rows),'zip_files':sum('zip_entry' in x for x in rows),'input_files':len(rows)}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run',action='store_true');p.add_argument('--work-root',type=Path,required=True);p.add_argument('--pack-root',type=Path,required=True)
    p.add_argument('--reuse-project-receipt',type=Path);p.add_argument('--prior-git-commit',help='Exact retained source commit, required only for verified reuse');args=p.parse_args()
    assert bool(args.reuse_project_receipt)==bool(args.prior_git_commit)
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    m=json.loads((ROOT/'assets/direction4/level1_wu_yong_pushcart_20261017.json').read_text(encoding='utf-8'))
    retained=[]
    for name in ['level1_wu_yong_merchant_20261017','level1_liu_tang_merchant_20261016','level1_liu_tang_pushcart_20261017','level1_chao_gai_merchant_20261017','level1_chao_gai_pushcart_20261017','level1_bai_sheng_carry_20261016']:
        d=json.loads((ROOT/'assets/direction4'/(name+'.json')).read_text(encoding='utf-8'));retained.extend(row['path'] for row in d['sources'].values())
        if 'portrait' in d:retained.append(d['portrait']['path'])
    inputs={'manifest':m,'ground_manifest':json.loads((ROOT/'assets/direction4/level1_tribute_ground_cart_20261017.json').read_text(encoding='utf-8')),
      'textures':sorted({r['path'] for r in m['sources'].values()}|set(retained))}
    if not args.run:
        print(json.dumps({'runtime_textures':len(inputs['textures']),'engine_busy':bool(running()),'lock_present':shared.LOCK.exists(),'native_launched':False}));return
    if running() or shared.LOCK.exists():raise RuntimeError('Shared Godot slot occupied')
    work=shared.resolve_profile_root(args.work_root);work=shared.resolve_profile_root(work.resolve())
    pack_root=shared.resolve_profile_root(args.pack_root);pack_root=shared.resolve_profile_root(pack_root.resolve())
    run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);e=run/'evidence';runtime=pack_root/run.name/'clean_runtime'
    previous=None;owner_reference=None
    if args.reuse_project_receipt:
        helper=load_identity(ROOT/HELPER);helper.no_links(args.reuse_project_receipt.absolute());previous=json.loads(args.reuse_project_receipt.read_text(encoding='utf-8'))
        assert previous['complete'] and previous['lock_released']
        project=Path(previous['project']);source_owner=Path(previous['source_owner']);assert source_owner!=ROOT and not previous['source_owner_is_checkout']
    else:source_owner=ROOT;project=ROOT/'.godot/wu_yong_pushcart_20261017'/run.name/'project'
    identity=load_identity(source_owner/HELPER);identity.private_staging(project)
    assert sha(source_owner/HELPER)==sha(ROOT/HELPER)
    names=sorted(set(shared.sources())|set(common.TOOLS)|{SELF,SCRIPT,PROBE,REFERENCE,HELPER,'tools/run_character_art_qa.py','tools/build_wu_yong_pushcart_20261017.py','tools/verify_wu_yong_pushcart_sources_20261017.py','tools/build_chao_gai_pushcart_20261017.py','tools/verify_chao_gai_pushcart_sources_20261017.py','tools/build_liu_tang_pushcart_20261017.py','tools/build_liu_tang_pudao_20261016.py','tools/build_shi_en_canon_20261015.py','tools/build_directional_spriteframes.py'}|({r['path'] for r in previous['source_files']} if previous else set()))
    assert identity.DERIVED not in names and not (ROOT/identity.DERIVED).exists()
    receipt={'complete':False,'run':str(run),'project':str(project),'source_owner':str(source_owner),'source_owner_is_checkout':source_owner==ROOT,'source_files':[],'steps':[],
      'godot_sha256':sha(engine),'identity_generator_sha256':sha(source_owner/HELPER),'steam_updated':False,
      'scope':'WuYong hn_wu_yong loaded tribute pushcart, own original hurt/attack, real mission pickup/movement/delivery/drop, 4 directions/3 sizes plus startup/1.6 camera views, rigid cart depth/contact; ground cart, Liu/Chao/Bai identity separation retained. QA uses explicit CARRY/drug prerequisites, sampling positions, unrelated actors frozen/fog off. No full wine/campaign/save/performance/Steam/seven-cart-eleven-load/all-art qualification. Existing reused source project/cache is archived before mutation; final PCK has new actual identity and native packed-constant comparison.'}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True;assert not running();run.mkdir(parents=True);e.mkdir();runtime.mkdir(parents=True)
        if previous:
            assert not common.source_changes(project,previous['source_files'])
            owner_ref=previous['reused_owner_reference'];owner_path=Path(owner_ref['receipt']);assert sha(owner_path)==owner_ref['receipt_sha256']
            owner_reference=json.loads(owner_path.read_text(encoding='utf-8'));assert Path(owner_reference['source_owner'])==source_owner
            assert not common.source_changes(source_owner,owner_reference['source_files'])
            receipt['reused_owner_reference']=owner_ref
            old_pack=Path(previous['pack_path']);assert sha(old_pack)==previous['pack_sha256']
            receipt['previous_receipt']={'path':str(args.reuse_project_receipt),'sha256':sha(args.reuse_project_receipt),'pack_path':str(old_pack),'pack_sha256':sha(old_pack)}
            receipt['prior_context_archive']=archive_previous(project,previous,identity,e,args.prior_git_commit)
            # The original guard still governs the exact private derived file.
            assert sha(project/identity.DERIVED)==previous['generated_identity']['derived']['sha256'];(project/identity.DERIVED).unlink()
        else:project.mkdir(parents=True)
        for name in names:
            common.relative_source(ROOT,name);target=project/name;raw=(ROOT/name).read_bytes();target.parent.mkdir(parents=True,exist_ok=True)
            if not target.exists() or target.read_bytes()!=raw:target.write_bytes(raw)
            receipt['source_files'].append({'path':name,'sha256':sha(target)})
        receipt['native_dependencies']=shared.install_native(project)
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile);receipt['private_profile']=str(profile)
        template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe';dest=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        dest.parent.mkdir(parents=True);shutil.copyfile(template,dest);receipt['template_sha256']=sha(template)
        input_path=e/'inputs.json';save(input_path,inputs);receipt['inputs_sha256']=sha(input_path)
        receipt['identity_seed']=identity.seed(project)
        common.process_step(engine,project,env,e,'reimport_reused_cache' if previous else 'cold_import',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        common.process_step(engine,project,env,e,'parse_scene_probe',['--headless','--check-only','--script','res://'+SCRIPT],60,'gl_compatibility',running,receipt['steps'])
        ref=e/'texture_references.json';common.process_step(engine,project,env|{'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE_OUT':str(ref)},e,'source_texture_reference',['--headless','--script','res://'+REFERENCE],90,'gl_compatibility',running,receipt['steps'])
        assert set(json.loads(ref.read_text(encoding='utf-8')))==set(inputs['textures']);receipt['texture_reference_sha256']=sha(ref)
        receipt['generated_identity']=identity.generate(project);assert not common.source_changes(project,receipt['source_files'])
        pack=runtime/'LiangshanWuYongGaiPushcart.pck'
        common.process_step(engine,project,env,e,'export_pack',['--headless','--editor','--export-pack','Windows Steam',str(pack)],300,'gl_compatibility',running,receipt['steps'])
        identity.verify_generated(project,receipt['generated_identity']);receipt.update(pack_path=str(pack),pack_sha256=sha(pack),pack_bytes=pack.stat().st_size)
        assert shared.install_native(runtime)==receipt['native_dependencies']
        for path in sorted((ROOT/'vendor').glob('*/provenance.json')):
            for row in json.loads(path.read_text(encoding='utf-8'))['files']:
                if row['path'].endswith('.dll'):
                    src=path.parent/row['path'];assert sha(src)==row['sha256'];target=runtime/src.name
                    if not target.exists():shutil.copyfile(src,target)
                    assert sha(target)==row['sha256']
        expected=e/'expected_identity.json';save(expected,{k:v for k,v in receipt['generated_identity']['identity'].items() if k not in ['files','directories']})
        common.process_step(engine,runtime,env|{'WU_EXPECTED_IDENTITY':str(expected)},e,'packed_identity_probe',['--headless','--main-pack',str(pack),'--script',str(project/PROBE)],60,'gl_compatibility',running,receipt['steps'])
        common.process_step(engine,runtime,env|{'SHI_EN_ART_OUT':str(e/'visual'),'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE':str(ref)},e,'packed_chao_pushcart_visuals',['--main-pack',str(pack),'--position','30000,30000','--script',str(project/SCRIPT)],360,'gl_compatibility',running,receipt['steps'])
        report=json.loads((e/'visual/report.json').read_text(encoding='utf-8'));assert report['passed'] and not report['failures']
        receipt.update(checks=len(report['checks']),screenshots=len(report['screenshots']),source_changes=common.source_changes(ROOT,receipt['source_files']),private_source_changes=common.source_changes(project,receipt['source_files']),source_owner_changes=common.source_changes(source_owner,owner_reference['source_files'] if owner_reference else receipt['source_files']))
        assert not receipt['source_changes'] and not receipt['private_source_changes'] and not receipt['source_owner_changes']
        identity.verify_generated(project,receipt['generated_identity']);assert sha(pack)==receipt['pack_sha256']
        if previous:assert sha(old_pack)==previous['pack_sha256']
        receipt['complete']=True
    except Exception as error:receipt.update(error=repr(error),traceback=traceback.format_exc())
    finally:
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not running():shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists();e.mkdir(parents=True,exist_ok=True);save(e/'receipt.json',receipt)
    print(json.dumps({k:receipt.get(k) for k in ['complete','run','checks','screenshots','error']},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)
if __name__=='__main__':main()
