"""Select descriptor-matched native candidate caches; preserve prior QA caches."""
from pathlib import Path
import hashlib,re,shutil

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def merge_candidate_cache(root, manifest, prior, bootstrap, project, receipt):
    checks={row['path']:row for row in receipt['source_files']}
    expected=set();descriptors=[]
    for source in manifest['sources'].values():
        path=source['path'];desc=path+'.import'
        row=checks[path]
        assert sha(root/path)==row['before_sha256']==row['after_sha256']==sha(bootstrap/path), 'Candidate PNG drift: '+path
        row=checks[desc]
        assert sha(root/desc)==row['after_sha256']==sha(bootstrap/desc), 'Candidate imported descriptor drift: '+desc
        descriptors.append({'path':desc,'before_sha256':row['before_sha256'],'verified_after_sha256':row['after_sha256'],
                            'native_import_normalized':row['before_sha256']!=row['after_sha256']})
        assert sha(root/path)==source['sha256']
        names=set(re.findall(r'res://\.godot/imported/([^"\r\n]+)',(root/desc).read_text(encoding='utf-8')))
        assert len(names)==1
        name=next(iter(names));assert name.endswith('.ctex')
        expected.update((name,name[:-5]+'.md5'))
    current=bootstrap/'.godot/imported';old=prior/'.godot/imported';dest=project/'.godot/imported'
    files={p.name:p for p in current.iterdir() if p.is_file()}
    assert set(files)==expected, 'Only the descriptor-matched candidate texture and sidecar cache set is allowed'
    audit=[]
    for name in sorted(expected):
        p=old/name;digest=sha(p) if p.is_file() else None
        audit.append({'name':name,'prior_sha256':digest,'candidate_sha256':sha(files[name]),
                      'same_before':digest==sha(files[name]),'selected_source':'verified_candidate_import'})
    assert not dest.exists()
    shutil.copytree(old,dest,ignore=lambda _directory,names:[n for n in names if n in expected])
    for name,src in files.items():
        assert not (dest/name).exists()
        shutil.copyfile(src,dest/name);assert sha(dest/name)==sha(src)
    for row in audit:
        p=old/row['name'];assert (sha(p) if p.is_file() else None)==row['prior_sha256']
    return {'scope':'Warm runtime cache plus exact source/descriptor-matched native candidate cache; original caches preserved',
            'candidate_files':len(expected),'different_prior_files':sum(r['prior_sha256'] is not None and not r['same_before'] for r in audit),
            'selection':audit,'descriptors':descriptors,'png_drift':0,'prior_cache_mutated':False,'candidate_cache_mutated':False,'cold_import':False}
