"""Enumerate a precise owned-file allowlist and audit it before Git staging."""
from pathlib import Path
import hashlib,json,re,subprocess
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def sha(raw):return hashlib.sha256(raw).hexdigest()
tracked={'.gitattributes','scripts/unit.gd','scripts/campaign_art.gd','docs/WORKLOG.md','docs/SOURCE_SETUP.md','docs/ART_FULL_20260915.md','docs/DIRECTORY_INDEX.md','docs/WU_YONG_PUSHCART_20261017.md','docs/GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md','qa/wu_yong_push_gait_20261018/README.md','qa/gongsun_sheng_mounted_layers_20261018/README.md'}
actual=set(git('diff','--name-only','-z').decode().strip('\0').split('\0'));assert actual==tracked,(actual-tracked,tracked-actual)
assert not git('diff','--cached','--name-only').strip(),'Do not mix preexisting index changes'
roots=['qa/gongsun_sheng_mounted_walk_20261019','qa/wu_yong_layered_full_pack_20261019','qa/wu_yong_push_gait_20261018/actual_unit_v2','qa/wu_yong_push_gait_20261018/unit_v2_visual_assessment.json','qa/gongsun_sheng_mounted_layers_20261018/actual_native_v3','qa/gongsun_sheng_mounted_layers_20261018/native_v3_visual_assessment.json']
added={p for p in git('ls-files','--others','--exclude-standard','-z','--',*roots).decode().split('\0') if p}
paths=sorted(tracked|added)
rows=[]
for name in paths:
    p=R/name;assert p.is_file() and not p.is_symlink()
    assert p.stat().st_size<25*1024*1024,name
    assert p.suffix.lower() not in ['.exe','.dll','.pck','.zip','.7z','.key','.pem']
    assert not set(p.relative_to(R).parts)&{'.godot','.git','profile','profiles'}
    raw=p.read_bytes()
    if p.suffix.lower()!='.png':
        assert not re.search(rb'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}|AKIA[A-Z0-9]{16}',raw),name
    rows.append({'path':name,'bytes':len(raw),'sha256':sha(raw)})
scope=Q/'sync_scope.json';assert not scope.exists()
scope.write_text(json.dumps({'branch':git('branch','--show-current').decode().strip(),'head_before':git('rev-parse','HEAD').decode().strip(),'target':'refs/heads/codex/sync-20260905-stable','files':rows,'scope_file_added_separately':scope.relative_to(R).as_posix(),'total_bytes':sum(x['bytes'] for x in rows),'unrelated_untracked_excluded':81},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'files':len(rows)+1,'bytes':sum(x['bytes'] for x in rows),'max_file_bytes':max(x['bytes'] for x in rows)}))
