"""Record current per-character art intent and honest candidate qualification."""
from pathlib import Path
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
review = json.loads((ROOT/'qa/zhu_wounded_20261005/ordinary_contacts_static_review_v5.json').read_text(encoding='utf-8'))
assert review['passed'] and not review['production_qualified']
marker = '<!-- traits-contacts-v5-current -->'
summary = '''<!-- traits-contacts-v5-current -->
## 2026-10-06 按人物特性修正体态：当前素材与同步范围

用户要求按原著人物特点塑造体态，不能全员统一军姿。武松普通待机/行走强调魁梧、剽悍、抬头挺胸；林冲强调教头的挺拔、沉稳和自然持枪。时迁保留轻巧机警、轻微髋部前倾与自然软膝，不画成病态驼背或深蹲；王英成熟矮壮，秦明强壮端正，石秀精干敏捷，杨林灵活，黄信稳健，邓飞粗犷警觉。攻击、受击、负伤允许动作需要的弯曲，不能强行军姿。具体衣装、甲片、步相和数值比例属于项目美术解释，不冒称原著逐项规定。

内置imagegen新增武松SE两张交替承重候选、林冲SE两张交替承重候选，另保留林冲首版B失败图（重复A承重）和原生B2修正。五张1254×1254 RGBA均原字节保存，精确请求、父图和几何参考producer可核对。只读SHA/透明边界/输入链检查通过；最小透明余量58px，未裁切，但未完全满足请求的100px余量。直接静态观察已记录；尚缺另外三向、过渡步相、导入/采样/足点和真实起停/反向/战斗/UI验收。普通武松/林冲生产取图未替换，production_qualified=false。

本轮同步范围包括已有获救七人取图增量、946项原关卡/16截图与410项五进程续玩组件证据，以及人物候选和完整来源链。五进程资格限定于安装来源的战役组件QA；不等于公开继续入口、全章结局/奖励一次性或完整发布资格。此前“尚未提交/推送”属于历史阶段记录；同步结果以stable分支提交历史与本轮同步收据为准。完整八关动态阶段、九模式、性能、Android及人物完整动作仍按DEVELOPMENT_AUDIT_20261006.md推进。

本次没有清理缓存、打包、Steam发布或main合并。继续遵守共享Godot自然等待策略。
<!-- /traits-contacts-v5-current -->

'''
for name in ['WORKLOG.md','SOURCE_SETUP.md','DIRECTORY_INDEX.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','CHARACTER_POSTURE_20261006.md']:
    p = ROOT/'docs'/name
    old = p.read_text(encoding='utf-8')
    assert marker not in old
    extra = ''
    if name == 'SOURCE_SETUP.md':
        extra = '本批原生候选保存工具：tools/contracts/zhu_wounded_20261005/save_ordinary_walk_native_v5.py <wu_song|lin_chong> <state> <原生生成PNG>；精确请求已在requests/保存。静态复核生产者review_ordinary_contacts_v5.py已执行，保留固定收据，不覆盖重跑；复查按收据逐一读取SHA。该检查不启动引擎，也不构成动画验收。\n\n'
    elif name == 'DIRECTORY_INDEX.md':
        extra = '新增候选：assets/characters/{wu_song,lin_chong}_traits_20261006/*_v5.png；精确请求/生成来源：tools/contracts/zhu_wounded_20261005/{requests,jobs}/*_v5.json；静态资格/判退：qa/zhu_wounded_20261005/ordinary_contacts_static_review_v5.json。全部为素材与证据，不是运行缓存。\n\n'
    p.write_bytes((summary + extra + old).encode('utf-8'))
attributes = ROOT/'.gitattributes'
block = '\n# Exact posture native sources, generation lineage, and verified component QA.\n'
for key in ['shi_qian','shi_xiu','qin_ming','yang_lin','huang_xin','wang_ying','deng_fei']:
    block += f'assets/characters/{key}_wounded_20261005/** -text -whitespace\n'
for key in ['wu_song','lin_chong']:
    block += f'assets/characters/{key}_traits_20261006/** -text -whitespace\n'
for pattern in ['assets/direction4/zhu_wounded_*.json','assets/direction4/ordinary_*_20261006_traits_v4.json',
                'assets/anim/zhu_wounded_*.tres','assets/anim/character_traits_v4_*.tres',
                'tools/contracts/zhu_wounded_20261005/**','qa/zhu_wounded_20261005/**',
                'tools/rescued_seven_art_qa.gd','tools/rescued_seven_cross_process_qa.gd',
                'tools/run_rescued_seven_art_qa.py','tools/run_rescued_seven_cross_process_qa.py',
                'tools/directional_character_sources.py','scripts/art_db.gd','scripts/liangshan_scenery.gd']:
    block += pattern+' -text -whitespace\n'
raw = attributes.read_bytes()
assert b'# Exact posture native sources' not in raw
attributes.write_bytes(raw+block.encode('utf-8'))
statefile = ROOT.parent/'qa-rescued-seven-current-20261006/continuation_state.json'
state = json.loads(statefile.read_text(encoding='utf-8'))
state.update(runner_session_id=None,state='Five-process component QA complete410; ordinary comparison80/80 each rejected visual transition; five SE contact natives saved, four static candidates and one rejected Lin B. No live owned jobs.',
             next='Review and synchronize verified round with explicit whitelist. Continue ordinary four-direction/passing motion and full development audit. No cache deletion before current qualification/protection checks.',
             ordinary_static_review='qa/zhu_wounded_20261005/ordinary_contacts_static_review_v5.json')
statefile.write_bytes((json.dumps(state,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'documents':6,'native_candidates':4,'retained_failure':1,'runtime_qualified':False,'production_qualified':False}))
