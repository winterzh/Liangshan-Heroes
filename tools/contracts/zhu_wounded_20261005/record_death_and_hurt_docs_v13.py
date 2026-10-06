"""Record qualified death/shadows and the pending real standing-hurt counterhit test."""
from pathlib import Path
import hashlib,json,subprocess

ROOT=Path(__file__).resolve().parents[3]
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    source='7ebfe4e3d5f4e87fc25e5d86dda69b4c6ac0eed5';branch='codex/sync-20260905-stable'
    assert git('rev-parse','HEAD')==source==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    review_path=ROOT.parent/'qa-ordinary-posture-20261006/death_diagnostic_sync_review_v10.json'
    review=json.loads(review_path.read_text(encoding='utf-8'))
    for row in review['files']:assert git('rev-parse',source+':'+row['path'])==row['git_expected_blob']
    p=ROOT/'qa/zhu_wounded_20261005/death_diagnostic_source_sync_v10.json';assert not p.exists()
    data={'repository':'https://github.com/winterzh/Liangshan-Heroes.git','branch':branch,'source_commit':source,'independently_read_remote_sha':source,
          'verified':True,'whitelisted_files':81,'bytes':55408917,'review_receipt':str(review_path),'review_sha256':sha(review_path),
          'scope':'Completed 661-check/96-capture diagnostics, Lin SW native correction/import and exact failed/corrected verifier lineage. Production scripts unchanged. Later v10a death/shadow result and v12/v13 hurt work are subsequent source changes.',
          'production_default_adopted':False,'platform_released':False,'metadata_followup':'Later metadata and hurt round have separate commits; this SHA identifies the reviewed 81-file source checkpoint.'}
    p.write_bytes((json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    text='''<!-- death-qualified-hurt-pending-v13-current -->
## 2026-10-07 倒地/影子候选复验通过，补修林冲西南活体受击

v10a正常时钟下346检查/32原生视口通过；4904来源、105既有、20新输入零漂移，仅私有ArtDB两人death查表。真实原level1战斗伤害、四阶段倒地、离开活体列表、影子批保留/释放与节点释放完成。直接查看并保存林冲SW四阶段和武松四向落地8图；其余死亡取图/姿态与已直接审查的v8a对应值一致。林冲新SW朝左、头脚方向连续、完整长枪与成人比例保留。证据ordinary_death_pilot_qualified_v10a.json、ordinary_death_pilot_visual_review_v10a.json；这是候选资格，生产默认death仍未采纳，非连续/全项目完成。

核对发现旧Lin SW hurt与death首格是同一个错向区域，需修正活体受击。v12只采用已核验新图的站立受击/后仰首姿态，绝不用躺倒尸体表示活人受击；另外三向hurt资源逐字节别名保留。1姿态/4资源，没有新增PNG。清单ordinary_lin_chong_20261007_hurt_v12.json，真实原关卡普通近战/反击及恢复动作的v13私有复验已启动，尚未取得完成收据。生产ArtDB/Unit未修改；该受击资格以及后续正式接入、连续动作/血条间距/多尺寸UI等仍开放。

此前81白名单文件（55,408,917字节）已推送stable，独立回读7ebfe4e3d5f4e87fc25e5d86dda69b4c6ac0eed5一致；death_diagnostic_source_sync_v10.json记录实际同期范围，后续死亡合格收据和受击工作是新的增量，不冒称已包含在该SHA。v10失败脚本/批和v9未执行生成输入保留；本批未新增缓存清理或平台发布。全目标继续按DEVELOPMENT_AUDIT_20261006.md执行。
<!-- /death-qualified-hurt-pending-v13-current -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '<!-- death-qualified-hurt-pending-v13-current -->' not in old
        extra=''
        if name=='SOURCE_SETUP.md':extra='v13入口：run_ordinary_hurt_pilot_v13.py --from-pilot <已完成v10a的receipt.json> --visual-review qa/zhu_wounded_20261005/ordinary_death_pilot_visual_review_v10a.json --work-root <工程外QA父目录> --run（python -X utf8 -B；无--run预检）。当前批已启动，先查外部continuation_state.json/共享锁，不重复启动。v10a死亡批已完成，v10编译失败原批保留。\n\n'
        p.write_bytes((text+extra+old).encode('utf-8'))
    p=ROOT/'docs/DEVELOPMENT_AUDIT_20261006.md';old=p.read_text(encoding='utf-8')
    p.write_bytes(('2026-10-07增量：v10a倒地/实际影子保留释放346项/32图通过，4904+105+20输入零漂移；8张新原生視口直接查看保存，旧其他死亡来源/姿态一致。新Lin SW hurt采用同一站立recoil候选，v12一姿态/四资源（其他三向原样）已编排，v13真实反击复验运行中。生产默认death/hurt尚未接入；连续/多尺寸/全项目门槛仍开放。81文件诊断源已同步7ebfe4e3，后续收据/受击增量不冒称已在该SHA。\n\n'+old).encode('utf-8'))
    print('Recorded qualified death/shadows, pending hurt and verified prior stable sync.')

if __name__=='__main__':main()
