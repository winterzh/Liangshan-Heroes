"""Authenticate final all-four evidence, retain first failure and update project handoffs."""
from pathlib import Path
import sys,json,hashlib,shutil
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;qa=repo/'qa/zhu_captives_bound_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
accepted=[];failed=[]
for p in sorted(base.glob('20261005_*/evidence/receipt.json')):
 r=json.loads(p.read_text(encoding='utf-8'));(accepted if r.get('complete') else failed).append((p,r))
assert len(accepted)==1
p,r=accepted[0];e=p.parent
assert r['lock_released'] and not r['source_changes'] and not r['private_source_changes'] and r['qa_unchanged'] and r['driver_unchanged'] and r['godot_unchanged']
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as driver
assert not driver.source_changes(repo,r['source_files']) and sha(repo/'tools/zhu_captives_bound_qa.gd')==r['qa_sha256']
report=json.loads((e/'zhu_captives_bound/report.json').read_text(encoding='utf-8'));v=json.loads((qa/'visual_review.json').read_text(encoding='utf-8'))
assert report['passed'] and v['complete'] and v['passed'] and len(v['screenshots'])==32
assert {x['sha256'] for x in report['screenshots']}=={x['sha256'] for x in v['screenshots']}
for x in v['screenshots']:assert x['passed'] and sha(Path(x['path']))==x['sha256']
index=[]
def copy(src,path):
 dst=qa/path;assert dst.resolve().is_relative_to(qa.resolve());dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst);index.append({'path':path,'sha256':sha(dst),'bytes':dst.stat().st_size})
for receipt,data in [accepted[0],*failed]:
 prefix='final' if data['complete'] else 'failed/'+receipt.parent.parent.name
 for a in data['artifacts']:
  src=receipt.parent/a['path'];assert sha(src)==a['sha256'];copy(src,prefix+'/'+a['path'])
 copy(receipt,prefix+'/receipt.json')
probe=Path(json.loads((base/'texture_bootstrap_run.json').read_text(encoding='utf-8'))['run'])
for name in ['receipt.json','import.log','dimensions.log','project/dimensions.json','project/probe.gd','project/inputs.json']:copy(probe/name,'bootstrap/'+name)
for name in ['prepare_candidates.py','texture_bootstrap.py','reproduce.py','prepare_launch.py','launch_when_idle.py','prepare_finish_scripts.py','cleanup_own_imports.py','cleanup_when_idle.py','archive_and_document.py','sync_batch.py','finish_handoff.py','save_visual_review.py']:copy(base/name,'harness/'+name)
for name in ['candidates.json','launch_receipt.json','first_launch_receipt.json','preflight.log']:copy(base/name,name)
(qa/'artifact_index.json').write_text(json.dumps({'complete':True,'artifacts':index,'scope':'Exact final and first failed engine artifacts plus dimension, candidate, preparation and finish evidence copies.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
checks=report['checks'];terminal=json.loads((e/'terminal_contract/report.json').read_text())['checks'];campaign=len(json.loads((e/'campaign_contract/report.json').read_text())['checks']);frozen=len(r['source_files'])
header=f'''## 2026-10-05 祝家庄剩余四名被缚囚徒已验收

从stable 9804752接续，杨林、黄信、王英、邓飞各新增1张原生1254×1254透明RGBA四向被缚待机及4份TRES，共16独立站姿。杨林保留黑巾、豹纹布衣、蓝腰带与绑腿，黄信保留黄巾、黄衣黑金札甲并移除背旗，王英保留红巾红衣皮甲及矮壮体态，邓飞保留卷发浓须、褐衣甲并移除铁链。双腕在身前、双手空、身上绳索，后视手腕自然遮挡；无武器、旗杆或坐骑。王英以0.70身体高度比例保持短壮，其他三人0.78，不改变半径/速度/战斗数值。内置imagegen首版黄信SW朝向错误，内置编辑纠正，父图和两次完整请求保留。生成/编辑结果均按原字节保存，未在本地裁切、镜像、缩放或绘制PNG；取样实际留边17–35px，通过147项来源、16项边界与32项独立元数据/资源逐字节重建。

现行祝家庄RTS原七名囚徒中四名目标，通过玩家右键和普通3秒办理回调获救；原七人实例、HP/战斗值/头像格保留，变为梁山非英雄、非战斗伤员，速度82、攻击0、能力槽空、variant清空，各自执行普通移动。获救仍用现有单朝向走路条/镜像规则和既有武器/背旗外观，本批只补被缚四向待机，不冒充获救专用无武器动画或通用五状态完成。秦明、时迁原生专图以及石秀既有专图继续按各自身份取用。

{checks}/{checks}本批原生和原关卡检查、{terminal}/{terminal}终态服装、{campaign}/{campaign}战役素材契约、8/8公共路由及盘点通过，{frozen}冻结输入及私有副本零漂移，32张最终画面直接审核。首轮348项游戏断言通过但收尾数量门槛失败，复查发现安装身份逐文件断言只用了杨林manifest；修复为逐一检查四人的全部资源，保留首轮失败证据并重新验证。原救援者接触位置、无关单位冻结、摄影方向/走路相位为显式夹具，Battle继续运行、倍率1。未声称破门、整章胜利、完整撤离、独立进程续玩或性能/真机资格；复用此前时迁最终缓存导入，不是无缓存首启。自然等待共享引擎，无其他任务消息或进程控制。详见[本批QA](../qa/zhu_captives_bound_20261005/README.md)。

下一批逐章动态盘点当前八关需求，重点核对现有石秀被缚/获救及七人撤离过程的身份、动作和UI缺口，再补当前关卡剧情变体/场景/特效。旧347项台账不能充当当前覆盖率。完整人物与动作/UI、战役落盘退出跨进程续玩/结果奖励一次性、九模式、约10分钟性能/尾帧/清理、Android真机及平台资格仍开放。

本轮只按白名单提交推送codex/sync-20260905-stable；实际清理/提交/远端回读以本轮收据为准。main保持6085f89f，未打包或发布Steam/Android。下方为历史记录。

'''
for name in ['WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md']:
 dst=repo/'docs'/name;dst.write_bytes(header.encode('utf-8')+dst.read_bytes())
(repo/'docs/ZHU_CAPTIVES_BOUND_20261005.md').write_text('# 祝家庄四名囚徒被缚四向\n\n'+header+'六名历史程序绳索囚徒现均登记原生专图，石秀仍使用既有战役专图。只声明本批四人的被缚站姿及当前正常解救；步行/受伤同向站姿不算原生动作，攻击/采集/死亡/down不借通用身体。新登记复用既有native bound帧持有缓存及两处程序绳索关闭，不更改通用人物、训练、存档、战斗或任务机制。\n',encoding='utf-8')
dst=repo/'docs/SOURCE_SETUP.md';dst.write_bytes('''## 2026-10-05 祝家庄四名原囚徒验收

    python -X utf8 -B tools/run_zhu_captives_bound_qa.py --repo <当前checkout> --manifest zhu_captives_bound=assets/direction4/bound_yang_lin_20261005.json --work-root <工程外QA目录> --shared-checks

该批入口虽然以杨林manifest指定批次，会冻结并逐一核对全部四人的manifest、来源和原生资源。默认只读预检，执行加--run，可通过--cache-from提供同源已验收私有缓存并记录来源；每阶段自然等引擎空闲，无其他应用控制。当前启动方式不变。[QA与边界](../qa/zhu_captives_bound_20261005/README.md)。

'''.encode()+dst.read_bytes())
dst=repo/'docs/DIRECTORY_INDEX.md';dst.write_bytes('''## 2026-10-05 祝家庄剩余四名被缚专图

- `assets/characters/{yang_lin,huang_xin,wang_ying,deng_fei}_bound_20261005/`：原生四向透明站姿与导入描述；黄信native_references保留必需编辑父图，禁止当缓存删去。
- `assets/direction4/bound_<人物>_20261005.json`及`assets/anim/bound_<人物>_idle_*.tres`：只读取样与脚点/身体高度。
- `tools/contracts/<人物>_bound_20261005/`：完整内置生成/编辑请求、原参考SHA与可复現prepare.py。
- `tools/zhu_captives_bound_qa.gd`、`run_zhu_captives_bound_qa.py`：整批冻结、四名原演员与七人正常解救。
- `qa/bound_<人物>_20261005/`：来源/边界/复现；`qa/zhu_captives_bound_20261005/`：最终/失败运行、32张画面及清理证据。

'''.encode()+dst.read_bytes())
dst=repo/'docs/CAMPAIGN_ART_REQUIREMENTS_20260902.md';dst.write_bytes('''## 2026-10-05 当前祝家庄剩余四名被缚身份已补

杨林/黄信/王英/邓飞现用各自徒手身前束腕四向站姿，秦明/时迁和石秀已有专图保留。获救variant清空仍使用既有通用单朝向动画；伤员非战斗不等于已具备无武器获救动画。当前四名原演员/七人解救证据见[本批QA](../qa/zhu_captives_bound_20261005/README.md)，整章撤离及当前八关动态需求继续核对。

'''.encode()+dst.read_bytes())
(qa/'README.md').write_text('# 祝家庄四名原囚徒QA\n\n'+header.replace('[本批QA](../qa/zhu_captives_bound_20261005/README.md)','本目录证据')+'final/receipt.json为冻结与缓存来源；final/zhu_captives_bound/report.json为四名原演员、七人、正常右键/计时解救及全部资源身份断言；visual_review.json逐图审核。failed/保存首轮失败，bootstrap/保存四张原生导入尺寸；各人物QA目录存来源/边界/重建，黄信原编辑父图与请求另在生产来源链保留。cleanup.json仅本批旧重复imported，最新成功副本与原始日志/存档保持。截图瞬时FPS不是性能证据。\n',encoding='utf-8')
for key in ['yang_lin','huang_xin','wang_ying','deng_fei']:
 (repo/f'qa/bound_{key}_20261005/README.md').write_text(f'# {key} 被缚四向来源\n\n来源与边界审计仅证明原生字节、透明取样和可复现资源；最终正常解救与画面证据统一见[整批验收](../zhu_captives_bound_20261005/README.md)。只补被缚待机四向，不算通用五状态或获救无武器动画。\n',encoding='utf-8')
print(json.dumps({'complete':True,'checks':checks,'terminal':terminal,'campaign':campaign,'frozen':frozen,'failed_batches':len(failed)}))
