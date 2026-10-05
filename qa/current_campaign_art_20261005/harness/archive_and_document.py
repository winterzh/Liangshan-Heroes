"""Archive authenticated current-opening and actual-evacuation evidence."""
from pathlib import Path
import json,hashlib,shutil,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;qa=repo/'qa/current_campaign_art_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
found=[(p,json.loads(p.read_text(encoding='utf-8'))) for p in base.glob('20261005_*/evidence/receipt.json')]
accepted=[(p,r) for p,r in found if r.get('complete')];assert len(accepted)==1
p,r=accepted[0];e=p.parent
assert r['lock_released'] and not r['source_changes'] and not r['private_source_changes'] and r['qa_unchanged'] and r['driver_unchanged'] and r['godot_unchanged']
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as driver
assert not driver.source_changes(repo,r['source_files'])
report=json.loads((e/'current_campaign_art/report.json').read_text(encoding='utf-8'))
v=json.loads((qa/'visual_review.json').read_text(encoding='utf-8'))
assert report['passed'] and v['complete'] and v['passed'] and len(v['screenshots'])==12
assert {x['sha256'] for x in report['screenshots']}=={x['sha256'] for x in v['screenshots']}
for x in v['screenshots']:assert x['passed'] and sha(Path(x['path']))==x['sha256']
source=json.loads((base/'source_review.json').read_text(encoding='utf-8'))
for name,digest in source['input_sha256'].items():assert sha(repo/name)==digest
index=[]
def copy(src,name):
    dst=qa/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
    index.append({'path':name,'sha256':sha(dst),'bytes':dst.stat().st_size})
for receipt,data in found:
    prefix='final' if data['complete'] else 'failed/'+receipt.parent.parent.name
    for a in data['artifacts']:
        src=receipt.parent/a['path'];assert sha(src)==a['sha256'];copy(src,prefix+'/'+a['path'])
    copy(receipt,prefix+'/receipt.json')
for name in ['prepare_launch.py','launch_when_idle.py','source_review.py','prepare_finish.py','cleanup_own_imports.py','cleanup_when_idle.py','archive_and_document.py','sync_batch.py','finish_handoff.py','save_visual_review.py','prepare_opening_reuse.py']:
    copy(base/name,'harness/'+name)
for name in ['source_review.json','launch_receipt.json','first_launch_receipt.json','second_launch_receipt.json','third_launch_receipt.json','fourth_launch_receipt.json','fourth_lock_release.json','opening_reuse_receipt.json','interruption.json','preflight.log']:copy(base/name,name)
proof=json.loads((repo/'tools/contracts/current_campaign_opening_20261005/snapshot.json').read_text(encoding='utf-8'))
for name,digest in proof['source_evidence_sha256'].items():
    path=repo/name;assert sha(path)==digest
    index.append({'path':path.relative_to(qa).as_posix(),'sha256':digest,'bytes':path.stat().st_size})
(qa/'artifact_index.json').write_text(json.dumps({'complete':True,'artifacts':index},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
checks=report['checks'];frozen=len(r['source_files']);chapters=report['resources']
table='| 现行关卡 | 原开场单位 | 身份/变体/阵营组合 |\n| --- | ---: | ---: |\n'+''.join(f"| {x['chapter']} | {x['original_unit_count']} | {len(x['units'])} |\n" for x in chapters)
evac=[x for x in report['runtime'] if x['case']=='seven_actual_return']
dist=f"{min(x['distance_moved'] for x in evac):.1f}–{max(x['distance_moved'] for x in evac):.1f}"
headline=f'''## 2026-10-05 当前八关开场与祝家庄七人实际撤回已核验

从stable 5eb48b1接续。先前通过Campaign.LEVELS实际启动全部八关，记录{sum(x['original_unit_count'] for x in chapters)}个原开场单位、{sum(len(x['units']) for x in chapters)}项按人物/变体/阵营合并的身份记录，包括真实UI头像、身体取图、六状态四向资源查询和建筑可生产名单。开场不是全阶段需求；资源查询、方向fallback不算原生动作或视觉质量。注册/继承源码链另记录10份脚本SHA及引用，旧台账仅1/8入口匹配，因此旧347项与31.124%继续禁止当当前覆盖率。后续生产、剧情变身、船体物件路线和继承中被覆盖的函数须继续核对。

原祝家庄石秀保持既有四向bound_shi_xiu，获救后清空variant，切回现有单朝向、双刀行走素材；原HP/头像保持。本轮通过玩家右键、普通1秒侦察、5秒内应及3秒解救完成现行原回调，偏门实际打开。原林冲通过正常普攻清理庄内八名及北矿三名原守军，共11名，不注入伤害、不删除/传送敌兵；敌兵冻结及林冲近战接触位置是显式夹具，不作为自由护送战斗资格。七名原囚徒用四段空地右键移动，真实路径穿过偏门并走至前营，每人位移{dist}逻辑像素，终点距前营均<190；没有注入或传送囚徒。接触位置、摄影方向/走路相位、无关单位及新训练单位冻结为显式夹具，Battle继续运行、倍率1；未验证破门、敌军自由护送战、摧毁大营或整章胜利。大营未破时仍不允许结算，七人安全事件没有被提前奖励。

{checks}/{checks}专项断言、8/8公共路由及当前盘点通过，{frozen}冻结输入与私有副本零漂移，12张最终原生截图直接审核。最终轮复用已独立通过的八关开场子项：安装源码身份、4,274个原输入及3份原证据哈希全部一致，未声称本轮重新渲染八关；其原完整测试仍因后段撤离失败而保留为失败。首轮八关盘点通过，但路标16,18正占敌军，正常右键被识别为攻击，伤员无法移动；改空地16,23并新增敌军命中守卫及超时位置诊断后，复验发现五人已到、王英和邓飞仍被沿途冻结的守军阻挡，因此改由原林冲普通攻击清路。第三候选复查发现筛选还包含四名敌方工人，核验自身进程身份后只终止该候选以修正筛选；原报告/日志与独立中断记录全部保留，未操作其他任务。第四轮七人已穿过偏门，但北矿守军阻挡43,18路标；保留失败，再补原林冲正常普攻清理三名北矿守军。第四轮结束时因共享引擎占用而保留本任务锁，待自然空闲后核验归属并单独释放，旧失败收据未改写。石秀既有被缚身体是蓝灰短衣、头巾、后束腕，与新六人身前束腕不同，本轮保留并核对路线，不声称重绘或通用身份全统一；开场首张标题刷新滞后、姓名/血条有遮挡，完整UI资格仍开放。截图FPS不构成性能资格。复用前批已验收缓存重新导入，不是无缓存首启；仅自然等待共享引擎，不联系或控制其他任务。

下一批优先补现行祝家庄七人的无武器伤员待机/行走，再按当前八关实际剧情转换、生产队列和船体物件逐章核对后补缺。通用人物与完整动作/身份/UI、战役落盘退出跨进程续玩/结果奖励一次性、九模式、约10分钟性能/尾帧/清理、Android真机及平台资格仍开放。详见[实现与当前入口](CURRENT_CAMPAIGN_ART_20261005.md)、[QA](../qa/current_campaign_art_20261005/README.md)。

本轮只按白名单提交推送codex/sync-20260905-stable；实际清理及SHA见本轮收据。main保持6085f89f，未打包或发布Steam/Android。下方历史记录按各自范围解读。

'''
for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md']:
    dst=repo/'docs'/name;dst.write_bytes(headline.encode('utf-8')+dst.read_bytes())
(repo/'docs/CURRENT_CAMPAIGN_ART_20261005.md').write_text('# 当前战役开场素材与原七人撤回\n\n'+headline+'\n'+table+'\n实际身份、每项资源原路径见QA的final/current_campaign_art/report.json，源码继承及动态引用见source_review.json。船体必须按物件default/damaged等状态核对，不能按人物idle/attack缺帧误判。人物lookup中的idle/方向fallback也不能当exact行走/攻击资格。\n\n开场人物查询中尚未返回全部四向待机的路线包括：江州燕顺、张顺、张横、蔡九；祝家庄祝虎；高太尉章公孙胜、刘唐；快活林施恩；大名府走通用路线的鲁智深、武松。这里只是现行入口下的路由诊断，必须核对其真实用途、生产来源和直接画面后决定新增素材；其他章的同名专用变体不自动覆盖这些通用路线。优先七人无武器伤员，再核对这些人物及各章晚期变体、普通兵和场景/特效/UI。\n',encoding='utf-8')
for name,text in {
    'SOURCE_SETUP.md':'''## 2026-10-05 当前八关与七人真实撤回验收

    python -X utf8 -B tools/run_current_campaign_art_qa.py --repo <checkout> --manifest current_campaign_art=assets/direction4/bound_yang_lin_20261005.json --work-root <工程外QA目录> --shared-checks

默认只读预检，执行加--run；可用--cache-from提供同源私有缓存，逐阶段自然等待共享引擎。入口冻结全部运行输入及四名被缚来源链，杨林manifest仅作为批次入口。现行8开场资源lookup与七人原演员撤离；tools/contracts/current_campaign_opening_20261005/snapshot.json保存独立通过的开场子项，输入及原证据哈希一致才复用，漂移则重新启动全部八关，未含整章战斗/胜利或跨进程续玩。公共启动方式未变。[QA](../qa/current_campaign_art_20261005/README.md)。

''',
    'DIRECTORY_INDEX.md':'''## 2026-10-05 当前八关素材开场与真实撤回

- tools/current_campaign_art_qa.gd与run_current_campaign_art_qa.py：当前注册八关开场、石秀和原七人正常移动验收。
- tools/contracts/current_campaign_opening_20261005/：可核验输入哈希的八关开场子项快照。
- qa/current_campaign_art_20261005/：final、历次失败、opening_evidence原证据、12张最终画面、源码继承引用、隔离/冻结/缓存来源及受限清理证据。
- docs/CURRENT_CAMPAIGN_ART_20261005.md：当前入口范围和开场对照；不替代全阶段覆盖率。

''',
    'CAMPAIGN_ART_REQUIREMENTS_20260902.md':'''## 2026-10-05 当前八关实际开场对账

已由实际注册入口启动八关并记录原开场身份/变体/头像/身体与资源lookup，补源代码继承链。旧347台账仅1个入口与当前一致，不能提供现行覆盖率。现行祝家庄七人确实按玩家命令沿偏门走至前营，但仍用旧武器通用身体，专用无武器伤员待机/行走优先补齐。船体按物件状态检查，人物方向fallback不算精确动作。后续生产、剧情转换、继承/辅助脚本继续逐章核对。[证据](../qa/current_campaign_art_20261005/README.md)。

''',
}.items():
    dst=repo/'docs'/name;dst.write_bytes(text.encode('utf-8')+dst.read_bytes())
(qa/'README.md').write_text('# 当前八关开场与七人真实撤回QA\n\n'+headline.replace('[实现与当前入口](CURRENT_CAMPAIGN_ART_20261005.md)','[实现与当前入口](../../docs/CURRENT_CAMPAIGN_ART_20261005.md)').replace('[QA](../qa/current_campaign_art_20261005/README.md)','本目录证据')+'\n'+table+'\nfinal/receipt.json认证冻结及缓存，final/current_campaign_art/report.json认证325原开场单位和原七人回营；source_review.json保留注册继承及动态来源位置，visual_review.json逐张审核，failed保存首轮失败。所有原始PNG未在本地改动。cleanup.json只针对本批旧重复imported；最新完整缓存、源码、失败日志/截图及私有存档保留。\n',encoding='utf-8')
print(json.dumps({'complete':True,'checks':checks,'frozen':frozen,'chapters':len(chapters),'original_units':sum(x['original_unit_count'] for x in chapters),'evac_distance':dist}))
