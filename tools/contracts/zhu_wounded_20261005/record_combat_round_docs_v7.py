"""Record scoped default adoption and exact duplicate-cache cleanup without closing full audit."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
path=BASE/'failed_action_import_duplicates_applied_v7.json';cleanup=read(path)
assert cleanup['complete'] and cleanup['protected_hash_drift']==cleanup['keeper_match_hash_drift']==0 and cleanup['deleted_files']==7436 and cleanup['deleted_bytes']==1780976820
summary={k:cleanup[k] for k in ['scope','keeper_receipt','keeper_receipt_sha256','targets','protected_files','matched_bytes','apply_requested','complete','deleted_files','deleted_bytes','producer_sha256','protected_hash_drift','keeper_match_hash_drift','elapsed_seconds']}
summary.update(full_inventory=str(path),full_inventory_sha256=sha(path),different_or_missing_keeper_count=len(cleanup['different_or_missing_kept']),
 restore='Retained failed project source/import descriptors remain. Run Godot editor import in that exact failed project before rechecking it; cached binaries rebuild. Logs, receipts, source PNGs, screenshots, private profiles and saves remain.')
write(QA/'failed_action_import_cleanup_v7.json',summary)
text='''<!-- ordinary-default-combat-v7-current -->
## 2026-10-07 新站姿与武松四向战斗已接入源码默认取图

ArtDB仅对空显式剧情变体的普通武松/林冲登记新idle/walk；普通武松增加四向attack/hurt，Unit将武松加入完整原生攻击绘制白名单，避免重复叠加整图挥动/程序刀影。林冲原四向战斗图继续使用。时迁与其他人物保持各自姿态，孟州武松、押解/囚犯林冲等显式剧情变体仍走原造型。人物数值、技能定义、指令与任务回调未修改。死亡、技能完整演出及连续步态后续继续审核；本轮不将这些未完成项标为合格。

武松斩击西北后腿/后靴修清，新原生actions_nw3_v7.png保留原字节与精确请求/父图。6原生来源（含旧待机）编排20姿态、8战斗资源；attack按蓄势/蓄势/斩击/斩击/收势/同向idle六槽匹配真实命中相位，hurt每向一帧。脚点分别取两只靴子的落地锚点，头部独立测量；正常出手允许身体发力和重心降低，不把斩击拉成直立军姿。原作者候选清单/旧失败来源不改写，当前实际采用范围见qa/zhu_wounded_20261005/ordinary_character_default_routes_v7.json。

私有试接入343项/48截图通过；随后用现行生产脚本原样复制、无私有ArtDB/Unit修改的原祝家庄林冲/大名府武松复验367项/48截图通过。正常时钟1.0，4904来源与105候选/资源输入零漂移，四向正常近战/反击、真实蓄势/命中/收势与恢复行走、原HUD/标准头像/剧情隔离及原数值均核实。直接查看并原字节保留12张实际生产视口；证据ordinary_chapter_combat_production_v7.json及ordinary_combat_production_visual_review_v7.json。显式接触摆位、非参与者冻结、关雾/镜头和阶段冻结是画面夹具，不证明连续播放、技能/死亡、自然通关、存档或性能。

审核本次覆盖状态无阻塞问题后，只清两个指定旧失败批的imported中与保留最新成功生产批同名/大小/SHA256一致的7436个文件，1,780,976,820字节（约1.66GiB）；15274受保护文件与保留缓存匹配SHA零漂移。源图/旧失败图/源码/日志/截图/私有profile/存档和成功批缓存完整保留，两个imported目录保持原处；复查旧失败工程先重新导入。范围及恢复见qa/zhu_wounded_20261005/failed_action_import_cleanup_v7.json。未清主缓存、其他旧批、Git对象或平台包，先前6批只读清单的4.824GiB仍未删除。

下一步按完整DEVELOPMENT_AUDIT_20261006.md继续：连续足底/衣装/武器、两人技能/死亡/多尺寸UI、全库人物、八关动态阶段/生产/船体/身份UI、同版战役保存自然结局/奖励一次、九玩法/发行程序、正常时钟约10分钟尾帧性能与Android实际设备资格。本次是源码默认绘制接入，不是Steam更新或完整目标完成。
<!-- /ordinary-default-combat-v7-current -->

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','CHARACTER_POSTURE_20261006.md','DIRECTORY_INDEX.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md']:
 p=ROOT/'docs'/name;raw=p.read_bytes();assert b'<!-- ordinary-default-combat-v7-current -->' not in raw;p.write_bytes(text.encode('utf-8')+raw)
p=ROOT/'docs/SOURCE_SETUP.md';entry='''\n当前默认绘制复验：python -X utf8 -B qa/zhu_wounded_20261005/harness/ordinary_chapter_combat_production_v7.py --from-receipt <原Battle source baseline收据> --work-root <已完成Wu/Lin gait、Wu combat native bootstrap与v7 pilot的工程外QA目录> --run。工具比原baseline只允许ArtDB/Unit这两份登记变更，冻结现行脚本原样运行，没有私有运行时补丁；该工具是此轮收据的固定producer，后续源码版本需要新baseline/新producer。正常源码启动仍按下文入口；所有本机Godot路径通过忽略配置提供。\n''';p.write_bytes(p.read_bytes()+entry.encode('utf-8'))
p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';rows=p.read_text(encoding='utf-8').splitlines()
for i,row in enumerate(rows):
 if row.startswith('| 原著人物特性、成人比例与动作身份 |'):
  rows[i]='| 原著人物特性、成人比例与动作身份 | 原七人及两人行走候选历史证据保留。新增武松20姿态/8战斗资源及6原生导入；当前空显式变体的Wu/Lin idle/walk和Wu attack/hurt已在源码默认登记。试接入343项/48图，生产脚本原样复验367项/48图/4904+105输入零漂移/无私有补丁，真实四向命中/反击及原HUD；12原生视口直接审查保留 | 默认接入覆盖这些状态，不能替代完整角色/全项目完成。两人连续足底/衣装/武器、技能/死亡/多尺寸UI，七人终态与全库人物/旧头像/特效仍开放 |'
 elif row.startswith('| 审核、修错、有限冗余清理 |'):
  rows[i]='| 审核、修错、有限冗余清理 | 修正武松西北斩击后腿/后靴与四向真实动作；覆盖状态生产审核通过。两个指定旧失败批7436同名/大小/SHA重复imported文件已删，1,780,976,820字节；15274受保护文件及保留匹配缓存零漂移，源码/原图/日志/存档/成功批保留 | 只关闭该两批已核验重复缓存；此前6批4.824GiB只读清单仍未删除。完整目标的审核与相应资格持续开放；旧失败项目需重导入，不删除失败证据或平台包 |'
p.write_bytes(('\n'.join(rows)+'\n').encode('utf-8'))
print(json.dumps({'docs_updated':7,'default_resources':24,'cleanup_files':7436,'cleanup_bytes':1780976820,'full_goal_qualified':False}))
