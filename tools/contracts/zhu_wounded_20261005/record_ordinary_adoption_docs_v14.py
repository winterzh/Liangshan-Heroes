"""Record tested exact lookup adoption; fresh unchanged-production verification pending."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    rp=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_hurt_pilot_v13_772dbc1b/receipt.json'
    r=json.loads(rp.read_text(encoding='utf-8'));assert r['complete'] and r['result']['checks']==369
    assert sha(ROOT/'scripts/art_db.gd')==r['private_patch']['patched_sha256']
    for row in r['source_files']:
        if row['path']!='scripts/art_db.gd':assert sha(ROOT/row['path'])==row['sha256']
    text='''<!-- ordinary-death-hurt-adopted-v14-pending -->
## 2026-10-07 修正倒地与活体受击已本地登记，正式副本复验进行中

v13原祝家庄林冲/大名府武松普通指令、四向近战/反击与恢复动作369检查/48图通过，正常时钟1.0，4904来源、105既有、25新输入零漂移。林冲SW真实反击前生命311.851851851852，受击后303.703703703704，仍为活人，实际采用站立recoil；直接查看保存SW待机/受击/恢复行走、NE/NW受击及Wu SW受击6图。正确朝左、完整长枪/靴子与成人体型保留；原数值/技能/HUD/头像及其他普通/剧情路由通过。证据ordinary_hurt_pilot_qualified_v13.json和ordinary_hurt_pilot_visual_review_v13.json。v10a倒地/影子346项/32图资格仍保留。接触/冻结/相位/镜头等夹具不等于连续或自然通关。

本地ArtDB普通查表新增Wu death及Lin death/hurt，内容逐字节等于已验证v13私有ArtDB；其余4904生产输入原样。Lin只改SW死亡与站立受击，其他各三向资源为原TRES字节别名，显式剧情变体不走普通新族。作者候选清单继续保留历史false资格字段，当前实际登记与后验由独立收据记录。v14使用当前生产脚本原样复制，无私有运行时补丁，分近战/受击及倒地/影子两个独立进程继续复验，尚未取得完成收据。生产脚本仅改ArtDB查表，未改Unit、数值、技能、存档或任务回调。

正式资格、完整连续动作/血条间距/多尺寸UI及DEVELOPMENT_AUDIT_20261006.md的其他全项目项继续开放。当前新增文件/文档和本地ArtDB登记尚未提交推送；上一个已同步检查点仍为7ebfe4e3，本轮成功后再白名单同步。未新增清理、打包或平台发布。
<!-- /ordinary-death-hurt-adopted-v14-pending -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- ordinary-death-hurt-adopted-v14-pending -->' not in old
        extra=''
        if name=='SOURCE_SETUP.md':extra='v14正式副本复验入口：python -X utf8 -B qa/zhu_wounded_20261005/harness/run_ordinary_production_v14.py --from-pilot <已完成v13 receipt.json> --visual-review qa/zhu_wounded_20261005/ordinary_hurt_pilot_visual_review_v13.json --work-root <工程外QA父目录> --run。无--run预检；当前已启动，先核对外部continuation_state.json/共享锁，不重复启动。\n\n'
        p.write_bytes((text+extra+old).encode('utf-8'))
    p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';old=p.read_text(encoding='utf-8')
    p.write_bytes(('2026-10-07当前：v13普通实战/非致命受击369项/48图通过，4904+105+25零漂移，实际Lin SW生命311.851851851852→303.703703703704并保持站立朝左、恢复行走。ArtDB已本地登记Wu death/Lin death/hurt，字节等于受审v13私有脚本；其他生产输入不变。v14当前生产副本无私有补丁复验已启动，正式完成收据尚待。当前新增与登记尚未提交推送；完整连续/UI和下表全项目项仍开放。\n\n'+old).encode('utf-8'))
    print('Recorded exact local adoption and pending production verification in seven handoff documents.')

if __name__=='__main__':main()
