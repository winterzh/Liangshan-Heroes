"""Update owned Shi Qian progress blocks without overwriting earlier evidence."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / 'qa/zhu_wounded_20261005'
START = '<!-- shi-qian-traits-gait-v4-current -->'
END = '<!-- /shi-qian-traits-gait-v4-current -->'


def section(path, body, after_title=False):
    old = path.read_text(encoding='utf-8')
    block = START + '\n' + body.strip() + '\n' + END + '\n\n'
    if START in old:
        a = old.index(START)
        b = old.index(END, a) + len(END)
        old = old[:a] + block.rstrip() + old[b:]
    elif after_title:
        i = old.index('\n')
        old = old[:i+1] + '\n' + block + old[i+1:]
    else:
        old = block + old
    path.write_text(old, encoding='utf-8')


unit = QA / ('shi_qian_unit_motion_footclear_v4.json' if (QA / 'shi_qian_unit_motion_footclear_v4.json').exists() else 'shi_qian_unit_motion_passing_v4.json')
if unit.exists():
    r = json.loads(unit.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and r['input_sha_drift'] == 0
    unit_text = f"时迁自身key的实际Unit已完成52项、80原生视口截图、{len(r['inputs'])}冻结运行输入零漂移；仅脱离Battle的候选帧夹具，不证明原关卡、碰撞、任务或奖励。"
else:
    unit_text = '时迁自身key的实际Unit复验正在准备/运行；尚无最终收据，不计为通过。'

body = """## 2026-10-06 当前增量：时迁机警轻身四步相候选

人物按原著特性与情境分别设计：时迁保留轻屈膝、少量髋部前倾、近身手臂和警觉平视；武松、林冲普通待机保持挺拔。正常成人比例与个性姿态同时满足，不能将驼背、短腿或错误方向归为人物性格。

时迁共20候选姿态来自14张原生1254×1254 RGBA：既有traits四向idle、新留白walk A四向atlas，加上四张单向B及八张独立passing。AtlasTexture直接采样原生四格，不做本地PNG裁切/缩放/镜像/重绘，也不拿idle充当passing。14源独立Godot导入、281来源检查、8资源重建通过；真实时钟起停64截图/20记录、38冻结输入零漂移。20姿态矩阵及实际四个步相直接查看，仍需核对NE contact A落地/摆腿识别、背面脚底幅度、精确脚点和衣装连续性，未判为自然步态生产合格。

六源/12姿态成对诊断另保留实际导入、153来源/8资源/21输入零漂移静态矩阵，只用于idle/A/B对照。原生A越界、B多图重复支撑/越界、直接交换只改部分、四格几何引导仍重复前向支撑、NW单向误画正面等5类失败PNG/精确请求均保留。四视图几何v4因共享World3D积累额外腿而判退；v5每视口独立world，新增NE单视图v6修复GDScript类型推断后实际渲染通过。数学参考仅新primitives，无人物PNG输入，脚色/机器人比例不进入人物素材。人物像素始终经内置imagegen参考原生编辑。提示词全集shi_qian_walk_native_prompt_set_v4.json，拒绝记录shi_qian_walk_native_rejections_v4.json。

""" + unit_text + """

生产ArtDB/CampaignArt/原解救回调和数值没有本批改动。共享Godot只自然等待，不控制或联系其他任务。原七人解救/撤回/终态、UI生产路由、连续动画资格与武松/林冲普通动作仍开放。全计划继续覆盖当前八关动态阶段/生产/船体/身份动作UI、跨进程保存退出续玩/奖励一次性、九模式、约10分钟性能/尾帧、Android真机及平台资格；审核修错后才受限清理和白名单同步stable。本批仅本地，未提交推送、清理、打包或发布；2026-10-06远端stable回读27f45b245e2b39f1f779fbfa62772e14bb68dd56。下方为之前阶段记录。
"""
if (QA / 'shi_qian_unit_motion_footclear_v4.json').exists():
    latest = """最新footclear另原生绘制NE单向contact A，明确image-left支撑靴脚跟/脚尖平落、image-right摆腿低抬，保留旧A atlas全图。当前15源/20姿态实际导入1254×1254；294来源检查、8资源只读重建通过。旧A东北格弃用理由在walk_footclear_declared_v4清单明确登记；与原footclear清单相比只增加unused_regions，所有运行姿态、pivot/scale、资源/PNG完全相同。首次漏声明的293项来源失败及原时钟/Unit清单保留，不覆盖历史，新增来源验收与运行画面同字节资源交叉核验。修正版真实时钟64截图/20记录/40冻结输入零漂移，实际四相和矩阵直接查看；自身Unit52项/80截图/4657冻结输入零漂移通过，1×/4×起停、反向和真实相位0/1/2/3直接查看。6.4秒定帧率视频仅原始视口预览，未连续播放验收，不是性能计时。见shi_qian_walk_footclear_review_v4.json、shi_qian_unit_motion_footclear_review_v4.json和shi_qian_walk_native_prompt_set_footclear_v4.json。全连续脚点/衣装、原关卡和生产路由资格仍开放。下述14源为修脚位前的历史阶段。"""
    body = body.replace('时迁共20候选姿态来自14张', latest + '\n\n初轮时迁20候选姿态来自14张')

for name in ('WORKLOG.md', 'PROJECT_STATUS.md', 'DEVELOPMENT_PLAN.md'):
    section(ROOT / 'docs' / name, body)
section(ROOT / 'docs/CHARACTER_POSTURE_20261006.md', body, True)
section(QA / 'README.md', body, True)
section(Path(__file__).parent / 'README.md', body, True)

setup = """## 2026-10-06 时迁traits四步相与自身Unit（候选）

14张原生PNG直接采样20姿态，包括两张四向atlas及12单向全画幅帧。实际导入1254×1254，281来源/8资源、64实际时钟截图/20记录/38输入零漂移通过；六源12姿态静态诊断另有153来源/21输入零漂移。生产路由未更改，NE A脚位和连续自然步态仍待验收。

    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_shi_qian_walk_passing_v4.py
    python -X utf8 -B qa/zhu_wounded_20261005/harness/texture_bootstrap_shi_qian_v4.py <工程外QA根目录> --manifest assets/direction4/zhu_wounded_shi_qian_20261006_walk_passing_v4.json --label shi_qian_walk_passing_v4
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_shi_qian_walk_passing_v4.py --import-receipt <该14源导入receipt.json>
    python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_wounded_shi_qian_20261006_walk_passing_v4.json --write
    python -X utf8 -B tools/directional_character_sources.py assets/direction4/zhu_wounded_shi_qian_20261006_walk_passing_v4.json tools/contracts/zhu_wounded_20261005/generation_shi_qian_walk_passing_v4.json --out qa/zhu_wounded_20261005/shi_qian_walk_sources_passing_v4.json
    python -X utf8 -B qa/zhu_wounded_20261005/harness/shi_qian_walk_preview_v4.py <同一工程外QA根目录>
    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_shi_qian_v4.py <同一工程外QA根目录> --cache-from <已核验私有QA批/project>

Unit独立夹具继承原指令/物理/绘制，仅覆写候选帧解析；缓存来源明确，不能当无缓存首启/原关卡或平台资格。新几何producer与失败producer/私有副本保留，不修改王英和石秀被既有收据依赖的源码。完整原生编辑请求/父图见shi_qian_walk_native_prompt_set_v4.json与generation_shi_qian_walk_passing_v4.json。共享引擎自然等待。公共启动入口不变。
"""
if (QA / 'shi_qian_unit_motion_footclear_v4.json').exists():
    setup = """## 2026-10-06 当前时迁footclear：NE A明确支撑脚

最新15原生源/20姿态实际导入，294来源、8资源、64截图/20记录/40冻结输入零漂移；自身Unit52项/80原生截图/4657冻结输入零漂移。declared清单只增加旧NE格弃用声明，与运行清单的姿态/资源/PNG完全一致；不改原生图，不重跑只因来源声明改变的渲染。原漏声明失败清单、运行夹具和私有证据完整保留。

    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_shi_qian_walk_footclear_v4.py
    python -X utf8 -B qa/zhu_wounded_20261005/harness/texture_bootstrap_shi_qian_footclear_v4.py <工程外QA根目录> --manifest assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_v4.json --label shi_qian_walk_footclear_v4
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_shi_qian_walk_footclear_v4.py --import-receipt <15源导入receipt.json>
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_shi_qian_footclear_declaration_v4.py
    python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_declared_v4.json --write
    python -X utf8 -B tools/directional_character_sources.py assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_declared_v4.json tools/contracts/zhu_wounded_20261005/generation_shi_qian_walk_footclear_v4.json --out qa/zhu_wounded_20261005/shi_qian_walk_sources_footclear_declared_v4.json
    python -X utf8 -B qa/zhu_wounded_20261005/harness/shi_qian_walk_footclear_preview_v4.py <同一工程外QA根目录>
    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_shi_qian_footclear_v4.py <同一工程外QA根目录> --cache-from <已核验私有QA批/project>

NE A新几何guide为shi_qian_contact_a_ne_geometry_v7，由独立primitives实际渲染，最终角色仍内置imagegen原生参考编辑；不修改旧producer。全七人/原任务/UI/连续步态/无缓存首启和平台资格仍开放。以下为初轮14源命令记录。

""" + setup
section(ROOT / 'docs/SOURCE_SETUP.md', setup)

index = """## 2026-10-06 时迁机警轻身真实四步相新增

- assets/direction4/zhu_wounded_shi_qian_20261006_walk_passing_v4.json、assets/anim/zhu_wounded_v4_shi_qian_gait_traits_*：14原生源/20候选姿态，4真实步相，每向独立资源，production_qualified=false。
- prepare_shi_qian_walk_passing_v4.py、generation_shi_qian_walk_passing_v4.json：两原生quad与十二单向帧的直接采样/完整原生父图和代码几何来源链。
- qa/zhu_wounded_20261005/shi_qian_walk_{texture,sources,cycle}_passing_v4.*、shi_qian_walk_passing_review_v4.json、shi_qian_walk_native_prompt_set_v4.json、shi_qian_walk_native_rejections_v4.json：281来源、64截图/20记录/38冻结输入零漂移、原生14请求和5类失败保留。未证明自然步态生产合格。
- 六源12姿态contact_pair另保留153来源/21输入静态对照；不能替代完整步态。
- harness/shi_qian_walk_preview_v4.*、unit_motion_shi_qian_v4.*、texture_bootstrap_shi_qian_v4.py：时迁独立候选验证，不覆盖被石秀/王英旧收据依赖的producer。Unit最终状态以自身receipt为准。
- shi_qian_opposite_quad_geometry_v4/v5及opposite_ne_geometry_v6 producer、guides、receipts：v4共享world多腿判退，v5独立world和NE v6新数学腿姿，仅新原生geometry，无人物位图编辑。
"""
if (QA / 'shi_qian_unit_motion_footclear_v4.json').exists():
    index = """## 2026-10-06 当前时迁footclear新增

- walk_footclear_declared_v4清单、gait_footclear资源与walk_a_geometry_ne_v4原生PNG：15源/20姿态；旧A atlas东北格有明确弃用理由，其他三格保留直接采样。
- shi_qian_walk_sources_footclear_declared_v4.json、shi_qian_footclear_declaration_equivalence_v4.json：294来源检查通过，运行字段/8资源与原footclear清单完全一致；293项漏声明失败记录另保留。
- shi_qian_walk_{texture,cycle}_footclear_v4.*、shi_qian_walk_footclear_review_v4.json：15源真实导入，64截图/20记录/40输入零漂移。
- shi_qian_unit_motion_footclear_v4.json及review：52项/80截图/4657运行输入零漂移，自身key的脱离Battle实际Unit；原任务/全七人/生产/UI/连续步态仍不合格。
- prepare_shi_qian_footclear_declaration_v4.py、prepare/record_shi_qian_walk_footclear_v4.py与专用footclear时钟/Unit夹具：旧来源/夹具/失败记录不覆盖；native_prompt_set_footclear_v4包含15精确请求。
- NE contact_a几何v7：平落地红脚/低抬蓝脚，独立代码与原生guide/实际receipt；无人物位图输入或本地PNG编辑。

下方14源为初轮阶段记录。

""" + index
section(ROOT / 'docs/DIRECTORY_INDEX.md', index)
print('8 owned progress/setup/index blocks updated; full objective remains open')
