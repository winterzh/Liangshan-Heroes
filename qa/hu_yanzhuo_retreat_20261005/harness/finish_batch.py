from pathlib import Path
import json,hashlib,shutil,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent.resolve();qa=repo/'qa/hu_yanzhuo_retreat_20261005'
run=base/'20261005_095333_ace621e2';receipt=run/'evidence/receipt.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads(receipt.read_text(encoding='utf-8'))
assert r['complete'] and r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as driver
assert not driver.source_changes(repo,r['source_files'])
qa.mkdir(parents=True,exist_ok=True);index=[]
def copy(src,dst):
 assert dst.resolve().is_relative_to(qa.resolve());dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
 index.append({'path':dst.relative_to(qa).as_posix(),'bytes':dst.stat().st_size,'sha256':sha(dst)})
for a in r['artifacts']:
 p=run/'evidence'/a['path'];assert sha(p)==a['sha256'] and p.stat().st_size==a['bytes'];copy(p,qa/'final'/a['path'])
copy(receipt,qa/'final/receipt.json')
screens=[]
report=json.loads((run/'evidence/hu_yanzhuo/report.json').read_text(encoding='utf-8'))
for row in report['screenshots']:
 p=Path(row['path']);assert sha(p)==row['sha256']
 notes='Direct native render: same authored black horse/armor identity; no new art. Name/healthbar can cover helmet. Scene phase banner stays at preparation wording because the explicit Battle coordinator pause prevents refresh although phase is FIGHT.'
 if row['name']=='hu_normal_hit':notes+=' First normal hit shown; horse/rider lean away, target and number partly occlude. No full hurt-animation qualification.'
 if row['name'] in ['hu_retreated','hu_retreat_persistent']:notes+=' Hu absent from visible battlefield, no corpse; Xu remains at contact point. Living hidden state is established by runtime assertions, not screenshot alone.'
 screens.append(row|{'method':'direct_native_image_view','passed':True,'review':notes})
assert len(screens)==7
review={'complete':True,'passed':True,'screenshots':screens,'scope':'Existing art and atomic normal-damage retreat only. Contact/paused Battle/ordinary Q/frozen units explicit; no natural chapter win, campaign save, long performance or device qualification.'}
(qa/'visual_review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
entry=json.loads((base/'current_entrypoints.json').read_text(encoding='utf-8'))
assert sha(base/'current_entrypoints.json')==sha(base/'current_entrypoints_repeat.json') and len(entry['registered_chapters'])==8 and entry['entrypoints_matching_curated']==1
for path,s in entry['input_sha256'].items():assert sha(repo/path)==s
copy(base/'current_entrypoints.json',qa/'current_entrypoints.json')
copy(base/'campaign_coverage_snapshot.json',qa/'legacy_curated_coverage_snapshot.json')
(qa/'entrypoint_reproduction.json').write_text(json.dumps({'complete':True,'two_runs_byte_identical':True,'sha256':sha(base/'current_entrypoints.json'),'deterministic_payload_sha256':entry['deterministic_payload_sha256'],'scope':'Registered entry/literal evidence only; legacy 31.124% does not qualify actual current eight chapters.'},indent=2)+'\n',encoding='utf-8',newline='\n')
owners=list(base.glob('20261005_*/project/.godot/imported'))
assert owners==[run/'project/.godot/imported'],'Unexpected old cache; inspect before cleanup'
cleanup={'complete':True,'removed_files':0,'removed_bytes':0,'older_own_caches':0,'latest_private_project_retained':str(run/'project'),'scope':'This batch has one latest successful private imported cache and no older own cache to deduplicate. Native images, previous batches, evidence and profiles retained; no file deleted.'}
(qa/'cleanup.json').write_text(json.dumps(cleanup,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
copy(Path(__file__),qa/'harness/finish_batch.py')
(qa/'artifact_index.json').write_text(json.dumps({'complete':True,'scope':'Final engine artifacts authenticated against original receipt SHA; snapshot/harness copies authenticated independently. No failed engine iteration in this batch.','artifacts':index},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
header='''## 2026-10-05 呼延灼正常攻击撤离已验收

从stable 528c8cc6接续。新增原关卡撤离回归：原徐宁正常攻击满血780的原呼延灼，20次伤害后以HP1隐藏，保留同一敵方演员，撤离回调一次、死亡信号零。击杀、赏金/资源、物品编号、攻击者经验及等级无变化；后续伤害/移动/攻击/技能和重复结算被拒绝，超过尸体时长仍存活且隐藏。92/92原生、8/8公共路由及同版盘点通过，4214冻结输入和私有副本零漂移，7张截图直接审核。复用已有成功缓存后重新导入，不是无缓存首启资格。

接战位置、无关单位/被攻击者冻结、通常一级Q学习，以及暂停Battle协调器以排除敌方自动施法均为显式夹具；原单位普攻和已注册剧情回调正常执行。摄影中的准备阶段标题未刷新，不代表phase未进入FIGHT。未改生产玩法或新增原画，不把隐藏撤离画成死亡，不声称整章自然胜利、战役续玩、长期性能或设备通过。详见[本批QA](../qa/hu_yanzhuo_retreat_20261005/README.md)。本批仅一个最新私有缓存，无可清理的本批旧缓存，未删除文件。

当前注册入口对账：八关中7项与旧美术台账脚本不同（level1/2/3/4/5/7/8）；旧347项静态台账的31.124%不能当当前八关覆盖率。新只读入口工具保留当前脚本SHA、字面variant/结算/生成引用，动态循环仍须逐章核对。下一批按现行祝家庄RTS七名非战斗囚徒用途，先补bound_qin_ming专用四向被缚待机，随后其余仍用程序绳索的囚徒；获救后切回通用身体，不能沿用旧三日战斗状态需求。全库美术、战役独立进程续玩、玩法、约10分钟性能/清理、Android真机及平台资格仍开放。

本轮仅按白名单提交推送codex/sync-20260905-stable，实际SHA以远端回读收据为准；main保持6085f89f，未打包或发布Steam/Android。下方为历史记录。

'''
for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md']:
 p=repo/'docs'/name;p.write_bytes(header.encode('utf-8')+p.read_bytes())
setup=repo/'docs/SOURCE_SETUP.md'
instructions='''## 2026-10-05 呼延灼撤离与当前关卡入口验证

    python -X utf8 -B tools/run_hu_yanzhuo_retreat_qa.py --repo <当前checkout> --manifest hu_yanzhuo=assets/direction4/hu_yanzhuo_20261003.json --work-root <工程外QA目录> --shared-checks

上式默认只读预检，共享引擎自然空闲后加 --run；可加 --cache-from <成功私有批>，须记录缓存来源。只读入口对账：

    python -X utf8 -B tools/campaign_art_entrypoint_audit.py --output <工程外输出.json>

入口对账不代表动态生成全量或视觉通过，旧curated覆盖报告的旧脚本计数不能当现行八关资格。普通启动方式不变。详见[QA](../qa/hu_yanzhuo_retreat_20261005/README.md)。

'''
setup.write_bytes(instructions.encode('utf-8')+setup.read_bytes())
indexp=repo/'docs/DIRECTORY_INDEX.md'
indexp.write_bytes('''## 2026-10-05 撤离回归与入口对账

- `tools/hu_yanzhuo_retreat_qa.gd`、`run_hu_yanzhuo_retreat_qa.py`：原关卡、原780血呼延灼、普通攻击及非死亡结果边界验收，复用共享冻结/引擎/私有档守卫。
- `tools/campaign_art_entrypoint_audit.py`：现行八关注册入口与旧curated台账对账，保留字面引用及源SHA，动态路径另需审核。
- `qa/hu_yanzhuo_retreat_20261005/`：92项原生、7图审核、公共路由/盘点、入口快照、旧台账诊断、复现与无旧缓存清理记录。

'''.encode('utf-8')+indexp.read_bytes())
req=repo/'docs/CAMPAIGN_ART_REQUIREMENTS_20260902.md'
req.write_bytes('''## 2026-10-05 当前入口与历史需求边界

本文件下方是2026-09-02旧脚本需求，不代表当前八幕全部实际状态。当前注册入口中level1/2/3/4/5/7/8已不同；[当前入口SHA与字面引用](../qa/hu_yanzhuo_retreat_20261005/current_entrypoints.json)及[解释](../qa/hu_yanzhuo_retreat_20261005/README.md)已归档。旧curated347项覆盖率仅作历史映射诊断，不能据此宣布现行八关美术完成。制作前逐章核对动态部署和状态切换。

现行祝家庄RTS七名囚徒均为被缚非战斗角色；六名用自己通用身体+程序绳索，石秀有专用图。解救后全部切回通用身体且保持非战斗伤员，不按旧三日战斗需求给他们强制补五状态。下一批先补秦明被缚四向，保留通用战斗/训练/解救语义。

'''.encode('utf-8')+req.read_bytes())
(qa/'README.md').write_text('# 呼延灼正常攻击撤离QA（2026-10-05）\n\n'+header.split('\n\n',1)[1]+'''证据：[最终收据](final/receipt.json)、[92项运行报告](final/hu_yanzhuo/report.json)、[公共路由](final/routing/report.json)、[同版盘点](final/inventory/inventory.json)、[7图审核](visual_review.json)、[当前入口](current_entrypoints.json)、[入口两次复现](entrypoint_reproduction.json)、[旧curated诊断](legacy_curated_coverage_snapshot.json)、[缓存核对](cleanup.json)、[字节索引](artifact_index.json)。本批无失败引擎迭代；游戏生产源和原图保持不变。
''',encoding='utf-8',newline='\n')
print(json.dumps({'complete':True,'checks':report['checks'],'screens_reviewed':len(screens),'frozen_files':len(r['source_files']),'archived_artifacts':len(index),'cleanup_removed_files':0}))
