"""Render unmodified source images at stated CSS sizes; this is not Godot QA."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys, time
from PIL import Image

Q = Path(__file__).resolve().parent
R = Q.parents[1]
key = sys.argv[1]
assert key in {'portrait_v2', 'portrait_v3'}
E = Path(sys.argv[2]).resolve()
assert E.is_relative_to(Path('D:/CodexEvidence/shuihu/deng_fei_portrait_20261019').resolve())
assert not E.exists()
(E / 'images').mkdir(parents=True)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
sources = {'old': R / 'assets/portraits13.png',
           'first': Q / 'native_originals/portrait_v1.png',
           'new': Q / 'native_originals' / (key + '.png')}
for name, source in sources.items():
    target = E / 'images' / (name + '.png')
    shutil.copyfile(source, target)
    assert sha(source) == sha(target)
def portrait(name, x, y, size):
    view = '0 0 410 400' if name == 'old' else '0 0 1254 1254'
    native = 1200 if name == 'old' else 1254
    return (f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}" '
            'preserveAspectRatio="xMidYMid meet" overflow="hidden">'
            f'<image href="images/{name}.png" width="{native}" height="{native}"/></svg>')
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1500">',
         '<rect width="1800" height="1500" fill="#17130F"/>',
         '<g fill="#EFE7D3" font-family="Microsoft YaHei, sans-serif">',
         f'<text x="30" y="42" font-size="28">邓飞 {key} · 浏览器静态来源对比，非游戏画面</text>']
for name, x, label in [('old', 30, '现用图集区域'), ('first', 600, '第一版：面部偏小'),
                       ('new', 1170, '近景候选：发髻留边')]:
    parts += [f'<text x="{x}" y="84" font-size="24">{label}</text>', portrait(name, x, 106, 512)]
for name, y, label in [('first', 705, '第一版'), ('new', 1050, key)]:
    parts.append(f'<text x="30" y="{y-30}" font-size="24">{label} · 原PNG等比显示</text>')
    x = 30
    for size in [256, 128, 96, 64, 32]:
        parts += [portrait(name, x, y, size),
                  f'<text x="{x}" y="{y+size+28}" font-size="22">{size}px</text>']
        x += size + 100
parts += ['<text x="30" y="1430" font-size="23">原著第44回：双睛赤、铁链。发式/衣甲/纸纹沿用游戏美术解释。</text>',
          '<text x="30" y="1470" font-size="23">只验证静态来源和缩小阅读；未接入Godot/HUD/图鉴/编译包。原PNG像素未修改。</text></g></svg>']
svg, output = E / 'review.svg', E / 'review.png'
svg.write_text(''.join(parts), encoding='utf-8')
browser = Path('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
command = [str(browser), '--headless=new', '--disable-gpu', '--no-first-run',
           '--no-default-browser-check', '--hide-scrollbars', '--force-device-scale-factor=1',
           '--window-size=1800,1500', '--virtual-time-budget=2000',
           '--user-data-dir=' + str(E / 'profile'), '--screenshot=' + str(output), svg.as_uri()]
with (E / 'stdout.log').open('xb') as stdout, (E / 'stderr.log').open('xb') as stderr:
    child = subprocess.Popen(command, stdout=stdout, stderr=stderr)
    code = child.wait(timeout=45)
assert code == 0
deadline = time.monotonic() + 30
while time.monotonic() < deadline:
    if output.exists() and output.stat().st_size > 100000:
        try:
            with Image.open(output) as im:
                im.verify()
            break
        except (OSError, SyntaxError):
            pass
    time.sleep(.2)
with Image.open(output) as im:
    assert im.size == (1800, 1500)
prefix = 'readability_' + key
for source, suffix in [(svg, '.svg'), (output, '.png')]:
    target = Q / (prefix + suffix)
    assert not target.exists()
    shutil.copyfile(source, target)
receipt = {'scope': 'Isolated browser static source comparison only; not Godot/UI/package acceptance.',
           'command': command, 'pid': child.pid, 'exit_code': code,
           'sources': {name: {'path': str(p), 'sha256': sha(p)} for name, p in sources.items()},
           'legacy_region': [0, 0, 410, 400], 'sizes': [256, 128, 96, 64, 32],
           'svg_sha256': sha(svg), 'png_sha256': sha(output), 'production_adopted': False}
with (Q / (prefix + '_receipt.json')).open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'capture': str(Q / (prefix + '.png')), 'exit_code': code}))
