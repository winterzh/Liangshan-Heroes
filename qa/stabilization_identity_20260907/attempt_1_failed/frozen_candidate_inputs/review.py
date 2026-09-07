"""Read production; verify the isolated candidate. Never run Godot or Git."""
from pathlib import Path
import collections
import hashlib
import json
import re
import sys

from prepare import HERE, ROOT, lf, sha, spans, methods, dump
from harden import normalize


def replay_patch(patch, sources):
    result = {}
    for section in re.split(r'(?m)(?=^--- a/)', patch):
        if not section: continue
        lines = section.splitlines(True)
        name = lines[0].rstrip()[6:]
        assert name in sources and name not in result
        assert lines[1].rstrip() == '+++ b/' + name
        old = sources[name].splitlines(True)
        cursor, built, index = 0, [], 2
        while index < len(lines):
            header = re.fullmatch(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@\n', lines[index])
            assert header, lines[index]
            start, old_count, new_start, new_count = [int(v) if v is not None else 1 for v in header.groups()]
            target = start - 1 if old_count else start
            assert cursor <= target <= len(old)
            built.extend(old[cursor:target]); cursor = target; index += 1
            consumed = emitted = 0
            assert len(built) == (new_start - 1 if new_count else new_start)
            while index < len(lines) and not lines[index].startswith('@@ '):
                mark, data = lines[index][0], lines[index][1:]
                assert mark in ' +-'
                if mark in ' -':
                    assert cursor < len(old) and old[cursor] == data, (name, cursor)
                    cursor += 1; consumed += 1
                if mark in ' +': built.append(data); emitted += 1
                index += 1
            assert (consumed, emitted) == (old_count, new_count), name
        built.extend(old[cursor:]); result[name] = ''.join(built)
    return result


def calls(text, pattern):
    """Balanced source call inventory: compare argument tokens in lexical order."""
    out=[]
    for m in re.finditer(pattern,text):
        depth=0;quote='';escape=False
        for j in range(m.end()-1,len(text)):
            c=text[j]
            if quote:
                if escape:escape=False
                elif c=='\\':escape=True
                elif c==quote:quote=''
            elif c in '\"\'':quote=c
            elif c=='(':depth+=1
            elif c==')':
                depth-=1
                if depth==0:
                    out.append(re.sub(r'\s+','',text[m.start():j+1]));break
    return out


def main():
    r=json.loads((HERE/'source_receipt.json').read_bytes())
    expected=json.loads((HERE/'reviewed_methods.json').read_bytes())
    before={};candidate={};changed={}
    for row in r['files']:
        name=row['path'];raw=(HERE/'before'/(name+'.txt')).read_bytes()
        assert sha(raw)==row['before_raw_sha256'],name
        assert (ROOT/name).read_bytes()==raw,('production drift',name)
        after=(HERE/'candidate'/name).read_bytes()
        assert sha(after)==row['candidate_sha256'],name
        before[name]=lf(raw);candidate[name]=lf(after)
        old=methods(before[name]);new=methods(candidate[name])
        changed[name]=sorted(f for f in old.keys()|new.keys() if old.get(f)!=new.get(f))
        assert changed[name]==expected[name],('method allowlist',name,changed[name])
        # This compares call argument tokens and lexical order. Runtime scheduling
        # and successful path equivalence still require actual Godot regression.
        for pattern in [r'\b(?:spawn_unit|spawn_at|spawn_group)\(',
                        r'\b(?:gameplay_)?(?:randf|randi)(?:_range)?\s*\(',
                        r'Engine\.get_(?:physics_frames|process_frames)\(']:
            assert calls(before[name],pattern)==calls(candidate[name],pattern),(name,pattern)
    assert set(expected)==set(candidate)
    patch=(HERE/'candidate.patch').read_bytes()
    assert sha(patch)==r['patch_sha256']
    assert replay_patch(lf(patch),before)==candidate
    unit=candidate['scripts/unit.gd'];state=candidate['scripts/run_unit_state.gd']
    declared=re.findall(r'^var (\w+)',unit,re.M)
    assert len(declared)==len(set(declared))==273
    rules=re.findall(r'^\s*"([^"]+)":',state.split('const RULES := {\n',1)[1].split('\n}',1)[0],re.M)
    reads=re.findall(r'"([^"]+)":unit\.',methods(state)['_read_explicit'])
    writes=re.findall(r'\tunit\.(\w+) = values\[',methods(state)['_assign_values'])
    assert set(rules)==set(reads)==set(writes) and len(rules)==244
    assert rules.count('entity_id')==reads.count('entity_id')==writes.count('entity_id')==1
    for fn in ['_physics_process','_on_unit_died','on_unit_trained','clear_campaign_section','capture_gameplay_rng']:
        assert methods(before['scripts/battle.gd'])[fn]==methods(candidate['scripts/battle.gd'])[fn]
    assert '_unit' not in changed['scripts/run_unit_state.gd']
    assert '_id' not in changed['scripts/run_unit_graph.gd']
    assert 'release_tombstones(' not in methods(candidate['scripts/run_unit_graph.gd'])['prepare']
    assert 'next_entity_id' not in methods(candidate['scripts/battle.gd'])['clear_campaign_section']
    assert methods(before['scripts/crowd_separation.gd'])['solve'].replace('u.get_instance_id()','u.entity_id')==methods(candidate['scripts/crowd_separation.gd'])['solve']
    assert (ROOT/'scripts/run_graph_identity.gd').read_bytes()==(ROOT/'qa/run_resume_components_20260907/sources/scratchpad/run_resume_integration/graph_identity.gd.txt').read_bytes()

    sys.path.insert(0,str(HERE/'parser_runtime'))
    from gdtoolkit.parser import parser
    normalized_count=0;projection_count=0
    for name,text in candidate.items():
        # gdtoolkit 4.5 rejects two existing Godot-valid equality/not expressions.
        # Assert exact same legacy occurrences; project only in parser memory.
        count=text.count('== not hud.touch_ui')
        assert count==before[name].count('== not hud.touch_ui')
        projection_count+=count
        parser.parse(text.replace('== not hud.touch_ui','== (not hud.touch_ui)'),gather_metadata=True)
        if name.startswith('scripts/levels/'):
            for fn,(a,b) in spans(before[name]).items():
                if fn in changed[name]:
                    original=before[name][a:b]
                    assert parser.parse(original)==parser.parse(normalize(original)),('format normalization AST',name,fn)
                    normalized_count+=1
    for path in HERE.glob('*smoke.gd'):
        parser.parse(path.read_text('utf8'),gather_metadata=True)

    creation=[];native=[];constructors=[];inputs=[]
    for p in sorted((ROOT/'scripts').rglob('*.gd')):
        raw=p.read_bytes();text=lf(raw);name=p.relative_to(ROOT).as_posix();relevant=False;fn='<top-level>'
        for n,line in enumerate(text.splitlines(),1):
            m=re.match(r'^(?:static )?func (\w+)\(',line)
            if m:fn=m[1]
            if m or line.lstrip().startswith('#'):continue
            if re.search(r'\b(?:spawn_unit|spawn_at|spawn_group|_start_construction|ai_start_construction)\(',line):
                relevant=True
                if name=='scripts/battle.gd':
                    status='shared_runtime_reviewed' if fn in {'spawn_at','spawn_group','_try_place_building','_start_construction','ai_start_construction','on_unit_trained','_eco_build','_do_summon'} else 'developer_fixture_fresh_allocator_only'
                elif name.startswith('scripts/levels/'):
                    assert name in candidate,('unreviewed level creation',name)
                    status='level_guarded_or_transaction_reviewed'
                else:status='outside_shared_level_requires_classification'
                creation.append({'path':name,'line':n,'method':fn,'code':line.strip(),'status':status})
            if 'Unit.new()' in line:
                constructors.append({'path':name,'line':n,'method':fn,'code':line.strip()})
            if re.search(r'get_instance_id\(|Engine\.get_(?:physics_frames|process_frames)\(',line):
                relevant=True;native.append({'path':name,'line':n,'method':fn,'code':line.strip()})
        if relevant or name in candidate:inputs.append({'path':name,'raw_sha256':sha(raw),'bytes':len(raw)})
    statuses=dict(collections.Counter(row['status'] for row in creation))
    assert 'outside_shared_level_requires_classification' not in statuses,statuses
    inventory={'status':'static_verified_runtime_pending','source_creation_rows':len(creation),'statuses':statuses,
               'creation_calls':creation,'direct_Unit_constructors':constructors,'native_identity_and_frame_calls':native,'source_inputs':inputs,
               'notes':['Source call rows are not runtime cases. Offline Unit/Graph shells remain entity_id zero until trusted binding.',
                        'Non-defense retained routes receive failure propagation only; continuation scope remains standard30 first.',
                        'Normal spawn/RNG source calls retain arguments and lexical order; frame scheduling is not proved here.',
                        'Mission commits action.done before level callback; required creation failure retains old entity and stops world. Full callback rollback is not implemented.']}
    dump(HERE/'semantic_inventory.json',inventory)
    report={'status':'static_verified_runtime_pending','production_changed':False,'godot_run':False,'git_run':False,
            'candidate_files':len(candidate),'changed_methods':sum(len(v) for v in changed.values()),
            'unit_declarations':273,'explicit_value_fields':244,'patch_replay_exact':True,
            'method_allowlist_passed':True,'unchanged_creation_rng_frame_call_tokens_and_order':True,
            'normalized_changed_level_function_AST_equal_count':normalized_count,'parser':'gdtoolkit 4.5.0',
            'legacy_parser_memory_projection_count':projection_count,'production_source_raw_unchanged':True,
            'creation_statuses':statuses,'complete_resume':False,
            'remaining':['Actual Godot parse/typecheck, graph v2 and injected creation failure driver.',
                         'Normal successful30wave and8campaign regression; full root/missions/effects commit barriers.',
                         'Future RunSession save entry must require healthy Battle before staging and recheck at capture commit; RNG capture already rejects faults.']}
    dump(HERE/'static_review.json',report)
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
