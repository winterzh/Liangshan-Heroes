from pathlib import Path
import json,hashlib,shutil
base=Path(__file__).parent
run=base/'20261005_113221_50bc6117'
report=json.loads((run/'evidence/bound_shi_qian/report.json').read_text(encoding='utf-8'))
rejection={'complete':True,'passed':False,'engine_checks_passed':True,'run':str(run),'reason':'Direct visual review: stationary original Qin Ming is a white rectangle in all four bound screenshots. Native route assertions passed but temporary uncached texture resources did not survive Canvas submission. Keep failed visual evidence; cache native bound frames and rerun.','screenshots':report['screenshots']}
(run/'visual_rejection.json').write_text(json.dumps(rejection,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copyfile(base/'launch_receipt.json',base/'launch_receipt_first_visual_rejected.json')
p=base/'launch_when_idle.py';s=p.read_text(encoding='utf-8')
s=s.replace("log=base/('launch_'+str(len(refusals))+'.log')","log=base/('launch_'+str(len(list(base.glob('launch_*.log'))))+'.log')")
p.write_text(s,encoding='utf-8')
for name in ['archive_and_document.py','cleanup_own_imports.py']:
 p=base/name;s=p.read_text(encoding='utf-8')
 if name=='archive_and_document.py':
  s=s.replace("(accepted if r.get('complete') else failed)","(accepted if r.get('complete') and not (p.parent.parent/'visual_rejection.json').exists() else failed)")
  s=s.replace("copy(p,'failed/'+p.parent.parent.name+'/receipt.json')","copy(p,'failed/'+p.parent.parent.name+'/receipt.json')\n    if (p.parent.parent/'visual_rejection.json').exists(): copy(p.parent.parent/'visual_rejection.json','failed/'+p.parent.parent.name+'/visual_rejection.json')")
  s=s.replace("failed_engine_batches", "rejected_batches")
  s=s.replace("秦明四向专图和头像路线保留", "首轮104项断言通过但画面审核发现静止秦明白块，保留该轮失败证据。修复native bound临时资源存续：ArtDB按专图路径持有帧数组，避免Canvas绘制命令使用已释放纹理RID；新增4项画面白块阈值与8项对象存续断言，最终重跑。秦明四向专图和头像路线保留")
 else:
  s=s.replace("if r.get('complete'): success", "if r.get('complete') and not (p.parent.parent/'visual_rejection.json').exists(): success")
 p.write_text(s,encoding='utf-8')
p=base/'sync_batch.py';s=Path('E:/ChatGPT/qa-qin-ming-bound-20261005/sync_batch.py').read_text(encoding='utf-8')
s=s.replace('Qin batch','Shi batch').replace('bound_qin_ming','bound_shi_qian').replace('qin_ming_bound_20261005','shi_qian_bound_20261005').replace('qin_ming_bound_qa','shi_qian_bound_qa').replace('QIN_MING_BOUND','SHI_QIAN_BOUND').replace('6f2bc37fa0b996e2658ac5ea44d444b16cd72f9d','eed82e1330c27dfd07eed6a9cf9a7e2dc59f963a').replace("==14","==8").replace("'screens_reviewed':14","'screens_reviewed':8")
start=s.index("paths=['.gitattributes'");end=s.index("\npaths+=json",start)
s=s[:start]+"paths=['.gitattributes','scripts/art_db.gd','scripts/campaign_art.gd','tools/qin_ming_bound_qa.gd','tools/shi_qian_bound_qa.gd','tools/run_shi_qian_bound_qa.py','assets/direction4/bound_shi_qian_20261005.json']"+s[end:]
s=s.replace('Add native bound Qin Ming art and verify current chapter rescue','Add native bound Shi Qian and retain captive textures during rendering')
p.write_text(s,encoding='utf-8')
p=base/'finish_handoff.py';s=Path('E:/ChatGPT/qa-qin-ming-bound-20261005/finish_handoff.py').read_text(encoding='utf-8')
s=s.replace('bound_qin_ming','bound_shi_qian').replace('QIN_MING_BOUND','SHI_QIAN_BOUND').replace('本轮仅按','本轮只按')
s=s[:s.index("p=qa/'README.md'")]+"p=qa/'README.md';s=p.read_text(encoding='utf-8');s=s.replace('本轮只按白名单',line+'本轮只按白名单',1);p.write_text(s,encoding='utf-8')\nprint(json.dumps({'complete':True,'cleanup_gib':round(clean['removed_bytes']/1024**3,2)}))\n"
p.write_text(s,encoding='utf-8')
print('Visual rejection preserved; acceptance selectors and retry logging updated.')
