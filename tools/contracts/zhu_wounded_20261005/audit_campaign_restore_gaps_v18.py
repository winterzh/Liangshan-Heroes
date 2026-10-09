"""Read installed source declarations to identify remaining campaign restore gates."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    source_names=['scripts/campaign.gd','scripts/run_official_restore_profile.gd','scripts/run_battle_world_core.gd',
        'scripts/run_campaign_level_state.gd','scripts/run_campaign_presentation_state.gd','scripts/continue_flow.gd',
        'scripts/levels/level5_gao_rts.gd','scripts/levels/level8_daming_rts.gd']
    source={n:(ROOT/n).read_text(encoding='utf-8') for n in source_names}
    campaign=source['scripts/campaign.gd'];profiles=source['scripts/run_official_restore_profile.gd']
    rows=[]
    for index,(level_id,title,path) in enumerate(re.findall(r'\{"id": "(level[1-8])", "title": "([^"]+)"[^\n]*?"script": "res://([^"]+)"',campaign)):
        factory=f'scripts/run_{level_id}_world_factory.gd'
        registered_profile=bool(re.search(r'const \w+_CONTEXT := \{"mode": "campaign", "level_id": "'+level_id+r'"',profiles))
        rows.append({'index':index,'level_id':level_id,'title':title,'installed_level_script':path,'factory_path':factory,
            'factory_exists':(ROOT/factory).is_file(),'profile_context_declared':registered_profile,
            'level_component_declared':('"'+level_id+'":') in source['scripts/run_campaign_level_state.gd'],
            'qualification':'Declaration inventory only; not actual restore/continue or natural chapter proof.'})
    assert len(rows)==8 and {r['level_id'] for r in rows}=={'level'+str(i) for i in range(1,9)}
    missing=[r['level_id'] for r in rows if not r['factory_exists'] or not r['profile_context_declared']]
    flow=source['scripts/continue_flow.gd'];m=re.search(r'func _player_context_supported\(\) -> bool:\n\treturn ([^\n]+)',flow);assert m
    gao=source['scripts/levels/level5_gao_rts.gd']
    result={'source_declaration_audit_complete':True,'campaign_chapters':rows,'missing_declared_factory_or_profile':missing,
        'public_save_gate_expression':m.group(1),'public_campaign_entry_qualified':False,
        'gao_end_button_uses_anonymous_callback':'end_button.pressed.connect(func():' in gao,
        'gao_external_end_button_declared':'"external": "end_button"' in source['scripts/run_campaign_level_state.gd'],
        'gao_named_activation_hook_present':'func activate_mission_button(' in gao,
        'required_work':['Complete installed level5/level8 profile/factory/core bindings; level5 named and reconstructible mission end button with correct callback ownership.',
            'Verify actual boats/transport/production/stages and level references; exit and independent process continue/resave for both chapters; revalidate existing chapter and unsupported-scope guards.',
            'Prove natural endings/reward once and full plan regression before exposing public campaign save entry. Current public save is classic30 only.'],
        'sources':[{'path':n,'sha256':sha(ROOT/n)} for n in source_names],
        'producer_sha256':sha(Path(__file__)),'scope':'Read-only exact current-source inventory. Missing declarations are evidence of incompleteness; existing declarations are not evidence of functional or platform qualification.'}
    p=ROOT/'qa/zhu_wounded_20261005/campaign_restore_gap_inventory_v18.json';assert not p.exists()
    p.write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'registered_chapters':8,'missing_profile_or_factory':missing,'gao_anonymous_end_button':result['gao_end_button_uses_anonymous_callback'],'public_campaign_qualified':False}))
if __name__=='__main__':main()
