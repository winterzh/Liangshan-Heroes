"""Update current development handoff from preserved passing/Unit receipts."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
START='<!-- shi-xiu-passing-v4-current -->'
END='<!-- /shi-xiu-passing-v4-current -->'
unit=QA/'shi_xiu_unit_motion_passing_v4.json'
unit_text='实际Unit候选测试已准备并启动私有工程冻结，当前尚无完成收据。'
if (QA/'shi_xiu_unit_motion_pending_v4.json').exists():
    unit_text='实际Unit测试首次自定义SceneTree入口因autoload依赖注册过早失败，已保留收据并改为正常Node场景。修正版私有当前工程已完成导入，绘图阶段正在自然等待共享引擎空闲；尚无完成Unit收据，不能算移动资格。见shi_xiu_unit_motion_entry_failure_v4.json及shi_xiu_unit_motion_pending_v4.json。'
if unit.exists():
    r=json.loads(unit.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
    unit_text=f"实际Unit候选测试已完成{len(r['result']['checks'])}项检查、80张渲染截图，{len(r['inputs'])}冻结运行输入零漂移；继承原移动/停止/转向/相位/次级绘制，仅覆写候选帧解析。脱离Battle的草地测试不代表原关卡、碰撞、任务或生产路由资格。"
refined_text=''
if (QA/'shi_xiu_walk_cycle_refined_v4.json').exists():
    refined_text='另原生编辑passing_b3_sw/ne降低过渡抬脚幅度，保留旧版父图。refined20源实际导入1254×1254、348来源/8资源、64截图/20记录及50冻结输入零漂移已通过；20姿态矩阵及实际相位0/1/2/3已直接查看。抬脚幅度改善，SW低抬脚的支撑/摆腿识别仍需动作审核；修正版实际Unit复验正在进行，不能沿用旧passing完成收据。'
if (QA/'shi_xiu_unit_motion_refined_v4.json').exists():
    rr=json.loads((QA/'shi_xiu_unit_motion_refined_v4.json').read_text(encoding='utf-8'))
    assert rr['complete'] and rr['lock_released'] and rr['input_sha_drift']==0
    refined_text=refined_text.replace('修正版实际Unit复验正在进行，不能沿用旧passing完成收据。',
        f"refined自身实际Unit复验已完成44项、80截图、{len(rr['inputs'])}冻结输入零漂移；仅脱离Battle的候选帧测试，不算全七人原关卡或生产资格。")
footclear_text=''
if (QA/'shi_xiu_unit_motion_footclear_v4.json').exists():
    fr=json.loads((QA/'shi_xiu_unit_motion_footclear_v4.json').read_text(encoding='utf-8'))
    assert fr['complete'] and fr['lock_released'] and fr['input_sha_drift']==0
    footclear_text=f"最新footclear采用SW passing_b5：前方摆腿收回抬起、后方支撑靴落地，B4错误支撑腿原图及拒绝记录保留。20源实际导入、348来源检查/8资源、64截图/20记录及50输入零漂移已通过。最新实际Unit独立复验44项、80截图、{len(fr['inputs'])}冻结输入零漂移；起停、反向及四个步相画面直接核对。80原始视口帧组成6.4秒定帧率视频，尚未连续播放验收。证据shi_xiu_walk_footclear_review_v4.json及shi_xiu_unit_motion_footclear_review_v4.json。"
wang_text=''
if (QA/'wang_ying_traits_idle_review_v4.json').exists():
    wr=json.loads((QA/'wang_ying_traits_idle_review_v4.json').read_text(encoding='utf-8'))
    assert wr['source_checks']==52 and wr['input_drift']==0 and len(wr['templates'])==4
    wang_text='王英保留现有矮壮成年四向原图；实际静态导入/52来源/4资源/7冻结输入零漂移通过并直接查看矩阵。既有渲染体高系数0.70相对普通0.78保持原项目解释，并非原著测量。另内置imagegen生成四张1254×1254全画幅方向模板，原字节/父图/请求保留；新模板尚未实际导入或运动验证，腰带及铆钉细节连续性须审核。静态矩阵标题误称ordinary idle已在审核限制记录，不能当普通状态路由资格。见wang_ying_traits_idle_review_v4.json。'
if (QA/'wang_ying_fullidle_review_v4.json').exists():
    full=json.loads((QA/'wang_ying_fullidle_review_v4.json').read_text(encoding='utf-8'))
    assert full['import_dimensions_verified'] and full['frozen_inputs']==13 and full['input_drift']==0
    wang_text='王英保留矮壮成熟的个别体态，旧四格原图/52来源/7输入静态收据保留。新四张全画幅idle已经独立导入1254×1254、82来源/4资源、13冻结输入零漂移实际静态预览通过并直接查看；四向体高与初估脚点一致，矩阵已正确标识rescued上下文。原生PNG字节未裁切/缩放/修改，低透明度边缘与不足80px请求留白分别记录。证据wang_ying_fullidle_{texture,sources,preview,matrix,review}_v4。'
    if (QA/'wang_ying_walk_a_authoring_v4.json').exists():
        poses=json.loads((QA/'wang_ying_walk_a_authoring_v4.json').read_text(encoding='utf-8'))
        assert len(poses['rows'])==4 and not poses['production_qualified']
        wang_text+='另内置imagegen新增四向walk_a首步原生候选，父图/精确请求/透明边界核验通过并逐张查看。NE前后腿与请求的左腿领先不一致，四向后脚轻触地未确认；相反接触步及两个真实passing步相、全帧衣装/脚点连续性、独立导入与Unit/原关卡资格仍待完成。暂不把新四首步当完整走路或生产资源。见wang_ying_walk_a_authoring_v4.json。'
if (QA/'wang_ying_ne_support_pair_v4.json').exists():
    pair=json.loads((QA/'wang_ying_ne_support_pair_v4.json').read_text(encoding='utf-8'))
    assert len(pair['rows'])==3 and not pair['production_qualified']
    wang_text+='NE文字改腿A2未充分交换腿位，保留为未选中；以石秀NE下肢相反姿态仅作腿姿参考，已得到B的右前脚落地/左后脚抬起，与A左后脚支撑不同。成对候选按支撑关系记录，不能冒称已满足旧提示词的左腿领先几何或完整自然步态。见wang_ying_ne_support_pair_v4.json。'
if (QA/'wang_ying_se_opposite_rejections_v4.json').exists():
    rejected=json.loads((QA/'wang_ying_se_opposite_rejections_v4.json').read_text(encoding='utf-8'))
    assert len(rejected['rows'])==3 and not rejected['production_qualified']
    wang_text+='SE相反步首版和姿态优先B2均重复A支撑脚，B2还把横向绑腿改为交叉绑腿；两版原图/请求/父图完整保留并判退。SW/NW相反步请求已准备但未执行；下一步须更明确的几何腿姿参考或新的原生编辑方式。见wang_ying_se_opposite_rejections_v4.json。'
if (QA/'wang_ying_walk_cycle_passing_v4.json').exists():
    wr=json.loads((QA/'wang_ying_walk_cycle_passing_v4.json').read_text(encoding='utf-8'))
    assert wr['complete'] and wr['lock_released'] and wr['input_sha_drift']==0
    wang_text='王英已保留成熟矮壮的个别体态，旧四格原图及历史审核完整保留。新四向全画幅idle/两接触步/两真实低抬脚passing共20张原生1254×1254，实际独立导入、364来源检查、8资源重建通过。真实process-clock起停64截图、20方向/状态/相位记录、50冻结输入零漂移；20姿态矩阵和实际0/1/2/3步相已直接查看。角色体高仍用既有0.70对普通0.78的项目解释，不冒称原著人体测量。'
    wang_text+='SE旧B/B2重复支撑和绑腿漂移已判退；新SE B3及SW/NW B3采用新Godot几何参考，仅参考腿姿，不读或修改任何人物位图。初版SE几何投影落地脚在错误侧，v5修正；SW/NW v6及八个passing v7参考已验证脚底接触、屏幕支撑侧和低抬脚范围，原生参考和精确生成代码/配置均保留。三个新B3实际交换支撑并保留横向绑腿，NE B保持相反支撑候选。A/B命名只表示对照支撑，不伪称旧左腿领先提示词完全实现。'
    wang_text+='12源成对诊断已完成236来源、8资源、12静态姿态及33输入零漂移，已被真正四步相候选替代作为当前下一阶段；不会把两接触诊断当完整步态。证据wang_ying_contact_pair_review_v4.json、wang_ying_walk_passing_review_v4.json及完整提示词wang_ying_walk_native_prompt_set_v4.json。'
    if (QA/'wang_ying_unit_motion_passing_v4.json').exists():
        wu=json.loads((QA/'wang_ying_unit_motion_passing_v4.json').read_text(encoding='utf-8'))
        assert wu['complete'] and wu['lock_released'] and wu['input_sha_drift']==0
        wang_text+=f"王英自身key的实际Unit独立复验已完成52项、80原生视口截图、{len(wu['inputs'])}运行输入零漂移；原移动/停止/反向/转向/相位及次级绘制继承，HP110、速度82、攻击0、非英雄/非战斗和槽0夹具身份逐帧核实。1×/4×关键帧和实际四步相已直接查看；6.4秒定帧率视频仅预览，没有连续播放已观看资格。见wang_ying_unit_motion_passing_v4.json及对应review。"
    wang_text+='整套仍是候选解析器下的脱离Battle测试；原七人解救撤回、碰撞/奖励/任务、生产ArtDB/UI和连续脚点/衣装衔接资格保持开放。本轮远端stable回读仍为27f45b245e2b39f1f779fbfa62772e14bb68dd56，本批仅本地开发，未清理、提交推送或平台发布。'
block=f'''{START}
## 2026-10-06 当前：按人物特性继续修姿态与真实步相

人物要求维持逐人判断：时迁机警轻身，武松高大有气势，林冲挺拔沉稳；普通待机、潜行、进攻和负伤按各自情境处理。时迁/武松/林冲已有静态候选及各自来源收据，仍待游戏动作衔接和生产资格。

石秀新增8张真实passing步相和4张单方向全画幅idle；SW/NE首次B重复A支撑腿，保留原生失败图/请求并另生成修正版。最终20源（4 idle+每向4真实行走相位）独立导入1254×1254，342来源检查、8资源只读重建通过。真实process-clock起停预览64截图、20方向/状态/帧记录，50冻结输入零漂移，20姿态矩阵及实际相位0/1/2/3已直接查看。衣装细节较旧四格idle一致，但SW passing B仍显抬脚伸展僵硬，NE抬脚高度/衔接须进一步审核；不判定为合格自然步态。证据shi_xiu_walk_texture_passing_v4.json、shi_xiu_walk_sources_passing_v4.json、shi_xiu_walk_cycle_passing_v4.json/.png及shi_xiu_walk_passing_review_v4.json。

{unit_text} 缓存复用明确记录，不能当无缓存首启资格。共享引擎只自然等待，未控制其他任务。没有连续浏览器播放验收。

{refined_text}

{footclear_text}

{wang_text}

生产ArtDB/CampaignArt/原解救回调与数值仍未改；本批未提交推送、清理、打包或平台发布。继续修脚点/自然步态、全七人动作与原解救撤回/终态、武松林冲普通动作衔接。全计划的当前八关动态阶段/生产/船体/身份动作UI、跨进程续玩/奖励一次性、九模式、约10分钟性能/尾帧、Android真机和平台资格保持开放。资格合格后审核修错、受限清理、白名单同步stable。以下为历史记录。
{END}

'''
names=['docs/WORKLOG.md','docs/PROJECT_STATUS.md','docs/DEVELOPMENT_PLAN.md',
       'docs/CHARACTER_POSTURE_20261006.md','qa/zhu_wounded_20261005/README.md',
       'tools/contracts/zhu_wounded_20261005/README.md']
for name in names:
    p=ROOT/name
    text=p.read_text(encoding='utf-8')
    if START in text:
        a=text.index(START); b=text.index(END,a)+len(END)
        text=text[:a]+block.rstrip()+text[b:]
    else:
        text=text.replace('## 2026-10-06 最新：人物分别设计，武松/林冲普通站姿候选已静态核验',
                          '## 2026-10-06 人物分别设计与普通站姿静态候选（历史阶段）',1)
        if text.startswith('# '):
            first,rest=text.split('\n',1); text=first+'\n\n'+block+rest.lstrip('\n')
        else: text=block+text
    p.write_text(text,encoding='utf-8',newline='\n')
print(json.dumps({'updated':names,'unit_receipt_complete':unit.exists()}))
