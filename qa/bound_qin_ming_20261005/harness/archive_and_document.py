"""Authenticate reviewed final artifacts, preserve failures and update handoff."""
from pathlib import Path
import sys,json,hashlib,shutil
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent.resolve();qa=repo/'qa/bound_qin_ming_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
success=[];failed=[]
for p in sorted(base.glob('20261005_*/evidence/receipt.json')):
    r=json.loads(p.read_text(encoding='utf-8'))
    (success if r.get('complete') else failed).append((p,r))
assert len(success)==1
receipt,r=success[0];evidence=receipt.parent
assert r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as driver
assert not driver.source_changes(repo,r['source_files'])
assert sha(repo/'tools/qin_ming_bound_qa.gd')==r['qa_sha256']
review=json.loads((qa/'visual_review.json').read_text(encoding='utf-8'))
assert review['complete'] and review['passed']
report=json.loads((evidence/'bound_qin_ming/report.json').read_text(encoding='utf-8'))
assert {x['sha256'] for x in review['screenshots']}=={x['sha256'] for x in report['screenshots']}
for row in review['screenshots']:assert sha(Path(row['path']))==row['sha256'] and row['passed']
index=[]
def copy(src,relative):
    dst=qa/relative;assert dst.resolve().is_relative_to(qa.resolve())
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
    index.append({'path':relative,'sha256':sha(dst),'bytes':dst.stat().st_size})
for a in r['artifacts']:
    p=evidence/a['path'];assert sha(p)==a['sha256'];copy(p,'final/'+a['path'])
copy(receipt,'final/receipt.json')
failure_rows=[]
for p,fr in failed:
    tag=p.parent.parent.name
    for a in fr['artifacts']:
        src=p.parent/a['path'];assert sha(src)==a['sha256'];copy(src,'failed/'+tag+'/'+a['path'])
    copy(p,'failed/'+tag+'/receipt.json')
    failure_rows.append({'run':tag,'failure':fr['failure'],'receipt_sha256':sha(p),'final_acceptance':False})
bootstrap=json.loads((base/'texture_bootstrap_run.json').read_text())['run'];probe=Path(bootstrap)
for name in ['receipt.json','import.log','dimensions.log','project/dimensions.json','project/probe.gd','project/inputs.json']:
    copy(probe/name,'bootstrap/'+name)
for name in ['texture_bootstrap.py','reproduce.py','cleanup_own_imports.py','resume_when_idle.py','launch_after_idle.py','archive_and_document.py']:
    copy(base/name,'harness/'+name)
for name in ['candidate.json','owned_lock_release.json','contract_lock_release.json']:copy(base/name,name)
(qa/'failures.json').write_text(json.dumps({'complete':True,'failed_engine_batches':failure_rows,'preparation_notes':['Initial metadata source key captured corrected to bound before engine runs.','Source audit invoked before four TRES existed; reordered after native import and resource build.'],'scope':'Preserve unsuccessful evidence; only final complete receipt and visual review qualify this batch.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(qa/'artifact_index.json').write_text(json.dumps({'complete':True,'artifacts':index,'scope':'Exact engine artifacts authenticated to original receipts; supporting harness/probe copies independently hashed.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
checks=report['checks'];terminal=json.loads((qa/'final/terminal_contract/report.json').read_text())['checks'];campaign=len(json.loads((qa/'final/campaign_contract/report.json').read_text())['checks']);screens=len(review['screenshots']);frozen=len(r['source_files'])
header=f'''## 2026-10-05 秦明原关卡被缚四向已验收

从stable 6f2bc37f接续。秦明新增原生1254×1254透明RGBA四向被缚待机及4份TRES，红头巾、卷须、金色兽首肩甲、红袍身份保留；双腕在身前束缚、双手空，专图不再叠旧程序绳线。原像素未裁切、镜像、缩放或编辑，按实际透明缝取样，边界留空16/17像素；原生导入实际尺寸通过，36项来源检查、8项独立元数据/资源复现逐字节一致。

现行祝家庄RTS原七名囚徒及原秦明，用玩家右键和普通3秒办理完成解救，同一演员从中立被缚切为梁山非战斗伤员，速度82、攻击0、能力槽空，头像/HP/战斗值保留；清空variant后切回既有四向走路并执行普通移动。{checks}/{checks}本批原生、{terminal}/{terminal}终态服装契约、{campaign}/{campaign}战役素材契约、8/8公共路由与当前盘点通过；{frozen}冻结输入及私有副本零漂移，{screens}张最终截图直接审核。其他五名程序被缚角色保留原静态/动画路线。旧三日绑定/解救另用显式新建演员夹具做兼容检查，不能替代当前RTS流程。

原救援者接触位置、无关单位冻结及摄影方向/走路相位为显式夹具；Battle协调器继续运行，时间倍率1。未验证入庄破门、整章自然胜利、战役独立进程续玩或长期性能。复用本批失败导入缓存后重新导入，不是无缓存首启资格。三次失败收据与截图保留：其他人物无idle帧时测试越界已改为兼查静态身体；外部引擎占用导致阶段拒绝，遵照用户自然等待，后续阶段会等待空闲且不控制其他任务；旧素材契约把所有变体当武松取头像，被董超/薛霸既有身份守卫拒绝，现按真实owner检查并保留错owner拒绝断言。详见[本批QA](../qa/bound_qin_ming_20261005/README.md)。

下一批继续按现行祝家庄RTS用途补时迁、杨林、黄信、王英、邓飞被缚四向，石秀保留现有专图；获救后仍是非战斗伤员。现行八关需求还需逐章动态核对，旧347项台账不能当当前覆盖率。全库美术、战役续玩与结果/奖励一次性、九模式、约10分钟性能/清理、Android真机及平台资格仍开放。

本轮仅按白名单提交推送codex/sync-20260905-stable；实际提交/清理数量见当轮收据。main保持6085f89f，未打包或发布Steam/Android。下方为历史记录。

'''
for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md']:
    p=repo/'docs'/name;p.write_bytes(header.encode('utf-8')+p.read_bytes())
setup='''## 2026-10-05 原祝家庄秦明被缚与解救验收

    python -X utf8 -B tools/run_qin_ming_bound_qa.py --repo <当前checkout> --manifest bound_qin_ming=assets/direction4/bound_qin_ming_20261005.json --work-root <工程外QA目录> --shared-checks

默认只读预检；引擎空闲后加 --run。可加 --cache-from <同源私有批>，必须记录缓存来源。该专用待机不是秦明通用五状态包；每个执行阶段等待共享引擎自然空闲，不控制其他应用。按请求/参考/native PNG SHA重建的 prepare.py 与 build_directional_spriteframes.py只生成资源元数据，不改像素。普通启动方式不变。[QA与边界](../qa/bound_qin_ming_20261005/README.md)。

'''
p=repo/'docs/SOURCE_SETUP.md';p.write_bytes(setup.encode('utf-8')+p.read_bytes())
directory='''## 2026-10-05 秦明专用被缚四向

- `assets/characters/qin_ming_bound_20261005/`：原生透明四向被缚图与原生导入描述；PNG保持原字节。
- `assets/direction4/bound_qin_ming_20261005.json`、`assets/anim/bound_qin_ming_idle_*.tres`：四个独立取样区域与脚点/身体高度元数据，待机专用。
- `tools/contracts/qin_ming_bound_20261005/`：生成请求、参考SHA、原图来源及可复现元数据脚本。
- `tools/qin_ming_bound_qa.gd`、`run_qin_ming_bound_qa.py`：当前RTS原演员与正常右键计时解救；旧三日兼容另列。
- `qa/bound_qin_ming_20261005/`：最终/失败回归、实际画面审核、原生导入、来源/重建、清理及归档索引。

'''
p=repo/'docs/DIRECTORY_INDEX.md';p.write_bytes(directory.encode('utf-8')+p.read_bytes())
requirement='''## 2026-10-05 秦明当前囚徒用途已补

现行祝家庄RTS的bound_qin_ming已使用徒手绳索四向原生专图，正常解救后清空variant、恢复通用身体并保持非战斗伤员。五名囚徒仍为原静态/动画+程序绳索，石秀专图保持。[本批验证](../qa/bound_qin_ming_20261005/README.md)按现行入口；下方旧三日需求仍属历史，不代表当前流程或总覆盖率。

'''
p=repo/'docs/CAMPAIGN_ART_REQUIREMENTS_20260902.md';p.write_bytes(requirement.encode('utf-8')+p.read_bytes())
(repo/'docs/QIN_MING_BOUND_20261005.md').write_text('# 秦明被缚四向（2026-10-05）\n\n'+header+'''运行路由：NATIVE_BOUND_VARIANTS只登记bound_qin_ming→qin_ming，先于旧PROGRAMMATIC_BOUND_VARIANTS取专用TRES；后者保留身份/头像和旧脚本兼容。idle为唯一原生动作；walk/hurt仅保持同向站姿并不声称原生动作，attack/gather/death/down拒绝借通用武器或终态。空/非法动画方向和错owner拒绝；静态两参数预览沿用SE。UI保持原秦明头像，绘制两处旧绳线只对native变体关闭，其他五人不变。

生成请求中的统一50px半格padding未完整满足；原均分前向下边只1px。原图未编辑，最终资源沿真实空透明缝取样，四区域完整覆盖前景且16/17px留空、正方形留边、脚点/高度元数据经过来源审计和实际画面验收。manifest的candidate/pending措辞保留生成阶段原始记录，运行接入资格以final receipt为准。
''',encoding='utf-8')
(qa/'README.md').write_text('# 秦明原关卡被缚四向QA\n\n'+header+'''证据：`final/receipt.json`含冻结清单/步骤/来源/缓存复用；`final/bound_qin_ming/report.json`区分current_rts原演员与legacy显式新建夹具；`visual_review.json`逐图记录；`source_audit.json`、`bounds_audit.json`、`reproduction.json`保留原图/元数据来源链；`bootstrap/`实际原生导入；`failed/`与`failures.json`保留三轮失败；`owned_lock_release.json`记录共享引擎自然空闲后只释放自己已退出批次的锁；`cleanup.json`记录仅本批旧重复imported清理。

完整主项目目标仍开放。冻结/截图验收不代表整章战斗通关、保存退出跨进程续玩、无缓存首启、性能或平台发布资格。
''',encoding='utf-8')
print(json.dumps({'complete':True,'checks':checks,'terminal':terminal,'campaign':campaign,'screenshots':screens,'frozen':frozen,'failed_batches':len(failed),'run':str(evidence.parent)}))
