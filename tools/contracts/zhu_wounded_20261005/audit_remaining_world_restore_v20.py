"""Read-only evidence of exact remaining map/scenery/core bindings after Unit work."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[3]
NAMES=['scripts/run_scenery_state.gd','scripts/run_map_state.gd','scripts/run_visual_graph.gd','scripts/run_battle_root_state.gd','scripts/run_battle_world_core.gd','scripts/game_map.gd','scripts/battle.gd','scripts/campaign_scenery.gd','scripts/campaign_environment.gd','scripts/campaign_city_wall.gd','scripts/campaign_passage.gd','scripts/continue_flow.gd']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    source={n:(ROOT/n).read_text(encoding='utf-8') for n in NAMES}
    scenery=source[NAMES[0]];campaign=source['scripts/campaign_scenery.gd']
    m=re.search(r'const CAMPAIGN_KINDS := (\[[^\n]+\])',scenery);assert m;kinds=json.loads(m.group(1))
    assert '"level5_scenery_state_' not in scenery and '"level8_scenery_state_' not in scenery
    assert 'CityWall' in campaign and 'Passage' in campaign and 'CanvasModulate.new()' in campaign and 'PointLight2D.new()' in campaign
    gate=re.search(r'func _player_context_supported\(\) -> bool:\n\treturn ([^\n]+)',source['scripts/continue_flow.gd']);assert gate
    evidence={'declaration_audit_complete':True,'existing_campaign_kinds':kinds,'missing_chapter_scenery_schemas':['level5','level8'],
      'gao':{'campaign_environment_enabled':False,'production_reason':'CampaignEnvironment.LEVELS excludes level5; normal launch uses native Liangshan scenery, map/environment identity must be bound to installed Gao chapter. Merely adding level5 to campaign _campaign_enabled would wrongly require CampaignScenery.',
        'required':['Dedicated installed Gao native-scenery identity/schema while reusing qualified Liangshan node/material/navigation decoder.','Original60x60 native-height/shore navigation and all shipyard/building footprints, original private RNG and scenery-owned arrays/entrance/flags.']},
      'daming':{'unhandled_production_types':['CanvasModulate LanternNight','PointLight2D lanterns/Cuiyun','campaign_city_wall.gd CityWall','campaign_passage.gd Passage'],
        'state_requiring_restore':['Fixed night tint and shared generated lantern gradient texture identity.','Cuiyun lamp energy0.45/1.15 follows actual source signal state.','Wall end_local/height_scale/salt; derived mesh rebuilt from those fixed values.','Passage map pointer/caption/object_key and cached _open; navigation tables remain gameplay authority.','CampaignScenery _walls/_sprites/_trees/_ground_shadows and shared _lantern_texture/_cuiyun_light ownership.'],
        'required':['Extend fixed node factories/field contracts for installed Daming context only; preserve original hierarchy, lighting/resources and dynamic states.','Capture/restore gate/wicket/prison navigation and scenery in staged detached world, without re-running deploy or reward/mission callbacks.']},
      'outer_remaining':['Visual partition installed chapter identities/schemas and original effect ownership.','Battle root installed level5/8 capture eligibility and model-specific queues/resources/states.','World core: Gao token level5:end validated before Unit preparation; inert Level shell then actual Mission-owned end_button binding, final Level restore and cross-component consistency.','Independent real process save/exit/continue/resave, paid production/ship/transport and natural ending/reward-once proofs; existing chapter/mode regression before player entry.'],
      'public_campaign_entry_qualified':False,'public_save_gate_expression':gate.group(1),'runtime_qualified':False,
      'sources':[{'path':n,'sha256':sha(ROOT/n)} for n in NAMES],'producer_sha256':sha(Path(__file__)),
      'scope':'Exact current-source inspection. This is remaining-work evidence, not map/scenery/world runtime acceptance. Current Unit v19c is separately pending its active engine wrapper.'}
    p=ROOT/'qa/zhu_wounded_20261005/remaining_world_restore_audit_v20.json';assert not p.exists();p.write_bytes((json.dumps(evidence,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'missing_scenery_chapters':2,'daming_unhandled_types':4,'runtime_qualified':False,'public_campaign_entry_qualified':False}))
if __name__=='__main__':main()
