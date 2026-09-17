"""Bind this candidate to ROOT's completed 25-file integration, without invoking Git."""
from pathlib import Path
import argparse, hashlib, json, os, re
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
def main():
    p=argparse.ArgumentParser();p.add_argument('--integrated-head',required=True);p.add_argument('--bind-only',action='store_true');a=p.parse_args()
    assert re.fullmatch('[0-9a-f]{40}',a.integrated_head), 'ROOT must supply the integrated full HEAD'
    assert not (HERE/'freeze.json').exists(), 'Do not rewrite a frozen candidate'
    bridge=json.loads((ROOT/'scratchpad/stabilization_defense_identity_bridge_20260907/overlay_manifest.json').read_text('utf8'))
    expected={r['path']:ROOT/r['candidate'] for r in bridge['files']}
    rows=json.loads((HERE/'overlay_manifest.json').read_text('utf8'))
    checked=[]
    for row in rows['files']:
        src=ROOT/row['path'];candidate=ROOT/row['candidate']
        assert not src.is_symlink() and not candidate.is_symlink()
        assert sha(candidate)==row['candidate_sha256'],row['path']
        exists=os.path.lexists(src)
        if row['path'] in expected:
            assert exists and sha(src)==sha(expected[row['path']]), 'Unmerged or additional production delta: '+row['path']
        else:
            assert not exists, 'New module appeared; explicit rebase required: '+row['path']
        row['before_exists']=exists
        row['before_raw_sha256']=sha(src) if exists else None
        checked.append({'path':row['path'],'before_exists':exists,'before_raw_sha256':row['before_raw_sha256']})
    # The new production defense module is a dependency, although not an overlay here.
    defense='scripts/run_defense_level_state.gd'
    assert sha(ROOT/defense)==sha(expected[defense]), 'defense v2 integration missing'
    rows.update(status='before_bound_native_topology_pending' if a.bind_only else 'frozen_for_first_native_attempt',production_head_declared_by_root=a.integrated_head,
                before_binding='Actual raw bytes equal the separately frozen 25-file identity/defense package; generic runner verifies Git HEAD.')
    dump(HERE/'overlay_manifest.json',rows)
    dump(HERE/'before_binding.json',{'production_head_declared_by_root':a.integrated_head,'git_invoked':False,
        'production_changed':False,'checked':checked,'defense_dependency_sha256':sha(ROOT/defense)})
    if a.bind_only:
        print(json.dumps({'before_bound':len(checked),'head':a.integrated_head,'frozen':False}))
        return
    inputs={}
    for name in ['overlay_manifest.json','before_binding.json','HANDOFF.md','prepare.py','freeze.py',
                 'inventory.json','static_preparation.json','topology_evidence.json','battle_delta.patch','visual_delta.patch',
                 'timed_helpers.gd.inc','timed_cases.gd.inc','visual_smoke.gd','item_smoke.gd','timed_smoke.gd']:
        inputs[name]=sha(HERE/name)
    for row in rows['files']:
        candidate=ROOT/row['candidate'];inputs[candidate.relative_to(HERE).as_posix()]=sha(candidate)
    dump(HERE/'freeze.json',{'status':'frozen_for_first_native_attempt','engine_run':False,'production_changed':False,
                           'inputs':inputs})
    print(json.dumps({'freeze_sha256':sha(HERE/'freeze.json'),'manifest_sha256':sha(HERE/'overlay_manifest.json'),
                      'inputs':len(inputs),'overlay':len(rows['files']),'head':a.integrated_head}))
if __name__=='__main__': main()
