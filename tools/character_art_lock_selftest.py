"""Exercise actual file ownership/busy guards without touching the shared lock."""
from pathlib import Path
import tempfile,json
from run_character_art_qa import release_owned_lock

def main():
    checks=[]
    with tempfile.TemporaryDirectory(prefix='character-art-lock-') as directory:
        root=Path(directory);lock=root/'owned.lock';owner=root/'run-a';other=root/'run-b'
        race={'steps':[],'failure':{'message':'Godot/Liangshan engine appeared before step import'}}
        lock.write_text(str(owner),encoding='utf-8')
        checks.append(('own unstarted race releases despite unrelated engine',release_owned_lock(lock,owner,race,True) and not lock.exists()))
        lock.write_text(str(other),encoding='utf-8')
        checks.append(('different owner stays untouched even idle',not release_owned_lock(lock,owner,race,False) and lock.read_text(encoding='utf-8')==str(other)))
        lock.write_text(str(owner),encoding='utf-8')
        started={'steps':[{'case':'import','passed':True}],'failure':race['failure']}
        checks.append(('busy after a step retains own lock',not release_owned_lock(lock,owner,started,True) and lock.exists()))
        wrong={'steps':[],'failure':{'message':'Other failure'}}
        checks.append(('unproven busy failure retains own lock',not release_owned_lock(lock,owner,wrong,True) and lock.exists()))
        checks.append(('idle completed child permits own release',release_owned_lock(lock,owner,started,False) and not lock.exists()))
    result={'passed':all(p for _,p in checks),'checks':[{'label':label,'passed':p} for label,p in checks],'scope':'Temporary lock files only; no Godot process, actual shared lock or other task is changed.'}
    print(json.dumps(result))
    return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
