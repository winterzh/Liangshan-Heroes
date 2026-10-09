"""Preserve v16a; refresh original living target after real kills and verify effects."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';H=QA/'harness'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_skill_clearance_v16a_99c4958c'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    r=read(RUN/'receipt.json');report=read(RUN/'skills/report.json')
    assert not r['complete'] and r['lock_released'] and report['checks']==733 and len(report['screenshots'])==112
    assert report['failures']==['original skill target remains alive']
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for src,name in [(RUN/'receipt.json','ordinary_skill_clearance_failed_receipt_v16a.json'),(RUN/'skills/report.json','ordinary_skill_clearance_failed_report_v16a.json')]:
        dst=QA/name;assert not dst.exists();shutil.copy2(src,dst);assert sha(dst)==sha(src)
    evidence={'qualified':False,'checks':733,'captures':112,'failures':report['failures'],'lock_released':True,
        'receipt_sha256':sha(RUN/'receipt.json'),'report_sha256':sha(RUN/'skills/report.json'),'log_sha256':sha(RUN/'skills.log'),
        'harnesses':r['harnesses'],'reason':'Wu SW slot2 actual smite killed the retained original enemy. Before slot3 self-buff, fixture reused that dead target and failed its alive check. All native cast phase views were still saved, but the whole batch remains failed.',
        'fix':'Sibling selects a living original enemy from the same pre-existing roster per slot, excludes inappropriate roles, keeps Lin original-hero target rule and verifies each active ability actual result. No spawned dummy, restored enemy HP or production/stat/timer changes.',
        'scope':'Full phase samples acquired but whole mechanical qualification false; later source/visual/effect qualification requires new completed sibling receipt.'}
    p=QA/'ordinary_skill_clearance_rejected_v16a.json';assert not p.exists();p.write_bytes((json.dumps(evidence,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    text=(H/'ordinary_skill_clearance_v16a.gd').read_text(encoding='utf-8')
    old='\t\tcheck(alive(enemy),"original skill target remains alive")\n\t\tvar aid: String=u.ability_slots[slot].id;var prefix:=key+"_"+str(slot)+"_"+d'
    new='''\t\tvar aid: String=u.ability_slots[slot].id;var prefix:=key+"_"+str(slot)+"_"+d
\t\t# Real preceding skill damage can kill a target. Choose another original
\t\t# living roster member; never restore HP or inject an opponent.
\t\tvar living: Array=foes.filter(func(e):return alive(e))
\t\tcheck(not living.is_empty(),"original living rule-valid target available "+prefix)
\t\tif living.is_empty():continue
\t\tenemy=living[0];enemy.position=center+v*60.0;b._grid_build()
\t\tvar hp_before: float=enemy.hp
\t\tart_runtime.append({"case":"original_target","ability":aid,"actor":key,"direction":d,"enemy_key":enemy.key,
\t\t\t"entity_id":enemy.entity_id,"hp":enemy.hp,"max_hp":enemy.max_hp,"atk":enemy.atk,"hero":enemy.is_hero,"in_original_roster":foes.has(enemy),"target_injected":false})'''
    assert text.count(old)==1;text=text.replace(old,new)
    old='\t\tu.order_stop();u.passive=true;await _wait(0.4);u.set_physics_process(false)'
    new='''\t\tvar hp_after: float=enemy.hp if is_instance_valid(enemy) else 0.0
\t\tmatch aid:
\t\t\t"wu_tigers":check(b.units.filter(func(e):return alive(e) and e.key=="tiger_summon" and e.faction==u.faction).size()==2,"actual two summoned tigers "+prefix)
\t\t\t"wu_wine":check(u._drunk_t>0.0,"actual wine timed buff "+prefix)
\t\t\t"wu_blades":check(hp_after<hp_before and (hp_after<=0.0 or enemy._def_down>0.0 and enemy._blind_t>0.0),"actual smite damage and living-victim statuses "+prefix)
\t\t\t"wu_drunkgod":check(u._phys_immune_t>0.0,"actual timed physical immunity "+prefix)
\t\t\t"lin_thrust":check(hp_after<hp_before,"actual thrust damage "+prefix)
\t\t\t"lin_sweep":check(u._lin_guard_t>0.0,"actual timed spear guard "+prefix)
\t\t\t"lin_chrono":check(b._lin_duels.any(func(duel):return duel.caster==u and duel.target==enemy),"actual original hero duel registered "+prefix)
\t\tart_runtime.append({"case":"cast_effect","actor":key,"direction":d,"ability":aid,"enemy_before_hp":hp_before,"enemy_after_hp":hp_after,
\t\t\t"cooldown":u.ability_slots[slot].get("cd_t",0.0),"physical_immunity_t":u._phys_immune_t,"drunk_t":u._drunk_t,"spear_guard_t":u._lin_guard_t})
\t\tu.order_stop();u.passive=true;await _wait(0.4);u.set_physics_process(false)'''
    assert text.count(old)==1;text=text.replace(old,new).replace('ordinary_skill_clearance_v16a','ordinary_skill_clearance_v16b')
    p=H/'ordinary_skill_clearance_v16b.gd';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    text=(H/'run_ordinary_skill_clearance_v16a.py').read_text(encoding='utf-8').replace('ordinary_skill_clearance_v16a','ordinary_skill_clearance_v16b')
    p=H/'run_ordinary_skill_clearance_v16b.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'prepared':True,'v16a_preserved':True,'v16a_qualified':False,'expected_captures':112,'effects_added':28,'production_changed':False}))
if __name__=='__main__':main()
