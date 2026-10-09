"""Record direct inspection of all 32 final unmodified engine screenshots."""
from pathlib import Path
import hashlib, json
from PIL import Image
repo = Path('E:/ChatGPT/水浒')
evidence = Path(__file__).parent/'20261005_124323_b66e6304/evidence/zhu_captives_bound'
report = json.loads((evidence/'report.json').read_text(encoding='utf-8'))
assert report['passed'] and report['checks'] == 378 and len(report['screenshots']) == 32
identities = {
    'yang_lin': '黑巾浓须、豹纹布衣和蓝腰带绑腿，徒手身前束腕；四向各自站姿正确。',
    'huang_xin': '黄巾黄衣、黑金札甲浓须，徒手身前束腕、无背旗；SW内置编辑后朝左，其余三向正确。',
    'wang_ying': '红巾红衣、皮甲和矮壮体态，徒手身前束腕、无双刀；四向正确且身体高度较矮。',
    'deng_fei': '卷发浓须、褐衣甲红腰带，徒手身前束腕、无铁链；四向正确。',
}
rows = []
for key, note in identities.items():
    for state in ['bound', 'rescued']:
        for direction in ['se', 'sw', 'ne', 'nw']:
            p = evidence/f'{key}_{state}_current_{direction}.png'
            digest = hashlib.sha256(p.read_bytes()).hexdigest()
            assert digest in {x['sha256'] for x in report['screenshots']}
            row = {'path': str(p), 'sha256': digest, 'character': key,
                   'state': state, 'direction': direction, 'passed': True,
                   'review_method': 'direct_view_image_of_full_unmodified_engine_capture',
                   'observation': note if state == 'bound' else
                       '绳索被缚外观消失，原演员恢复现有单朝向行走身体及原武器/背旗/铁链外观；未声称专用无武器获救动作或四向行走完成。'}
            if state == 'bound':
                im = Image.open(p).convert('RGB')
                assert im.size == (1440, 960)
                # Read-only pixel counting in the same fixed viewport as engine QA.
                count = sum(1 for y in range(250, 800) for x in range(400, 1100)
                            if all(c >= 250 for c in im.getpixel((x,y))))
                assert count < 500
                row['near_white_pixels_fixed_viewport'] = count
            rows.append(row)
result = {'complete': True, 'passed': True, 'checks': 378, 'screenshots': rows,
          'scope': '四名现行祝家庄原囚徒的四向被缚站姿与正常解救后的原身体切换，合计32张。七人身份及数值由运行断言验证。',
          'fixtures': '接触位置、无关单位冻结、摄影方向和行走相位；原演员、普通3秒救援回调、Battle继续运行、倍率1。',
          'limitations': ['现有获救武器外观仍需专用无武器伤员动画', '未验收完整撤离或整章胜利',
                          '截图瞬时FPS不证明性能', '局部场景背景/雾层缓存过渡不用于整图资格判定',
                          '未验收跨进程续玩、九模式、Android真机或平台发布']}
(repo/'qa/zhu_captives_bound_20261005/visual_review.json').write_text(
    json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete': True, 'screens_reviewed': len(rows),
                 'bound_white_pixel_max': max(x.get('near_white_pixels_fixed_viewport',0) for x in rows)}))
