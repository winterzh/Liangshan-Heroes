"""Add installed chapter selection/inert factories and a reconstructible Gao control."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()=='d561d78c4bb9f6357e24436d2c8cdfddab48a4e2'
    names=['scripts/run_official_restore_profile.gd','scripts/levels/level5_gao_rts.gd'];before={n:sha(ROOT/n) for n in names}
    p=ROOT/names[0];s=p.read_text(encoding='utf-8')
    s=s.replace('const SCHEMA :=', 'const Gao := preload("res://scripts/levels/level5_gao_rts.gd")\nconst Daming := preload("res://scripts/levels/level8_daming_rts.gd")\nconst GAO_ID := "campaign_level5_v1"\nconst DAMING_ID := "campaign_level8_v1"\nconst GAO_CONTEXT := {"mode": "campaign", "level_id": "level5", "waves": 0}\nconst DAMING_CONTEXT := {"mode": "campaign", "level_id": "level8", "waves": 0}\nconst GAO_FLAGS := {"current": 4, "skirmish": false, "skirmish_ai": false, "arena": false, "custom_defense": false, "scenario": false}\nconst DAMING_FLAGS := {"current": 7, "skirmish": false, "skirmish_ai": false, "arena": false, "custom_defense": false, "scenario": false}\nconst SCHEMA :=',1)
    s=s.replace('\treturn _bad("OFFICIAL_CONTEXT_NOT_SUPPORTED")','\tif value.mode == "campaign" and value.level_id == "level5" and value.waves == 0:\n\t\treturn {"ok": true, "context": GAO_CONTEXT.duplicate(), "profile_id": GAO_ID}\n\tif value.mode == "campaign" and value.level_id == "level8" and value.waves == 0:\n\t\treturn {"ok": true, "context": DAMING_CONTEXT.duplicate(), "profile_id": DAMING_ID}\n\treturn _bad("OFFICIAL_CONTEXT_NOT_SUPPORTED")',1)
    s=s.replace('\t\tLIAN_ID:\n','\t\tGAO_ID:\n\t\t\treturn CampaignScript.LEVELS.size() > 4 and CampaignScript.LEVELS[4].id == "level5" and CampaignScript.LEVELS[4].script == (Gao as Script).resource_path\n\t\tDAMING_ID:\n\t\t\treturn CampaignScript.LEVELS.size() > 7 and CampaignScript.LEVELS[7].id == "level8" and CampaignScript.LEVELS[7].script == (Daming as Script).resource_path\n\t\tLIAN_ID:\n',1)
    s=s.replace('[Classic, Zhu, Huang, Yezhu, Jiang, Kuai, Lian]','[Classic, Zhu, Huang, Yezhu, Jiang, Kuai, Lian, Gao, Daming]')
    s=s.replace('\t\tLIAN_ID: return {"ok": true, "flags": LIAN_FLAGS.duplicate()}','\t\tGAO_ID: return {"ok": true, "flags": GAO_FLAGS.duplicate()}\n\t\tDAMING_ID: return {"ok": true, "flags": DAMING_FLAGS.duplicate()}\n\t\tLIAN_ID: return {"ok": true, "flags": LIAN_FLAGS.duplicate()}',1)
    s=s.replace('\t\tLIAN_ID: return Lian','\t\tGAO_ID: return Gao\n\t\tDAMING_ID: return Daming\n\t\tLIAN_ID: return Lian',1)
    s=s.replace('[ZHU_ID, HG_ID, YEZHU_ID, JIANG_ID, KUAI_ID, LIAN_ID]','[ZHU_ID, HG_ID, YEZHU_ID, JIANG_ID, KUAI_ID, LIAN_ID, GAO_ID, DAMING_ID]')
    p.write_bytes(s.encode('utf-8'))
    p=ROOT/names[1];s=p.read_text(encoding='utf-8')
    old='\t\tend_button=Button.new()\n\t\tend_button.text="收兵通关 · 已击退高俅"\n\t\tend_button.pressed.connect(func(): _finish(b,b.mission.has_event("gao_captured")))\n\t\tb.mission._buttons.add_child(end_button)'
    new='\t\tend_button=b.mission.add_level_button("gao_end","收兵通关 · 已击退高俅")\nfunc activate_mission_button(b, button_id: String) -> void:\n\tif button_id == "gao_end": _finish(b,b.mission.has_event("gao_captured"))'
    assert s.count(old)==1;s=s.replace(old,new);p.write_bytes(s.encode('utf-8'))
    parent=ROOT/'scripts/run_level4_world_factory.gd';template=parent.read_text(encoding='utf-8')
    for number,actor,context,filename in [(5,'Gao','GAO_CONTEXT','level5_gao_rts.gd'),(8,'Daming','DAMING_CONTEXT','level8_daming_rts.gd')]:
        s=template.replace('Level4','Level'+str(number)).replace('LEVEL4','LEVEL'+str(number)).replace('level4','level'+str(number)).replace('Lian',actor).replace('LIAN_CONTEXT',context).replace('level'+str(number)+'_lianhuanma_rts.gd',filename)
        if number==5:
            s=s.replace('mission_token: String) -> Dictionary:','mission_token: String, token_to_external: Dictionary = {}) -> Dictionary:')
            s=s.replace('identity.content_version, id_to_unit, next_entity_id, {}, mission_token)','identity.content_version, id_to_unit, next_entity_id, token_to_external, mission_token)')
            s=s.replace('# Level5 owns no external/UI nodes; all named references and pools bind\n\t# through the already-created, gated shared Unit registry.','# The Mission-owned gao_end button must already be recreated and gated.\n\t# Unit and external nodes are supplied by the validated private world owner.')
        p=ROOT/f'scripts/run_level{number}_world_factory.gd';assert not p.exists();p.write_bytes(s.encode('utf-8'));names.append(p.relative_to(ROOT).as_posix())
    record={'applied':True,'parent_commit':'d561d78c4bb9f6357e24436d2c8cdfddab48a4e2','source_delta':[{'path':n,'before_sha256':before.get(n),'after_sha256':sha(ROOT/n)} for n in names],
        'factory_template_sha256':sha(parent),'producer_sha256':sha(Path(__file__)),
        'scope':'Installed selection and inert level/runtime components plus named Mission-owned Gao button. Full graph/unit/boat/transport/production/scenery/core integration and independent restore qualification still required. Public campaign Continue unchanged.',
        'component_qualified':False,'full_world_qualified':False,'public_campaign_entry_qualified':False}
    p=ROOT/'qa/zhu_wounded_20261005/campaign_foundation_patch_v18.json';assert not p.exists();p.write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'production_files':names,'full_world_qualified':False}))
if __name__=='__main__':main()
