from pathlib import Path
base=Path(__file__).parent
prior=Path('E:/ChatGPT/qa-zhu-captives-bound-20261005')
for name in ['cleanup_own_imports.py','cleanup_when_idle.py']:
    data=(prior/name).read_text(encoding='utf-8').replace('qa/zhu_captives_bound_20261005','qa/current_campaign_art_20261005')
    if name=='cleanup_own_imports.py':
        data=data.replace("for key in ['yang_lin','huang_xin','wang_ying','deng_fei']:\n protected.update(p for p in (repo/f'qa/bound_{key}_20261005').rglob('*') if p.is_file())",'')
    (base/name).write_text(data,encoding='utf-8')
data=(prior/'sync_batch.py').read_text(encoding='utf-8')
data=data.replace('qa/zhu_captives_bound_20261005','qa/current_campaign_art_20261005').replace('980475297f112572c1f8ac748dcb284d726b3377','5eb48b108e66ed129dddd982984df535d0226b8f')
data=data.replace("len(v['screenshots'])==32","len(v['screenshots'])==12")
data=data.replace('tools/zhu_captives_bound_qa.gd','tools/current_campaign_art_qa.gd')
a=data.index("paths=['.gitattributes'");b=data.index('paths=sorted(set(paths))',a)
data=data[:a]+'''paths=['.gitattributes','tools/current_campaign_art_qa.gd','tools/run_current_campaign_art_qa.py']
paths+=['docs/'+name for name in ['WORKLOG.md','SOURCE_SETUP.md','DIRECTORY_INDEX.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md','CAMPAIGN_ART_REQUIREMENTS_20260902.md','CURRENT_CAMPAIGN_ART_20261005.md']]
paths+=[p.relative_to(repo).as_posix() for p in qa.rglob('*') if p.is_file()]
''' +data[b:]
data=data.replace('Add native bound art for four remaining Zhu prisoners and verify rescue','Inventory current campaign openings and verify original seven prisoner evacuation')
data=data.replace('final/zhu_captives_bound/report.json','final/current_campaign_art/report.json').replace("'screens_reviewed':32","'screens_reviewed':12")
data=data.replace("'terminal_checks':json.loads((qa/'final/terminal_contract/report.json').read_text())['checks'],'campaign_checks':len(json.loads((qa/'final/campaign_contract/report.json').read_text())['checks']),",'')
(base/'sync_batch.py').write_text(data,encoding='utf-8')
print('Prepared restricted cleanup and sync scripts')
