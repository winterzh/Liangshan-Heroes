"""Save direct-review notes for the final 12 native engine captures; do not edit pixels."""
from pathlib import Path
import json,hashlib
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
accepted=[p for p in base.glob('20261005_*/evidence/receipt.json') if json.loads(p.read_text(encoding='utf-8')).get('complete')]
assert len(accepted)==1
directory=accepted[0].parent/'current_campaign_art'
r=json.loads((directory/'report.json').read_text(encoding='utf-8'))
assert r['passed'] and not r['failures'] and len(r['screenshots'])==12
rows=[]
for row in r['screenshots']:
    p=Path(row['path']);assert p.resolve().is_relative_to(directory.resolve())
    assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256']
    if '_bound_current_' in row['name']:
        note='石秀原蓝灰衣和头巾、既有被缚站姿按四向专图路由；邻近姓名/血条遮挡上身，不能凭这些画面认定绳索和手腕完整可读，不声称新六人身前束腕或通用身份全统一。'
    elif '_rescued_current_' in row['name']:
        note='石秀解除绳索后恢复原蓝灰衣、发髻头带和双刀通用行走身体；现有单朝向/镜像仍可见，专用无武器伤员动作未完成。'
    else:
        note='原七名获救者沿清理后的原地图和偏门移动，画面为该路标实况；姓名/血条和队伍选圈仍有重叠。到营距离、实例身份及非战斗属性以同轮运行记录证明。'
    rows.append({**row,'passed':True,'review_method':'Direct view_image of each full unmodified final engine PNG','observation':note})
result={'complete':True,'passed':True,'scope':'Current-owned Shi Xiu bound/rescued routing and original seven actor movement presentation only; not final art/UI/campaign qualification.',
        'screenshots':rows,'limitations':['获救仍持武器，需要补专用无武器伤员待机/行走',
        '石秀既有被缚衣装和后束腕路线保留，未声称新原画或身份完全统一',
        '首张开场标题刷新滞后，姓名/血条/选圈有遮挡，完整UI资格仍开放',
        '普通攻击清路使用原林冲近战位置与冻结敌兵夹具，未验证自由护送战',
        '未摧毁大营或完成整章胜利、跨进程续玩、九模式、性能/真机资格']}
qa=repo/'qa/current_campaign_art_20261005';qa.mkdir(parents=True,exist_ok=True)
(qa/'visual_review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'screens_reviewed':len(rows),'scope':result['scope']}))
