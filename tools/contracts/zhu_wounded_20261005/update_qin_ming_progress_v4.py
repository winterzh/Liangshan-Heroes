"""Update owned Qin Ming progress blocks from actual receipts; preserve history."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / 'qa/zhu_wounded_20261005'
START = '<!-- qin-ming-traits-gait-v4-current -->'
END = '<!-- /qin-ming-traits-gait-v4-current -->'


def section(path, body, after_title=False):
    old = path.read_text(encoding='utf-8')
    block = START + '\n' + body.strip() + '\n' + END + '\n\n'
    if START in old:
        a, b = old.index(START), old.index(END) + len(END)
        old = old[:a] + block.rstrip() + old[b:]
    elif after_title:
        i = old.index('\n')
        old = old[:i+1] + '\n' + block + old[i+1:]
    else:
        old = block + old
    path.write_text(old, encoding='utf-8')


unit = QA / 'qin_ming_unit_motion_passing_v4.json'
if unit.exists():
    r = json.loads(unit.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and r['input_sha_drift'] == 0
    unit_text = f"秦明自身key的实际Unit独立复验已通过52项/80原生视口截图/{len(r['inputs'])}冻结运行输入零漂移，夹具身份逐帧HP110、速度82、攻击0、非英雄/非战斗/槽0。原指令、物理、起停、反向及次级绘制继承；仅脱离Battle的候选解析器，不证明原七人/碰撞/任务/奖励/生产/UI。1×/4×关键帧和真实四步相直接查看，定帧率视频仅预览，未连续播放验收或性能计时。"
else:
    unit_text = '秦明自身key实际Unit复验正在私有运行准备/等待共享引擎；没有最终收据，不计为通过。'

body = """## 2026-10-06 当前增量：秦明强壮军官体态与真实四步相候选

本批七人清单为时迁、石秀、秦明、杨林、黄信、王英、邓飞。朱仝不在本批，初始口头选择已核对改为秦明。秦明按其强壮、刚烈军官特征保留宽肩厚实躯干、自然抬头与端正上背，获救步行不带战马/狼牙棒/绳索；盔甲与红披风是既有项目设计，具体比例和0.78体高元数据是美术解释，不伪称原著人体测量。时迁轻巧机警、王英成熟矮壮及武松/林冲挺拔要求保持逐人处理，不统一成僵硬军姿。

秦明新增四个单向全画幅idle、每向四张独立walk_a/passing_a/walk_b/passing_b，共20张原生1254×1254 RGBA与20姿态。独立导入、342来源检查、8资源重建通过；真实时钟64截图/20记录/50冻结输入零漂移。20姿态矩阵与实际四相直接查看。东北passing_a首版近似双脚落地，原图/请求保留并判退；原生A2明确image-left支撑、image-right低抬，选择A2而非复制idle过渡。候选仍需连续脚点/靴底幅度及披风/甲片衔接审核，不判为自然步态生产合格。

四向全画幅idle另保留79来源/4资源、13输入零漂移静态证据。8个新contact几何参考是独立Godot primitives，无人物PNG输入/编辑，逐向核验红脚平接触、蓝脚低抬与屏幕支撑侧；各3个producer输入同SHA，原生guide、代码、配置与收据保留。八个passing仅复用既有数学腿姿guide，不继承王英短体型或颜色。最终人物像素始终内置imagegen原生参考生成/编辑，未本地裁切/缩放/镜像/重绘。见qin_ming_contact_geometry_review_v4.json、qin_ming_walk_passing_review_v4.json、qin_ming_walk_native_authoring_bundle_v4.json及完成后native_prompt_set_v4.json。

""" + unit_text + """

生产ArtDB/CampaignArt/原解救回调和数值没有本批改动。共享Godot自然等待，不控制或联系其他任务。下一步复核秦明连续步态/脚点，再推进杨林、黄信、邓飞及全七人原解救/撤回/终态、生产/UI；武松、林冲普通动作衔接继续。全目标的当前八关动态阶段/生产/船体/身份动作UI、跨进程保存退出续玩/奖励一次性、九模式、约10分钟性能/尾帧、Android真机与平台资格仍开放。资格合格后审核修错、受限清理、白名单同步stable。本批仅本地，尚未提交推送、清理、打包或平台发布。以下为之前阶段记录。
"""
for name in ('WORKLOG.md', 'PROJECT_STATUS.md', 'DEVELOPMENT_PLAN.md'):
    section(ROOT / 'docs' / name, body)
section(ROOT / 'docs/CHARACTER_POSTURE_20261006.md', body, True)
section(QA / 'README.md', body, True)
section(Path(__file__).parent / 'README.md', body, True)

setup = """## 2026-10-06 秦明20原生源/真实四步相（候选）

342来源/8资源、64实际时钟截图/20记录/50输入零漂移通过。独立fullidle保留79来源/4资源/13输入静态证据。东北过脚A首版判退，A2另生成并保留原生父图。全画幅source直接采样，不本地变换PNG。

    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_qin_ming_walk_passing_v4.py
    python -X utf8 -B qa/zhu_wounded_20261005/harness/texture_bootstrap_qin_ming_v4.py <工程外QA根目录> --manifest assets/direction4/zhu_wounded_qin_ming_20261006_walk_passing_v4.json --label qin_ming_walk_passing_v4
    python -X utf8 -B tools/contracts/zhu_wounded_20261005/prepare_qin_ming_walk_passing_v4.py --import-receipt <20源导入receipt.json>
    python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_wounded_qin_ming_20261006_walk_passing_v4.json --write
    python -X utf8 -B tools/directional_character_sources.py assets/direction4/zhu_wounded_qin_ming_20261006_walk_passing_v4.json tools/contracts/zhu_wounded_20261005/generation_qin_ming_walk_passing_v4.json --out qa/zhu_wounded_20261005/qin_ming_walk_sources_passing_v4.json
    python -X utf8 -B qa/zhu_wounded_20261005/harness/qin_ming_walk_preview_v4.py <同一工程外QA根目录>
    python -X utf8 -B qa/zhu_wounded_20261005/harness/unit_motion_qin_ming_v4.py <同一工程外QA根目录> --cache-from <已核验私有QA批/project>

新contact几何由独立qin_ming_contact_geometry_v4.gd及配置渲染，无人物位图输入。8份配置保留生成前期待文字，实际完成看独立receipt与直接观看的PNG；producer选用后保持SHA不变。

    python -X utf8 -B qa/zhu_wounded_20261005/harness/render_qin_ming_contact_geometry_v4.py <工程外QA根目录> --phase <walk_a或walk_b> --direction <se或sw或ne或nw>

最终人物使用内置imagegen，完整请求/原生父图/generation lineage保留。Qin专用正常Node场景继承原Unit，只适配候选帧；不会覆盖王英/石秀/时迁被已有收据依赖的producer。共享引擎自然等待，公共启动入口不变。原关卡、连续步态、UI与无缓存首启/平台资格另验收。
"""
section(ROOT / 'docs/SOURCE_SETUP.md', setup)

index = """## 2026-10-06 秦明强壮军官四步相新增

- assets/characters/qin_ming_wounded_20261005/idle_single_*_v4.png、walk_a/b_*_v4.png、passing_a/b_*_v4.png及passing_a2_ne_v4.png：20选用原生源；东北首版passing_a_ne保留为失败父图。
- assets/direction4/zhu_wounded_qin_ming_20261006_walk_passing_v4.json与assets/anim/zhu_wounded_v4_qin_ming_gait_passing_*：20真实姿态/8资源，candidate_only与production_qualified=false。
- tools/contracts/zhu_wounded_20261005/prepare_qin_ming_walk_passing_v4.py及generation_qin_ming_walk_passing_v4.json：原生来源链/完整数学guide producer依赖。
- qa/zhu_wounded_20261005/qin_ming_walk_{texture,sources,cycle}_passing_v4.*与review/native_authoring_bundle/native_prompt_set：342来源、64截图/20记录/50输入零漂移；原生请求/首版判退保留。
- Qin专用texture_bootstrap/idle_preview/walk_preview/unit_motion与record helper：同目录旧角色producer不覆盖；自身Unit最终状态以自身receipt为准。
- qin_ming_contact_geometry_v4.gd、render_qin_ming_contact_geometry_v4.py、guides/qin_ming_walk_{a,b}_{se,sw,ne,nw}_geometry_v4.*：8新数学参考，每份3 producer SHA输入；无人物位图输入或本地像素编辑。
- fullidle保留79来源/13输入静态矩阵；原七人/生产/UI/连续步态资格仍开放，不能以该静态矩阵代替。
"""
section(ROOT / 'docs/DIRECTORY_INDEX.md', index)
print('8 owned Qin Ming progress/setup/index blocks updated; full objective open')
