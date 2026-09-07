"""Additional reviewed failure transactions, applied only to candidate strings.

The generated guards preserve every successful expression's evaluation order.
No generic guard is used in place of the explicit refund/replacement transactions.
"""
import re

def split_code(s, separator):
    depth, quote, escape, parts, start = 0, '', False, [], 0
    for i,c in enumerate(s):
        if quote:
            if escape: escape=False
            elif c=='\\': escape=True
            elif c==quote: quote=''
        elif c in '\"\'': quote=c
        elif c=='#': break
        elif c in '([{': depth+=1
        elif c in ')]}': depth-=1
        elif c==separator and depth==0:
            parts.append(s[start:i]); start=i+1
    parts.append(s[start:])
    return parts

def normalize(s):
    """Expand only inline blocks/semicolons in a caller that is being guarded."""
    def code_and_depth(line):
        depth=0; quote=''; escape=False
        for i,c in enumerate(line):
            if quote:
                if escape: escape=False
                elif c=='\\': escape=True
                elif c==quote: quote=''
            elif c in '\"\'': quote=c
            elif c=='#': return line[:i],depth
            elif c in '([{': depth+=1
            elif c in ')]}': depth-=1
        return line,depth
    logical=[]; pending=[]; depth=0
    for line in s.splitlines(True):
        code,delta=code_and_depth(line)
        pending.append(line); depth+=delta
        if depth==0:
            if len(pending)==1: logical.append(line)
            else:
                ind=pending[0][:len(pending[0])-len(pending[0].lstrip('\t'))]
                logical.append(ind+' '.join(code_and_depth(p)[0].strip().removesuffix('\\').rstrip() for p in pending)+'\n')
            pending=[]
    assert not pending and depth==0, ('unbalanced source',pending)
    def line_parts(line):
        ind=line[:len(line)-len(line.lstrip('\t'))]; body=line.strip()
        if body.startswith(('if ','elif ','else:', 'for ', 'while ')):
            cols=split_code(body, ':')
            if len(cols)>1 and ':'.join(cols[1:]).strip():
                return [ind+cols[0]+':\n'] + line_parts(ind+'\t'+':'.join(cols[1:]).strip())
        parts=split_code(body,';')
        if len(parts)>1: return [ind+p.strip()+'\n' for p in parts if p.strip()]
        return [line if line.endswith('\n') else line+'\n']
    return ''.join(p for line in logical for p in line_parts(line))

def harden(out, before, root, load):
    from prepare import one, method, spans

    # Current campaign paid production: refund first and leave completion counts
    # unchanged if the required Unit helper cannot publish a unit.
    refunds = {
      'scripts/levels/level2_jiangzhou_rts.gd': ('\tvar u: Unit=_guard(b,key,CITY_POST+Vector2i(-2,2))\n','int(price.cost_gold),int(price.cost_wood)'),
      'scripts/levels/level3_zhujiazhuang_rts.gd': ('\tvar u: Unit = _guard(b,spec.key,at)\n','g,w'),
      'scripts/levels/level4_lianhuanma_rts.gd': ('\t\tvar u: Unit=_guard(b,key,(NORTH_POST if lane==0 else SOUTH_POST)+Vector2i(-3,0))\n','int(cost.cost_gold),int(cost.cost_wood)'),
      'scripts/levels/level8_daming_rts.gd': ('\t\tvar u=_guard(b,key,(OUTPOST if lane==0 else CITY_POST)+Vector2i(-3,1))\n','int(cost.cost_gold),int(cost.cost_wood)'),
      'scripts/levels/level5_gao_rts.gd': ('\t\tvar u: Unit=_guard(b,key,cell)\n','int(price.cost_gold),int(price.cost_wood)'),
    }
    for name,(marker,cost) in refunds.items():
        s=load(name); ind=marker[:len(marker)-len(marker.lstrip('\t'))]
        s=one(s,marker,marker+ind+'if u == null:\n'+ind+'\tb.add_resources('+cost+',1)\n'+ind+'\treturn\n')
        out[name]=s

    # Replacing the training rider and transferring Gao to land must commit only
    # after the new entity exists; retain original carrier/dummy on failure.
    name='scripts/levels/level4_lianhuanma_rts.gd'; s=load(name)
    s=one(s,'\txu=_actor # A normally re-recruited Xu Ning can still teach after a loss.\n\tif is_instance_valid(dummy): dummy.queue_free(); b.units.erase(dummy)\n\tdummy=b.spawn_at("hook_training_dummy",1,DRILL_ENTRY)\n',
      '\tvar replacement: Unit=b.spawn_at("hook_training_dummy",1,DRILL_ENTRY)\n\tif replacement == null: return\n\txu=_actor # A normally re-recruited Xu Ning can still teach after a loss.\n\tif is_instance_valid(dummy): dummy.queue_free(); b.units.erase(dummy)\n\tdummy=replacement\n')
    out[name]=s
    name='scripts/levels/level5_gao_rts.gd'; s=load(name)
    old='\t\t\tlanded=true\n\t\t\tactor.remove_meta("carried_story_person")\n\t\t\tactor.display_name="张顺·凿船小艇"\n\t\t\tprisoner=b.spawn_at("gao_qiu",0,LANDING)\n'
    new='\t\t\tvar replacement: Unit=b.spawn_at("gao_qiu",0,LANDING)\n\t\t\tif replacement == null: return\n\t\t\tprisoner=replacement\n\t\t\tlanded=true\n\t\t\tactor.remove_meta("carried_story_person")\n\t\t\tactor.display_name="张顺·凿船小艇"\n'
    out[name]=one(s,old,new)

    # Whole authored redeployments reject exhausted capacity before deleting any
    # old world. These are exact counts of their fixed spawn loops, not budgets.
    preflights={
      'scripts/levels/level3_zhujiazhuang.gd': {'_second_day':'11','_third_day':'30'},
      'scripts/levels/level4_lianhuanma.gd': {'_deploy_battle':'18 + (0 if xu_lost else 1)'},
      'scripts/levels/level5_liangshan.gd': {'_start_land':'15','_start_land_closure':'23','_start_final_fleet':'15'},
    }
    for name, specs in preflights.items():
        s=load(name)
        for fn,count in specs.items():
            header='func '+fn+'(b) -> void:\n'
            s=method(s,fn,lambda body,h=header,c=count:one(body,h,h+'\tif not b.entity_ids_available('+c+'):\n\t\tb._gameplay_rng_stop("ENTITY_REDEPLOY_CAPACITY")\n\t\treturn\n'))
        out[name]=s

    name='scripts/levels/level2_jiangzhou.gd'; s=load(name)
    def pursuit(s):
        s=one(s,'\tpursuit_wave_done = true\n','')
        marker='\tvar pursuers: Array = b.spawn_group("guan_dao", 3, Unit.FACTION_GUAN, PLAZA_C, target)\n'
        return one(s,marker,marker+'\tif not b._gameplay_rng_issue.is_empty(): return\n\tpursuit_wave_done = true\n')
    out[name]=method(s,'_spawn_pursuit_wave',pursuit)
    s=out[name]
    for wave,count in [(1,5),(2,6),(3,3)]:
        def wave_commit(body,w=wave,n=count):
            marker='\twave'+str(w)+'_done = true\n'
            body=one(body,marker,'\tif not b.entity_ids_available('+str(n)+'):\n\t\tb._gameplay_rng_stop("ENTITY_CHAPTER_WAVE_CAPACITY")\n\t\treturn\n')
            return body.rstrip()+'\n\tif not b._gameplay_rng_issue.is_empty(): return\n'+marker+'\n'
        s=method(s,'_spawn_wave'+str(wave),wave_commit)
    out[name]=s

    name='scripts/levels/level8_dongchangfu.gd'; s=load(name)
    s=one(s,'\t\t\treinforcements_sent = true\n','')
    marker='\t\t\tb.spawn_group("guan_dao",count,Unit.FACTION_GUAN,Vector2i(39,27),b.map.cell_to_world(Vector2i(30,33)),1)\n'
    out[name]=one(s,marker,marker+'\t\t\tif not b._gameplay_rng_issue.is_empty(): return\n\t\t\treinforcements_sent = true\n')

    name='scripts/levels/level4_lianhuanma.gd'; s=load(name)
    for fn in ['_spawn_battle_enemies','_start_free_battle']:
        def cavalry(body):
            header=body.splitlines(True)[0]
            return one(body,header,header+'\tif not b.entity_ids_available(2 * WAVE_SIZE + 2):\n\t\tb._gameplay_rng_stop("ENTITY_CAVALRY_CAPACITY")\n\t\treturn\n')
        s=method(s,fn,cavalry)
    marker='\t\t\tbattle_started = true\n'
    s=one(s,marker,'\t\t\tif not b.entity_ids_available(2 * WAVE_SIZE + 2):\n\t\t\t\tb._gameplay_rng_stop("ENTITY_CAVALRY_CAPACITY")\n\t\t\t\treturn\n'+marker)
    out[name]=s

    # Guard helpers and all current/retained built-in chapter creation paths.
    # This is fail-stop propagation, not arbitrary custom-hook rollback.
    for p in sorted((root/'scripts/levels').glob('*.gd')):
        name=p.relative_to(root).as_posix()
        if name in ['scripts/levels/skirmish.gd','scripts/levels/skirmish_ai.gd']: continue
        s=out.get(name,p.read_text('utf-8-sig').replace('\r\n','\n'))
        functions={k:s[a:b] for k,(a,b) in spans(s).items()}
        direct={k for k,v in functions.items() if re.search(r'\bb\.spawn_(?:at|unit|group)\(',v)}
        if not direct: continue
        load(name)
        affected=set(direct)
        while True:
            new={k for k,v in functions.items() if any(re.search(r'(?<![\w.])'+re.escape(f)+r'\(b(?:,|\))',v) for f in affected)}
            if new<=affected: break
            affected|=new
        # Direct Unit-returning helpers can be checked at each consumer too.
        unit_helpers={k for k in direct if re.search(r'\)\s*->\s*Unit\s*:',functions[k].splitlines()[0])}
        call_re=re.compile(r'\bb\.spawn_(at|unit|group)\(|(?<![\w.])('+('|'.join(sorted(unit_helpers)) or '(?!)')+r')\(b(?:,|\))')
        for fn in sorted(affected, key=lambda k:spans(s)[k][0], reverse=True):
            a,b=spans(s)[fn]; block=normalize(s[a:b]); lines=block.splitlines(True)
            ret='return'
            header=lines[0]
            if re.search(r'->\s*Unit\s*:',header): ret='return null'
            elif re.search(r'->\s*bool\s*:',header): ret='return false'
            elif re.search(r'->\s*Array(?:\[.*?\])?\s*:',header): ret='return []'
            rebuilt=[]; serial=0
            for index,line in enumerate(lines):
                if index==0 or not line.strip() or line.lstrip().startswith('#'):
                    rebuilt.append(line); continue
                if not call_re.search(line):
                    rebuilt.append(line); continue
                # Assigned results already followed by explicit failure handling
                # (refunds and replacements) must retain that handling unchanged.
                assignment=re.match(r'^(\t+)(?:var\s+)?(\w+)(?:\s*:\s*\w+)?\s*:?=\s*(?:b\.spawn_(?:at|unit|group)|'+('|'.join(sorted(unit_helpers)) or '(?!)')+r')\(',line)
                if assignment:
                    ind,var=assignment.groups(); rebuilt.append(line)
                    next_line=lines[index+1].strip() if index+1<len(lines) else ''
                    if re.match(r'if\s+'+re.escape(var)+r'\s*==\s*null',next_line) or next_line.startswith('if not b._gameplay_rng_issue.is_empty()'):
                        continue
                    if '.spawn_group(' in line:
                        rebuilt.append(ind+'if not b._gameplay_rng_issue.is_empty(): '+ret+'\n')
                    else:
                        rebuilt.append(ind+'if '+var+' == null:\n'+ind+'\tb._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")\n'+ind+'\t'+ret+'\n')
                    continue
                # Direct standalone or loop expressions are made explicit. Calls
                # nested in append/array literals are handled by a balanced scan.
                assert ' if ' not in line.split('(',1)[0], (name,fn,line)
                ind=line[:len(line)-len(line.lstrip('\t'))]
                remainder=line
                while True:
                    m=call_re.search(remainder)
                    if not m: break
                    start=m.start(); op=remainder.find('(',start)
                    depth=0; quote=''; escape=False; end=None
                    for j in range(op,len(remainder)):
                        c=remainder[j]
                        if quote:
                            if escape: escape=False
                            elif c=='\\': escape=True
                            elif c==quote: quote=''
                        elif c in '\"\'': quote=c
                        elif c=='(': depth+=1
                        elif c==')':
                            depth-=1
                            if depth==0: end=j+1; break
                    assert end is not None, ('multiline creation must be manually expanded',name,fn,line)
                    expression=remainder[start:end]; serial+=1; temp='_created_entity_'+str(serial)
                    group=expression.startswith('b.spawn_group(')
                    rebuilt.append(ind+'var '+temp+(': Array = ' if group else ': Unit = ')+expression+'\n')
                    if group:
                        rebuilt.append(ind+'if not b._gameplay_rng_issue.is_empty(): '+ret+'\n')
                    else:
                        rebuilt.append(ind+'if '+temp+' == null:\n'+ind+'\tb._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")\n'+ind+'\t'+ret+'\n')
                    remainder=remainder[:start]+temp+remainder[end:]
                if remainder.strip() != temp: rebuilt.append(remainder)
            newblock=''.join(rebuilt)
            # Propagate local helper faults at the caller boundary, including
            # process/mission callbacks that otherwise continue publishing state.
            lines=newblock.splitlines(True); rebuilt=[]
            for i,line in enumerate(lines):
                rebuilt.append(line)
                if i==0: continue
                code=line.strip()
                if code.startswith(('#','return ','if ','elif ','for ','var _created_entity_')): continue
                if not any(re.search(r'(?<![\w.])'+re.escape(f)+r'\(b(?:,|\))',code) for f in affected if f not in unit_helpers): continue
                if 'func(' in code or '.bind(' in code: continue
                ind=line[:len(line)-len(line.lstrip('\t'))]
                if code.endswith(':'): continue
                rebuilt.append(ind+'if not b._gameplay_rng_issue.is_empty(): '+ret+'\n')
            s=s[:a]+''.join(rebuilt)+s[b:]
        out[name]=s

    # The two production short episodes inherit the guarded base callbacks.
    # Propagate any base fault before an override consumes incomplete deployment.
    for name in ['scripts/levels/level1_huangnigang_short.gd','scripts/levels/level7_kuaihuolin_short.gd']:
        s=load(name); lines=s.splitlines(True); changed=[]
        for line in lines:
            changed.append(line)
            if re.match(r'^\t+super\.(?:deploy|on_start|on_mission_action|on_unit_died|process|_open_showdown)\(b',line):
                ind=line[:len(line)-len(line.lstrip('\t'))]
                changed.append(ind+'if not b._gameplay_rng_issue.is_empty(): return\n')
        out[name]=''.join(changed)

    # These required replacement callbacks can be called after Mission has
    # marked an action complete. Retaining the old entity alone is insufficient:
    # stop the owned world so that outer capture cannot save a half-commit.
    # Expected retryable production failures keep their separate refund path.
    for name in ['scripts/levels/level2_jiangzhou.gd',
                 'scripts/levels/level2_jiangzhou_rts.gd',
                 'scripts/levels/level4_lianhuanma_rts.gd',
                 'scripts/levels/level5_gao_rts.gd',
                 'scripts/levels/level6_yezhulin.gd']:
        s=out[name]
        s=re.sub(r'(?m)^(\t+)if (replacement|rescued) == null:\n\1\treturn\n',
                 lambda m:m[0].replace(m[1]+'\treturn\n',
                 m[1]+'\tb._gameplay_rng_stop("ENTITY_REQUIRED_REPLACEMENT")\n'+m[1]+'\treturn\n'),s)
        out[name]=s
    return out
