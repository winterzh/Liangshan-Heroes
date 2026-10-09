"""Update owned Yang Lin handoff blocks only from completed native QA receipts."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / 'qa/zhu_wounded_20261005'
START = '<!-- yang-lin-traits-gait-v4-current -->'
END = '<!-- /yang-lin-traits-gait-v4-current -->'

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def section(path, body):
    old = path.read_text(encoding='utf-8')
    block = START + '\n' + body.strip() + '\n' + END + '\n\n'
    if START in old:
        a, b = old.index(START), old.index(END) + len(END)
        old = old[:a] + block.rstrip() + old[b:]
    else:
        old = block + old
    path.write_text(old, encoding='utf-8')

sources = read(QA/'yang_lin_walk_sources_passing_v4.json')
clock = read(QA/'yang_lin_walk_cycle_passing_v4.json')
unit = read(QA/'yang_lin_unit_motion_passing_v4.json')
assert sources['passed'] and sources['authored_poses'] == 20
for r in (clock, unit):
    assert r['complete'] and r['lock_released'] and r['input_sha_drift'] == 0
assert unit['identity_key'] == 'yang_lin' and len(unit['result']['checks']) == 52
body = f'''## 2026-10-06 当前增量：杨林逐人特征与四步相候选

按用户要求逐人处理：武松、林冲挺拔，时迁机警灵活；杨林保留宽肩窄腰、自然头颈与轻松膝关节的行旅武人体态。具体比例及0.78体高元数据是项目美术解释；豹纹外衣、浅色毛边/袖口、蓝色头巾/腰带/绑腿是既有项目设计，不冒称原著服饰要求。七人实际清单仍是时迁、石秀、秦明、杨林、黄信、王英、邓飞。

杨林20张原生1254×1254 RGBA：四向idle及各向walk_a/passing_a/walk_b/passing_b，20姿态/8资源。{len(sources['checks'])}来源检查、独立原尺寸导入通过；真实时钟64截图/20记录/50冻结输入零漂移。西南walk_b首版重复A支撑脚，失败PNG与请求保留；新B2换脚后选用。原生人物像素全部由内置imagegen参考生成/编辑，完整请求与来源链保留，未本地裁切/缩放/镜像/重绘。数学guide仅提供腿姿和镜头，不继承王英体型。

自身key实际Unit复验52项/80截图/{len(unit['inputs'])}冻结运行输入零漂移；夹具HP110、速度82、攻击0、非英雄/非战斗/槽0。1×/4×起停、转向关键帧及实际四相直接查看，视频仅80张原始视口定帧率预览，未连续播放验收或性能计时。候选解析器脱离原Battle，不证明原七人解救/撤回/碰撞/奖励/生产/UI。脚点、后靴幅度、衣摆/豹纹/腰带连续衔接仍需完整动作审核。

本批生产ArtDB/CampaignArt/原解救回调与数值未修改，production_qualified=false。共享Godot自然等待，不控制或联系其他任务。下一步黄信、邓飞，再推进全七人原流程与生产/UI，武松/林冲普通动作衔接；当前八关动态阶段/生产/船体/身份动作UI、跨进程保存退出续玩及奖励一次性、九模式、约10分钟性能/尾帧、Android真机与平台资格仍开放。审核修错后按范围清理并白名单同步stable。本批仅本地，尚未提交、推送、清理、打包或平台发布。以下保留之前阶段记录。
'''
for name in ('WORKLOG.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','CHARACTER_POSTURE_20261006.md'):
    section(ROOT/'docs'/name, body)
section(QA/'README.md', body)
section(Path(__file__).parent/'README.md', body)
setup = '''## 2026-10-06 杨林20原生源候选复验入口

    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_yang_lin_walk_passing_v4.py
    python -X utf8 -B qa/zhu_wounded_20261005/harness/texture_bootstrap_yang_lin_v4.py <工程外QA根目录> --manifest assets/direction4/zhu_wounded_yang_lin_20261006_walk_passing_v4.json --label yang_lin_walk_passing_v4
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_yang_lin_walk_passing_v4.py --import-receipt <已完成导入receipt.json>
    python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_wounded_yang_lin_20261006_walk_passing_v4.json --write
    python -X utf8 -B tools/directional_character_sources.py assets/direction4/zhu_wounded_yang_lin_20261006_walk_passing_v4.json tools/contracts/zhu_wounded_20261005/generation_yang_lin_walk_passing_v4.json --out qa/zhu_wounded_20261005/yang_lin_walk_sources_passing_v4.json
    python -X utf8 -B qa/zhu_wounded_20261005/harness/yang_lin_walk_preview_v4.py <同一工程外QA根目录>
    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_yang_lin_v4.py <同一工程外QA根目录> --cache-from <已核验私有QA批/project>

每步成功后才运行下一步。专用正常Node夹具继承原Unit，只适配候选帧；原流程/生产/UI与连续步态资格另验。共享引擎自然等待，本机引擎路径仅用忽略文件或环境参数。
'''
section(ROOT/'docs/SOURCE_SETUP.md',setup)
index = '''## 2026-10-06 杨林候选资源与证据

- assets/characters/yang_lin_wounded_20261005/：20选用全画幅idle/四步相原生PNG；walk_b_sw首版判退保留，walk_b2_sw选用。
- assets/direction4/zhu_wounded_yang_lin_20261006_walk_passing_v4.json及assets/anim/zhu_wounded_v4_yang_lin_gait_passing_*：20姿态/8资源，candidate_only，production_qualified=false。
- tools/contracts/zhu_wounded_20261005/prepare_yang_lin_*、generation_yang_lin_walk_passing_v4.json、requests/、jobs/：精确请求、原生父图与数学producer完整来源链。
- qa/zhu_wounded_20261005/yang_lin_walk_{texture,sources,cycle}_passing_v4.*、walk_passing_review、walk_native_prompt_set及unit_motion_passing收据/审核：实际导入/时钟/Unit证据，连续动作与原流程资格开放。
- 杨林专用texture_bootstrap/idle_preview/walk_preview/unit_motion及record/update helper；保留之前角色收据所依赖的producer。
'''
section(ROOT/'docs/DIRECTORY_INDEX.md',index)
print('8 owned Yang Lin progress/setup/index blocks updated; full objective remains open')
