"""Update owned Deng Fei handoff blocks from actual completed candidate receipts."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
START='<!-- deng-fei-traits-gait-v4-current -->';END='<!-- /deng-fei-traits-gait-v4-current -->'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def section(path,body):
    old=path.read_text(encoding='utf-8');block=START+'\n'+body.strip()+'\n'+END+'\n\n'
    if START in old:
        a,b=old.index(START),old.index(END)+len(END);old=old[:a]+block.rstrip()+old[b:]
    else:old=block+old
    path.write_text(old,encoding='utf-8')
s=read(QA/'deng_fei_walk_sources_passing_v4.json');c=read(QA/'deng_fei_walk_cycle_passing_v4.json');u=read(QA/'deng_fei_unit_motion_passing_v4.json')
assert s['passed'] and s['authored_poses']==s['production_pngs']==20
for r in (c,u):assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
assert u['identity_key']=='deng_fei' and len(u['result']['checks'])==52
sx=read(QA/'shi_xiu_unit_motion_identity_footclear_v4.json')
assert sx['complete'] and sx['identity_key']=='shi_xiu' and sx['input_sha_drift']==0 and len(sx['result']['checks'])==52
failures=sorted(p.name for p in QA.glob('deng_fei_*rejection_v4.json'))
failure_text=('失败首版及原生修正独立保留，判退证据：'+', '.join(failures)+'。') if failures else '本次单姿态检查未判退初版；仍不代表连续动作或生产合格。'
body=f'''## 2026-10-06 当前增量：邓飞粗犷警觉体态与四步相候选

按用户要求逐人处理。邓飞保留粗犷警觉武人体态、健康上背、自然头颈与成人比例，卷发/浓胡须、棕铜甲装与破边披布、锈红发带/腰带及装饰护胫保持既有设计；不带铁链或武器，眼睛自然红棕不发光。具体卷发/服装/0.78体高元数据是项目美术解释，不冒称原著精确外形规定。武松/林冲普通待机挺拔、时迁轻巧机警，不能统一成僵硬军姿。

邓飞20张选用原生1254×1254 RGBA构成四向idle及各向walk_a/passing_a/walk_b/passing_b，共20姿态/8资源。独立原尺寸导入、{len(s['checks'])}来源检查通过；真实时钟64截图/20记录/50冻结输入零漂移，矩阵和实际四相直接查看。{failure_text}数学guide只给镜头/腿姿，不继承其他人物体型。人物PNG全部内置imagegen原生参考生成/编辑，精确请求与原生父图/producer完整来源链保留，未本地裁切/缩放/镜像/重绘，idle不代替passing。

自身key实际Unit复验52项/80截图/{len(u['inputs'])}冻结输入零漂移，逐帧HP110、速度82、攻击0、非英雄/非战斗/槽0。1×/4×起停、反向与实际四相直接查看；80张原始视口以12.5fps组成6.4秒预览，未连续播放验收或性能计时。原指令/物理/绘制继承，仅候选解析器脱离Battle，不证明原七人/碰撞/解救/撤回/奖励/生产/UI。足点、后靴幅度、卷发/披布/甲片/腰带衔接仍需完整动作审核，production_qualified=false。

七人实际名单是时迁、石秀、秦明、杨林、黄信、王英、邓飞。所有七人的完整候选与独立Unit证据现已可供下一轮原流程接入前审查，不能以这些夹具代替生产验收。原解救回调与Level3获救者存档校验都要求空art_variant，修改路由必须同步兼容保存退出续玩；详见docs/RESCUED_ART_INTEGRATION_20261006.md。生产ArtDB/CampaignArt/Unit/回调和任务数值本批未修改。共享Godot自然等待，不控制或联系其他任务。

石秀旧44项收据没有逐帧身份/数值字段，本轮用同一footclear原生资源补独立52项/80截图/{len(sx['inputs'])}输入零漂移，逐帧自身key与非战斗数值核实，旧收据保持原位。七人选用PNG/描述/资源与各自Unit输入交叉核对见docs/RESCUED_ART_CANDIDATE_MATRIX_20261006.md及rescued_seven_candidate_identity_audit_v4.json，范围仍是候选夹具。

邓飞Unit首个私有缓存合并在引擎启动前因同名SHA差异拒绝：旧自动导入mipmap=false/size_limit=0与本批已核验配置不同。第二个新守卫把描述文件前后SHA也强行要求相同，过严而在引擎前拒绝；本轮修正为PNG前后同SHA、描述精确匹配已完成导入收据的after_sha256。新QA只选40个描述对应的本批纹理/sidecar缓存，并记录前后SHA，原缓存与失败批均不删除、不修改；cache_is_not_cold_import=true，不冒称冷导入或性能资格。原生SW B3生成的一次连接失败和成功重试记录也保留。

下一步全七人连续动作审查、原解救/撤回/终态、生产路由/UI和存档兼容，武松/林冲普通动作衔接。原目标中当前八关动态阶段/生产/船体/身份动作UI、跨进程保存退出续玩及奖励一次性、九模式、约10分钟性能/尾帧、Android真机与平台资格仍开放。审核修错后受限清理重复缓存、白名单同步stable；本批仅本地，尚未提交、推送、清理、打包或发布。以下保留历史阶段证据。
'''
for name in ('WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','CHARACTER_POSTURE_20261006.md'):section(ROOT/'docs'/name,body)
section(QA/'README.md',body);section(HERE/'README.md',body)
setup='''## 2026-10-06 邓飞20原生源候选复验入口

    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_deng_fei_walk_passing_v4.py
    python -X utf8 -B qa/zhu_wounded_20261005/harness/texture_bootstrap_deng_fei_v4.py <工程外QA根目录> --manifest assets/direction4/zhu_wounded_deng_fei_20261006_walk_passing_v4.json --label deng_fei_walk_passing_v4
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_deng_fei_walk_passing_v4.py --import-receipt <已完成20源导入receipt.json>
    python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_wounded_deng_fei_20261006_walk_passing_v4.json --write
    python -X utf8 -B tools/directional_character_sources.py assets/direction4/zhu_wounded_deng_fei_20261006_walk_passing_v4.json tools/contracts/zhu_wounded_20261005/generation_deng_fei_walk_passing_v4.json --out qa/zhu_wounded_20261005/deng_fei_walk_sources_passing_v4.json
    python -X utf8 -B qa/zhu_wounded_20261005/harness/deng_fei_walk_preview_v4.py <同一QA根目录>
    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_deng_fei_v4.py <同一QA根目录> --cache-from <已核验私有QA批/project>

精确请求见requests/deng_fei_*_v4.json；完整选用20源提示集见deng_fei_walk_native_prompt_set_v4.json，早期8源partial记录保留。每步成功后再执行下一步。专用正常Node场景继承原Unit，仅适配候选资源，原Battle/关卡/生产/UI/保存兼容及连续动作另验。引擎路径仅用本机忽略配置或参数，共享引擎自然等待。

merge_candidate_import_cache_v4.py按PNG及导入后描述SHA选择本批40个ctex/md5，其他运行缓存仍用已验证私有批；差异和选择写入Unit收据，旧缓存保持不变，不能声称冷导入。石秀补验入口：

    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_shi_xiu_identity_v4.py <同一QA根目录> --cache-from <已验证私有QA批/project>

该正常Node夹具仅增加逐帧身份及8项身份断言，同一20姿态footclear资源不变，原44项记录保留。
'''
section(ROOT/'docs/SOURCE_SETUP.md',setup)
index='''## 2026-10-06 邓飞候选资源与收据

- assets/characters/deng_fei_wounded_20261005/idle_single_*_v4.png、walk_a/b_*_v4.png、passing_a/b_*_v4.png及修正版：20选用原生源，失败父图独立保留。
- assets/direction4/zhu_wounded_deng_fei_20261006_walk_passing_v4.json及assets/anim/zhu_wounded_v4_deng_fei_gait_passing_*：20姿态/8资源，candidate_only，production_qualified=false。
- tools/contracts/zhu_wounded_20261005/prepare_deng_fei_*、generation_deng_fei_walk_passing_v4.json、requests/、jobs/：精确原生请求与完整来源链。
- qa/zhu_wounded_20261005/deng_fei_walk_{texture,sources,cycle}_passing_v4.*、review/native_prompt_set及unit_motion_passing_v4收据/审核：真实导入/时钟/自身Unit证据；早期8源partial记录保持原位。
- 邓飞专用texture_bootstrap/walk_preview/unit_motion及record/update helper：之前角色producer输入保持SHA不变。
- docs/RESCUED_ART_INTEGRATION_20261006.md：七人原流程、生产查询一致性、存档兼容和跨进程奖励一次性接入计划；候选通过不代表原流程完成。
- docs/RESCUED_ART_CANDIDATE_MATRIX_20261006.md、rescued_seven_candidate_identity_audit_v4.json：七人候选来源/资源/自身身份的交叉证据；不是原Battle验收。
- unit_motion_shi_xiu_identity_v4.py/.gd/.tscn与shi_xiu_unit_motion_identity_footclear_v4.json/review：保留旧44项后增加52项逐帧身份复验。
- merge_candidate_import_cache_v4.py及deng_fei_unit_cache_conflict/descriptor_guard_failure_v4.json：候选缓存选择、引擎前拒绝和修复证据；旧私有缓存及失败批不清理。
'''
section(ROOT/'docs/DIRECTORY_INDEX.md',index)
print('8 owned Deng Fei handoff blocks updated from actual receipts; full goal remains open')
