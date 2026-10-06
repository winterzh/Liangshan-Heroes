"""Record original production routing separately from earlier candidate receipts."""
from pathlib import Path
import json,hashlib,argparse
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--receipt',type=Path);args=ap.parse_args()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
marker='<!-- original-rescued-route-v4-current -->'
proof=None
if args.receipt:
    r=json.loads(args.receipt.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
    report=args.receipt.parent/'rescued_seven_current/report.json';v=json.loads(report.read_text(encoding='utf-8'))
    assert v['passed'] and not v['failures']
    out=ROOT/'qa/zhu_wounded_20261005/original_rescued_seven_production_route_v4.json'
    assert not out.exists()
    proof={'scope':'Original eight opening deployments and real Zhu timed rescue/seven-actor evacuation with frozen nonparticipants and explicit contact/phase fixtures; not full chapter victory, cross-process continue, continuous playback, performance or Android acceptance',
           'complete':True,'production_qualified':False,'receipt':str(args.receipt),'receipt_sha256':sha(args.receipt),'report':str(report),'report_sha256':sha(report),
           'checks':v['checks'],'captures':len(v['screenshots']),'input_count':len(r['source_files']),
           'source_drift':0,'private_source_drift':0,'lock_released':True,
           'runtime':v['runtime'],'screenshots':v['screenshots'],'source_files':r['source_files'],
           'remaining':['Continuous gait/cloth visual review','Cross-process save and reward once','Legacy three-day and ordinary Wu Song/Lin Chong action transition','Eight dynamic chapters/nine modes/ten-minute performance/Android qualification']}
    out.write_bytes((json.dumps(proof,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
status=('原Battle回归已通过%d项、%d张原生视口截图、%d冻结输入零漂移；原七人经真实解救回调并用正常玩家命令撤回前营，姿态取图/标准头像/选择按钮/缺失武装动作拒绝与真实撤离均核验。证据：qa/zhu_wounded_20261005/original_rescued_seven_production_route_v4.json。'%(proof['checks'],proof['captures'],proof['input_count'])) if proof else '原Battle新回归已准备并运行中，尚无完成收据；不得将候选Unit证据改写为原关卡验收。'
block='\n'.join([marker,'## 2026-10-06 当前增量：原关卡获救七人取图接入','',
    '人物姿态继续按特性分别处理：武松、林冲普通待机挺拔；时迁机警轻身而非病态驼背，秦明强壮端正，王英成熟矮壮，杨林灵活，黄信稳健，邓飞粗犷警觉。七人候选清单与原图/失败父图不改写。',
    '', 'Unit.visual_art_variant仅在现行祝家庄RTS脚本、该关prisoners成员、梁山/非战斗/非英雄/已获救及空显式变体时派生zhu_wounded_人物key。原解救回调及各人真实生命值不变；获救速度82/攻击0/无技能与存档空art_variant校验不变；显式剧情变体优先，旧三日关卡恢复战斗能力后不触发此路由。只说明字段契约兼容，不承诺不同安装来源SHA的旧存档可跨版本恢复。',
    '', 'CampaignArt登记七套原生idle/walk资源；ArtDB本体、来源/方向、精确动作、来源预览与所属人物UI查询一致，错人物/非法方向拒绝。hurt复用站立idle，不称新受伤动作；缺失attack/gather/assisted/death/down拒绝普通武装回退，终态走现有同造型程序化绘制。Unit各实际身体查询及旧scenery影子兼容入口使用派生造型，UI保留标准人物头像。',
    '',status,
    '', '独立复验入口：python -X utf8 -B tools/run_rescued_seven_art_qa.py --repo <checkout> --manifest rescued_seven_current=assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_declared_v4.json --work-root <工程外QA目录> --cache-from <已核验原关卡QA批> --shared-checks --run。无--run为只读预检。自然等待Godot空闲；不控制或联系其他任务。新QA脚本tools/rescued_seven_art_qa.gd保留旧current_campaign_art_qa及历史收据。',
    '', '连续步态/衣装、完整终态画面、跨进程保存退出续玩/奖励一次性、旧三日与普通武松/林冲动作衔接仍待进一步资格验证。全计划的八关动态阶段/生产/船体/身份动作UI、九模式、约10分钟性能尾帧与Android真机/平台目标仍开放。production_qualified=false。本批尚未提交/推送、清理、打包或发布。',
    '<!-- /original-rescued-route-v4-current -->',''])
for name in ['docs/WORKLOG.md','docs/PROJECT_STATUS.md','docs/DEVELOPMENT_PLAN.md','docs/SOURCE_SETUP.md','docs/DIRECTORY_INDEX.md','docs/CHARACTER_POSTURE_20261006.md','docs/RESCUED_ART_INTEGRATION_20261006.md','qa/zhu_wounded_20261005/README.md','tools/contracts/zhu_wounded_20261005/README.md']:
    p=ROOT/name;s=p.read_text(encoding='utf-8')
    if marker in s:
        end=s.index('<!-- /original-rescued-route-v4-current -->')+len('<!-- /original-rescued-route-v4-current -->')
        s=s[:s.index(marker)]+block+s[end:].lstrip('\n')
    else:s=block+'\n'+s
    p.write_bytes(s.encode('utf-8'))
print(json.dumps({'document_count':9,'runtime_qualified':bool(proof),'production_qualified':False}))
