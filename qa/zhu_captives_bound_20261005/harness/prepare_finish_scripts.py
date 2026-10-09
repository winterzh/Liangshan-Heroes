from pathlib import Path
base=Path(__file__).parent;previous=Path('E:/ChatGPT/qa-shi-qian-bound-20261005')
s=(previous/'cleanup_own_imports.py').read_text(encoding='utf-8').replace('qa/bound_shi_qian_20261005','qa/zhu_captives_bound_20261005').replace('Shi Qian QA root','remaining Zhu captives QA root')
s=s.replace("before={str(p):sha(p) for p in sorted(protected)}","for key in ['yang_lin','huang_xin','wang_ying','deng_fei']:\n protected.update(p for p in (repo/f'qa/bound_{key}_20261005').rglob('*') if p.is_file())\nbefore={str(p):sha(p) for p in sorted(protected)}")
(base/'cleanup_own_imports.py').write_text(s,encoding='utf-8')
s=(previous/'cleanup_when_idle.py').read_text(encoding='utf-8').replace('qa/bound_shi_qian_20261005','qa/zhu_captives_bound_20261005');(base/'cleanup_when_idle.py').write_text(s,encoding='utf-8')
s=(previous/'sync_batch.py').read_text(encoding='utf-8').replace('qa/bound_shi_qian_20261005','qa/zhu_captives_bound_20261005').replace('eed82e1330c27dfd07eed6a9cf9a7e2dc59f963a','980475297f112572c1f8ac748dcb284d726b3377').replace('tools/shi_qian_bound_qa.gd','tools/zhu_captives_bound_qa.gd').replace('final/bound_shi_qian/report.json','final/zhu_captives_bound/report.json').replace("==8 and clean", "==32 and clean").replace("'screens_reviewed':8","'screens_reviewed':32").replace('SHI_QIAN_BOUND_20261005.md','ZHU_CAPTIVES_BOUND_20261005.md').replace('Add native bound Shi Qian and retain captive textures during rendering','Add native bound art for four remaining Zhu prisoners and verify rescue')
start=s.index("paths=['.gitattributes'");end=s.index("paths=sorted(set(paths))",start)
s=s[:start]+'''paths=['.gitattributes','scripts/campaign_art.gd','tools/zhu_captives_bound_qa.gd','tools/run_zhu_captives_bound_qa.py']
paths+=['docs/'+name for name in ['WORKLOG.md','SOURCE_SETUP.md','DIRECTORY_INDEX.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md','CAMPAIGN_ART_REQUIREMENTS_20260902.md','ZHU_CAPTIVES_BOUND_20261005.md']]
folders=['qa/zhu_captives_bound_20261005']
for key in ['yang_lin','huang_xin','wang_ying','deng_fei']:
    manifest=f'assets/direction4/bound_{key}_20261005.json'
    paths+=[manifest]+json.loads((repo/manifest).read_text(encoding='utf-8'))['resources']
    folders+=[f'assets/characters/{key}_bound_20261005',f'tools/contracts/{key}_bound_20261005',f'qa/bound_{key}_20261005']
for folder in folders:paths+=[p.relative_to(repo).as_posix() for p in (repo/folder).rglob('*') if p.is_file()]
'''+s[end:]
(base/'sync_batch.py').write_text(s,encoding='utf-8')
s=(previous/'finish_handoff.py').read_text(encoding='utf-8').replace('qa/bound_shi_qian_20261005','qa/zhu_captives_bound_20261005').replace('SHI_QIAN_BOUND_20261005.md','ZHU_CAPTIVES_BOUND_20261005.md');(base/'finish_handoff.py').write_text(s,encoding='utf-8')
print('Finish helpers prepared; no cleanup or Git mutation performed.')
