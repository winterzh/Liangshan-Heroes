"""Record completed diagnostic evidence and the unadopted Lin SW correction."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[3]

def main():
    review=json.loads((ROOT/'qa/zhu_wounded_20261005/ordinary_final_actions_pilot_visual_review_v8a.json').read_text(encoding='utf-8'))
    assert review['mechanical_checks']==661 and not review['passed'] and review['wu_death_sampled_qualified'] and not review['lin_sw_death_qualified']
    text='''<!-- death-diagnostic-v10-current -->
## 2026-10-07 技能/真实倒地诊断完成，林冲西南朝向需修正

原关卡武松、林冲的八项技能四向484检查/64图完成；原level1生命与数值下真实致命战斗及四个倒地阶段177检查/32图完成，共661项、96个原生视口。正常时钟1.0，4904来源、105既有与13新输入零漂移，私有ArtDB仅试接武松death。完整机械收据ordinary_final_actions_pilot_v8a.json和直接查看/原字节保留的40图见ordinary_final_actions_pilot_visual_review_v8a.json。合法level6/rank1恢复、接触摆位、冻结非参与者、关雾/镜头/相位冻结仍是明确夹具。敌方近战英雄会保留自然技能使用，资格为原敌人真实战斗伤害，不称“致命一击全是普通近战”。

机械通过不等于整体画面通过：武松四向16个倒地阶段直接审查，成人体型、双刀、前后方向及静止/淡出保留；林冲旧西南fatal转右、fall转左、最终头脚又反向，画面判退。新内置imagegen西南候选两张1254RGBA原生图及精确请求/父图均保存；首版fatal仍转右，第二版定向修正为左。编排四个新SW姿态，其他三向死亡资源为原TRES逐字节别名，不改旧图/旧资源、不本地裁切/缩放/镜像/重绘。清单ordinary_lin_chong_20261007_death_v10.json，来源generation_lin_chong_death_v10.json。原生导入/尺寸资格依独立收据，实际落地点、完整死亡/影子及生产接入仍待新批验证。

v9生产复验脚本仅准备，未执行，保留为v10生成输入；v10在私有ArtDB试接武松四向死亡与林冲西南修正，并新增影子保留/释放与其他普通/剧情路由守卫。共享Godot自然等待，不操作其他任务。生产ArtDB/Unit未改，新death仍未默认采纳。施法中后期血条间距、连续动作、多尺寸UI及DEVELOPMENT_AUDIT_20261006.md的八关动态/保存终局/九模式/性能/Android实际设备等项仍开放；本批未新增清理、打包或平台发布。
<!-- /death-diagnostic-v10-current -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- death-diagnostic-v10-current -->' not in old
        extra=''
        if name=='SOURCE_SETUP.md':
            extra='v10入口：先核对外部continuation_state.json与共享锁，当前已运行的原生导入批不得重复启动。尺寸完成后运行build_lin_sw_death_frames_v10.py --import-receipt <原生导入receipt.json>；再运行qa/zhu_wounded_20261005/harness/run_ordinary_death_pilot_v10.py --from-pilot <完成v8a的receipt.json> --visual-review qa/zhu_wounded_20261005/ordinary_final_actions_pilot_visual_review_v8a.json --work-root <工程外QA父目录> --run。无--run只预检；候选独立导入入口texture_bootstrap_lin_death_v10.py <QA父目录> --manifest assets/direction4/ordinary_lin_chong_20261007_death_v10.json --label lin_chong_death_v10。各命令用python -X utf8 -B执行，Godot仍由本机忽略配置/参数解析。\n\n'
        p.write_bytes((text+extra+old).encode('utf-8'))
    p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';old=p.read_text(encoding='utf-8')
    p.write_bytes(('2026-10-07倒地审核：八项技能四向484项/64图、原level1真实战斗倒地177项/32图，共661项/96图机械通过，来源4904+105+13零漂移。40个直接查看的原生视口保存；整体画面判退于旧林冲SW死亡朝向，新SW两张候选/四姿态及三向原资源别名已编排，原生/落地/影子/生产资格依后续独立批。武松四向16个样本直接查看合格，不据此关闭连续/中后期施法血条/多尺寸/全项目事项；v9仅准备未执行，v10验证尚待。证据ordinary_final_actions_pilot_visual_review_v8a.json。\n\n'+old).encode('utf-8'))
    print('Recorded seven handoff documents; overall visual gate still open.')

if __name__=='__main__':main()
