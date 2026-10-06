"""Publish owned Huang Xin progress only after actual native/clock/Unit receipts."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
START='<!-- huang-xin-traits-gait-v4-current -->';END='<!-- /huang-xin-traits-gait-v4-current -->'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def section(path,body):
    old=path.read_text(encoding='utf-8');block=START+'\n'+body.strip()+'\n'+END+'\n\n'
    if START in old:
        a,b=old.index(START),old.index(END)+len(END);old=old[:a]+block.rstrip()+old[b:]
    else:old=block+old
    path.write_text(old,encoding='utf-8')
s=read(QA/'huang_xin_walk_sources_passing_v4.json');c=read(QA/'huang_xin_walk_cycle_passing_v4.json');u=read(QA/'huang_xin_unit_motion_passing_v4.json')
assert s['passed'] and s['authored_poses']==s['production_pngs']==20
for r in (c,u):assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
assert u['identity_key']=='huang_xin' and len(u['result']['checks'])==52
deng_pending='邓飞四向idle与contact A共8张原生源已直接检查，尚未独立Godot导入/完整步态/实际Unit复验。' if (QA/'deng_fei_contact_a_native_review_v4.json').exists() else '邓飞后续步态与实际Unit仍待完成。'
body=f'''## 2026-10-06 当前增量：黄信稳健军官体态与四步相候选

人物按原著特性与用户要求逐人处理。黄信保持端正上背、自然抬头、稳健军官姿态；武松/林冲挺拔与时迁轻巧机警要求不变。金饰甲片、赭黄头巾/围巾/袖袍及绑腿是既有项目美术设计，具体比例与0.78体高元数据是美术解释，不伪称原著测量或服装规定。七人清单仍为时迁、石秀、秦明、杨林、黄信、王英、邓飞。

20张选用原生1254×1254 RGBA构成四向idle和各向walk_a/passing_a/walk_b/passing_b，20姿态/8资源。独立原尺寸导入、{len(s['checks'])}来源检查通过；真实时钟64截图/20记录/50冻结输入零漂移。矩阵和实际四相直接查看。西南idle首版错误朝右，idle_single2_sw改为朝左后选用；西南四步相使用该修正版作参考。东北walk_b首版重复A支撑脚，B2换成右支撑/左摆脚后选用；西南passing_b首版同样重复A，新passing_b2_sw明确右支撑/左过脚后选用，三份失败原图/请求/判退证据保留。数学guide只提供镜头/腿姿，人物PNG全部内置imagegen原生参考生成/编辑，完整精确请求、失败父图及producer来源链保留，未本地裁切/缩放/镜像/重绘；idle不代替passing。

自身key实际Unit复验52项/80截图/{len(u['inputs'])}冻结输入零漂移；夹具HP110、速度82、攻击0、非英雄/非战斗/槽0逐帧核实。1×/4×起步、停步、转向及实际四相关键帧直接查看。80张原始视口以12.5fps组成6.4秒预览，未连续播放验收或性能计时。自然脚点、后靴幅度、披布/甲片/衣摆连续衔接与原关卡接入仍须审核，production_qualified=false。

本批仅脱离Battle的候选解析器，生产ArtDB/CampaignArt/原解救回调与数值未改，不证明原七人解救/撤回/碰撞/任务/奖励/生产/UI。共享Godot自然等待，不控制或联系其他任务。下一步邓飞及全七人原流程/生产/UI，武松与林冲普通动作衔接。当前八关动态阶段/生产/船体/身份动作UI、跨进程保存退出续玩及奖励一次性、九模式、约10分钟性能/尾帧、Android真机与平台资格仍开放。审核修错后按范围清理、白名单同步stable。本批仅本地，尚未提交、推送、清理、打包或平台发布。以下保留历史阶段记录。

原生产/存档依赖已只读核对：解救回调与Level3获救者校验都要求空art_variant，不能单独改新变体而漏续玩兼容。接入顺序、七人原流程、跨进程保存与奖励一次性证据要求见docs/RESCUED_ART_INTEGRATION_20261006.md及qa/zhu_wounded_20261005/rescued_route_preflight_v4.json，预检不是接入验收。

{deng_pending}
'''
for name in ('WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','CHARACTER_POSTURE_20261006.md'):section(ROOT/'docs'/name,body)
section(QA/'README.md',body);section(HERE/'README.md',body)
setup='''## 2026-10-06 黄信20源候选验证入口

    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_huang_xin_requests_v4.py
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_huang_xin_walk_passing_v4.py
    python -X utf8 -B qa/zhu_wounded_20261005/harness/texture_bootstrap_huang_xin_v4.py <工程外QA根目录> --manifest assets/direction4/zhu_wounded_huang_xin_20261006_walk_passing_v4.json --label huang_xin_walk_passing_v4
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_huang_xin_walk_passing_v4.py --import-receipt <已完成导入receipt.json>
    python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_wounded_huang_xin_20261006_walk_passing_v4.json --write
    python -X utf8 -B tools/directional_character_sources.py assets/direction4/zhu_wounded_huang_xin_20261006_walk_passing_v4.json tools/contracts/zhu_wounded_20261005/generation_huang_xin_walk_passing_v4.json --out qa/zhu_wounded_20261005/huang_xin_walk_sources_passing_v4.json
    python -X utf8 -B qa/zhu_wounded_20261005/harness/huang_xin_walk_preview_v4.py <同一QA根目录>
    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_huang_xin_v4.py <同一QA根目录> --cache-from <已核验私有QA批/project>

每步成功后再执行下一步。候选实际Unit正常Node夹具继承原指令/物理/绘制，只适配候选帧；原Battle/关卡/生产/UI和连续动作另验。引擎用本机忽略配置或参数，共享引擎自然等待。
'''
section(ROOT/'docs/SOURCE_SETUP.md',setup)
index='''## 2026-10-06 黄信候选资源与QA

- assets/characters/huang_xin_wounded_20261005/idle_single_*_v4.png及walk/passing原生PNG：20选用源，失败变体另保留。
- assets/direction4/zhu_wounded_huang_xin_20261006_walk_passing_v4.json、assets/anim/zhu_wounded_v4_huang_xin_gait_passing_*：20姿态/8资源，candidate_only及production_qualified=false。
- tools/contracts/zhu_wounded_20261005/prepare_huang_xin_requests/harnesses/walk_passing_v4.py、generation_huang_xin_walk_passing_v4.json、requests/、jobs/：精确请求与完整原生父图/数学producer来源。
- qa/zhu_wounded_20261005/huang_xin_walk_{texture,sources,cycle}_passing_v4.*及review/native_prompt_set、huang_xin_unit_motion_passing_v4.json/review：真实导入/时钟/Unit收据。
- 黄信专用texture_bootstrap、walk_preview、unit_motion及record/update helper：保留原角色生产者，连续动作与原关卡资格仍开放。
- docs/RESCUED_ART_INTEGRATION_20261006.md及qa/zhu_wounded_20261005/rescued_route_preflight_v4.json：生产解析器/解救回调/存档兼容的只读预检与后续原流程验收计划，未修改生产代码。
- assets/characters/deng_fei_wounded_20261005/idle_single_*_v4.png、walk_a_*_v4.png及deng_fei_fullidle/contact_a_native_review_v4.json：等待期间推进的8张原生单姿态来源，尚不证明Godot/完整步态/Unit通过。
'''
section(ROOT/'docs/DIRECTORY_INDEX.md',index)
print('8 owned Huang Xin handoff blocks updated from actual receipts; full goal open')
