"""Authenticate final Shi Qian evidence and update project handoff documents."""
from pathlib import Path
import sys,json,hashlib,shutil
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent.resolve();qa=repo/'qa/bound_shi_qian_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
accepted=[];failed=[]
for p in sorted(base.glob('20261005_*/evidence/receipt.json')):
    r=json.loads(p.read_text(encoding='utf-8'));(accepted if r.get('complete') and not (p.parent.parent/'visual_rejection.json').exists() else failed).append((p,r))
assert len(accepted)==1
receipt,r=accepted[0];evidence=receipt.parent
assert r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as driver
assert not driver.source_changes(repo,r['source_files']) and sha(repo/'tools/shi_qian_bound_qa.gd')==r['qa_sha256']
report=json.loads((evidence/'bound_shi_qian/report.json').read_text(encoding='utf-8'))
review=json.loads((qa/'visual_review.json').read_text(encoding='utf-8'))
assert report['passed'] and review['complete'] and review['passed'] and len(review['screenshots'])==8
assert {x['sha256'] for x in report['screenshots']}=={x['sha256'] for x in review['screenshots']}
for x in review['screenshots']:assert sha(Path(x['path']))==x['sha256'] and x['passed']
index=[]
def copy(src,relative):
    dst=qa/relative;assert dst.resolve().is_relative_to(qa.resolve());dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(src,dst);assert sha(src)==sha(dst);index.append({'path':relative,'sha256':sha(dst),'bytes':dst.stat().st_size})
for a in r['artifacts']:
    p=evidence/a['path'];assert sha(p)==a['sha256'];copy(p,'final/'+a['path'])
copy(receipt,'final/receipt.json')
for p,fr in failed:
    for a in fr['artifacts']:
        src=p.parent/a['path'];assert sha(src)==a['sha256'];copy(src,'failed/'+p.parent.parent.name+'/'+a['path'])
    copy(p,'failed/'+p.parent.parent.name+'/receipt.json')
    if (p.parent.parent/'visual_rejection.json').exists(): copy(p.parent.parent/'visual_rejection.json','failed/'+p.parent.parent.name+'/visual_rejection.json')
probe=Path(json.loads((base/'texture_bootstrap_run.json').read_text(encoding='utf-8'))['run'])
for name in ['receipt.json','import.log','dimensions.log','project/dimensions.json','project/probe.gd','project/inputs.json']:copy(probe/name,'bootstrap/'+name)
for name in ['prepare_candidate.py','prepare_qa.py','texture_bootstrap.py','reproduce.py','launch_when_idle.py','cleanup_own_imports.py','archive_and_document.py','prepare_visual_retry.py','audit_rejected_white_blocks.py','save_visual_review.py','sync_batch.py','finish_handoff.py']:copy(base/name,'harness/'+name)
for name in ['candidate.json','launch_receipt.json','launch_receipt_first_visual_rejected.json']:copy(base/name,name)
(qa/'artifact_index.json').write_text(json.dumps({'complete':True,'artifacts':index,'scope':'Exact final/failed engine artifacts authenticated to original receipt SHA; candidate, import and harness copies independently hashed.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
checks=report['checks'];terminal=json.loads((evidence/'terminal_contract/report.json').read_text(encoding='utf-8'))['checks'];campaign=len(json.loads((evidence/'campaign_contract/report.json').read_text(encoding='utf-8'))['checks']);frozen=len(r['source_files'])
header=f'''## 2026-10-05 时迁原关卡被缚四向已验收

从stable eed82e1接续。内置imagegen新增一张原生1254×1254透明RGBA时迁被缚四向及4份待机TRES。保留portraits18中行右格的黑头巾、蒙面、深灰布衣与绑腿布靴；被缚状态移除背袋，双腕束在身前、双手空，后视手腕自然被身体遮挡。原PNG未裁切、镜像、缩放或绘制；实际导入尺寸一致，取样留边32–34px，36项来源审计、8项独立元数据/来源/资源重建逐字节一致。

现行祝家庄RTS原时迁与原七人队列，经过玩家右键和普通3秒办理回调解救，保持同一演员、当前头像格、HP和战斗值。获救变为梁山非英雄伤员，速度82、攻击0、能力槽空，清空variant后使用既有走路条/镜像规则并执行普通移动。通用时迁仍是旧单朝向走路，不能把本批被缚四向当通用五状态或通用四向行走已完成。首轮104项断言通过但画面审核发现静止秦明白块，保留该轮失败证据。修复native bound临时资源存续：ArtDB按专图路径持有帧数组，避免Canvas绘制命令使用已释放纹理RID；新增4项画面白块阈值与8项对象存续断言，最终重跑。秦明四向专图和头像路线保留，剩余四名程序绳索囚徒保持原静态/动画路线。

{checks}/{checks}本批原生、{terminal}/{terminal}终态服装契约、{campaign}/{campaign}战役素材契约、8/8公共路由与当前盘点通过，{frozen}冻结输入及私有副本零漂移，8张最终画面直接审核。原救援者接触位置、无关单位冻结及摄影方向/走路相位是显式夹具，Battle协调器继续运行、时间倍率1；不代表破门入庄、整章胜利、前营完整撤离或战役独立进程续玩。复用此前秦明成功缓存重新导入，不是无缓存首启资格。阶段间等待共享引擎自然空闲，没有联系或控制盲盒。详见[本批QA](../qa/bound_shi_qian_20261005/README.md)。

下一批按现行祝家庄用途继续补杨林、黄信、王英、邓飞被缚四向，石秀现有专图保留；随后继续逐章动态核对当前八关需求，旧347项台账不能当当前覆盖率。通用人物/动作/身份/UI、战役保存退出跨进程续玩/结果奖励一次性、九模式、约10分钟性能/尾帧/清理、Android真机及平台资格仍开放。

本轮只按白名单提交推送codex/sync-20260905-stable；实际提交、清理及远端回读以当轮收据为准。main保持6085f89f，未打包或发布Steam/Android。下方为历史记录。

'''
for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md']:
    p=repo/'docs'/name;p.write_bytes(header.encode('utf-8')+p.read_bytes())
p=repo/'docs/SHI_QIAN_BOUND_20261005.md';p.write_text('# 时迁被缚四向（2026-10-05）\n\n'+header+'''NATIVE_BOUND_VARIANTS登记bound_shi_qian→shi_qian和既有秦明；复用专用TRES优先路由及两处旧程序绳线关闭逻辑。idle是唯一原生动作，walk/hurt保持同向站姿但不称为原生动作；attack/gather/death/down拒绝借通用战斗或终态。错owner及空/非法动画方向拒绝；静态两参数预览沿用SE，UI使用当前时迁原头像格。获救旧走路与背袋身体保持，仍不可战斗。

参考未裁出人像，生成请求明确指定原portraits18中行右格；整张来源与原走路条SHA均保留，PNG只读测量不输出编辑图。原请求希望50px边距，实际取样32–34px透明留空足够且无前景丢失/重叠；最终资格由运行/来源/画面证据共同建立。
''',encoding='utf-8')
p=repo/'docs/SOURCE_SETUP.md';p.write_bytes('''## 2026-10-05 时迁当前囚徒验收

    python -X utf8 -B tools/run_shi_qian_bound_qa.py --repo <当前checkout> --manifest bound_shi_qian=assets/direction4/bound_shi_qian_20261005.json --work-root <工程外QA目录> --shared-checks

默认只读预检；共享引擎自然空闲后加 --run。可加 --cache-from <同源私有批>，记录缓存来源；执行阶段只等待空闲，不控制其他应用。prepare.py和build_directional_spriteframes.py只写元数据/TRES，PNG保留原字节。通用启动方式不变。[QA与边界](../qa/bound_shi_qian_20261005/README.md)。

'''.encode('utf-8')+p.read_bytes())
p=repo/'docs/DIRECTORY_INDEX.md';p.write_bytes('''## 2026-10-05 时迁专用被缚四向

- `assets/characters/shi_qian_bound_20261005/`：原生透明站立囚徒图和导入描述。
- `assets/direction4/bound_shi_qian_20261005.json`与`assets/anim/bound_shi_qian_idle_*.tres`：四取样区、脚点与身体高度；仅待机专用。
- `tools/contracts/shi_qian_bound_20261005/`：完整生成请求、原参考SHA、来源与可复现元数据脚本。
- `tools/shi_qian_bound_qa.gd`、`run_shi_qian_bound_qa.py`：原时迁、原七人及正常右键/计时解救、旧通用动画保留。
- `qa/bound_shi_qian_20261005/`：冻结收据、实际画面、共享契约、导入/来源/重建及清理证据。

'''.encode('utf-8')+p.read_bytes())
p=repo/'docs/CAMPAIGN_ART_REQUIREMENTS_20260902.md';p.write_bytes('''## 2026-10-05 现行祝家庄时迁被缚用途已补

bound_shi_qian已使用当前黑巾蒙面布衣身份的徒手绳索专图，正常解救后清空variant，继续原单朝向走路且不可战斗。秦明专图保留；杨林、黄信、王英、邓飞仍为程序绳索，石秀现有专图保留。[本批QA](../qa/bound_shi_qian_20261005/README.md)按现行RTS入口，不代表下方旧三日需求或通用时迁动作已补齐。

'''.encode('utf-8')+p.read_bytes())
(qa/'README.md').write_text('# 时迁原关卡被缚四向QA\n\n'+header+'''证据：final/receipt.json保存冻结输入及缓存来源，final/bound_shi_qian/report.json保存原演员/七人/正常计时回调断言；visual_review.json逐图直接审核。bootstrap/保留实际尺寸，source_audit.json、bounds_audit.json与reproduction.json保存原图/来源及只读元数据重建。harness/为本次准备与收尾审计脚本；cleanup.json仅本批旧重复imported清理，不触及前批或主缓存。

画面中瞬时FPS/首帧准备阶段字幕不代表性能资格或错误phase；整章与长期/设备验证仍开放。
''',encoding='utf-8')
print(json.dumps({'complete':True,'checks':checks,'terminal':terminal,'campaign':campaign,'frozen':frozen,'rejected_batches':len(failed),'run':str(evidence.parent)}))
