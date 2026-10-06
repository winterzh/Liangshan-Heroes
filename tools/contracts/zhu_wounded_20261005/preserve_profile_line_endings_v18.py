"""Preserve each unchanged native line's original terminator in the profile patch."""
from pathlib import Path
import difflib,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3]
def main():
    p=ROOT/'scripts/run_official_restore_profile.gd';before=p.read_bytes()
    original=subprocess.check_output(['git','show','d561d78c4bb9f6357e24436d2c8cdfddab48a4e2:scripts/run_official_restore_profile.gd'],cwd=ROOT)
    old=original.decode('utf-8').splitlines(keepends=True);new=before.decode('utf-8').splitlines(keepends=True)
    a=[x.rstrip('\r\n') for x in old];b=[x.rstrip('\r\n') for x in new];out=[]
    for tag,i,j,k,l in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
        if tag=='equal':out.extend(old[i:j])
        else:
            ending='\r\n' if i<len(old) and old[i].endswith('\r\n') else '\n'
            out.extend(x+ending for x in b[k:l])
    result=''.join(out).encode('utf-8');assert result.decode().splitlines()==before.decode().splitlines();p.write_bytes(result)
    record={'semantic_change':False,'path':p.relative_to(ROOT).as_posix(),'before_sha256':hashlib.sha256(before).hexdigest(),'after_sha256':hashlib.sha256(result).hexdigest(),'producer_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'reason':'Original source uses mixed terminators. Keep original bytes for every unchanged line; no whole-file normalization.'}
    q=ROOT/'qa/zhu_wounded_20261005/campaign_profile_line_endings_v18.json';assert not q.exists();q.write_bytes((json.dumps(record,indent=2)+'\n').encode())
if __name__=='__main__':main()
