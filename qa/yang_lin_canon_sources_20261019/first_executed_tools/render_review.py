"""Static source/region browser review; not Godot, Unit or animation acceptance."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys, time
from PIL import Image
Q = Path(__file__).resolve().parent
R = Q.parents[1]
E = Path(sys.argv[1]).resolve()
assert E.is_relative_to(Path('D:/CodexEvidence/shuihu/yang_lin_canon_sources_20261019').resolve())
assert not E.exists()
(E / 'images').mkdir(parents=True)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
sources = {'old': R / 'assets/portraits13.png',
           'portrait': Q / 'native_originals/portrait_v1.png',
           'body': R / 'assets/characters/yang_lin_wounded_20261005/idle_single_se_v4.png',
           'idle': Q / 'native_originals/idle_v2.png'}
for name, source in sources.items():
    target = E / 'images' / (name + '.png')
    shutil.copyfile(source, target)
    assert sha(source) == sha(target)
binding = json.loads((Q / 'selected_regions_v3.json').read_text(encoding='utf-8'))
assert sha(sources['idle']) == binding['sha256']
def panel(name, x, y, size):
    view = '410 0 364 400' if name == 'old' else '0 0 1254 1254'
    native = 1200 if name == 'old' else 1254
    return (f'<rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#383C39"/>'
            f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}" preserveAspectRatio="xMidYMid meet" overflow="hidden">'
            f'<image href="images/{name}.png" width="{native}" height="{native}"/></svg>')
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1600">',
         '<rect width="1800" height="1600" fill="#171916"/>',
         '<g fill="#F0E8D8" font-family="Microsoft YaHei, sans-serif">',
         '<text x="30" y="42" font-size="28">杨林普通肖像 / 持枪待机候选 · 浏览器静态来源检查，非游戏画面</text>']
for name, x, label in [('old', 30, '旧头像区域：背后弯刀'),
                       ('portrait', 600, '新普通肖像：同脸、暖纸纹'),
                       ('body', 1170, '现用获救身体参考：仍无武器')]:
    parts += [f'<text x="{x}" y="84" font-size="23">{label}</text>', panel(name, x, 106, 512)]
for name, x, label in [('old', 30, '旧头像'), ('portrait', 870, '新头像')]:
    parts.append(f'<text x="{x}" y="660" font-size="23">{label} · 128 / 64 / 32px</text>')
    for size in [128, 64, 32]:
        parts.append(panel(name, x, 682, size))
        x += size + 65
parts.append('<text x="30" y="865" font-size="25">普通持枪待机四向 · 每格保持627px虚拟尺寸，同一显示比例，无逐方向包围盒拟合</text>')
for i, row in enumerate(binding['regions']):
    x, y, w, h = row['region']
    cx, cy, cw, ch = row['source_cell']
    px = 30 + i * 435
    parts += [f'<text x="{px}" y="905" font-size="24">{row["direction"].upper()}</text>',
              f'<rect x="{px}" y="925" width="410" height="410" fill="#38413B"/>',
              f'<svg x="{px}" y="925" width="410" height="410" viewBox="{cx} {cy} {cw} {ch}" overflow="hidden">',
              f'<defs><clipPath id="c{i}"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath></defs>',
              f'<image href="images/idle.png" width="1254" height="1254" clip-path="url(#c{i})"/></svg>']
parts += ['<text x="30" y="1410" font-size="23">第44回：头圆耳大、鼻直口方、眉秀目疏、腰细膀阔；一根浑铁笔管枪。</text>',
          '<text x="30" y="1455" font-size="23">服饰/须发沿既有模型，是美术解释；新普通武装候选不改变获救/被缚状态。</text>',
          '<text x="30" y="1500" font-size="23">原稿无像素修改；取图区含完整人物/枪，主体外极淡杂点不取，原均分格检查仍未通过。</text>',
          '<text x="30" y="1545" font-size="23">尚未原生导入/动作衔接/HUD/图鉴/包内/性能验收。当前技能文本也未据此获得原著资格。</text></g></svg>']
svg, output = E / 'review.svg', E / 'review.png'
svg.write_text(''.join(parts), encoding='utf-8')
command = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '--headless=new',
           '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--hide-scrollbars',
           '--force-device-scale-factor=1', '--window-size=1800,1600', '--virtual-time-budget=2000',
           '--user-data-dir=' + str(E / 'profile'), '--screenshot=' + str(output), svg.as_uri()]
with (E / 'stdout.log').open('xb') as stdout, (E / 'stderr.log').open('xb') as stderr:
    child = subprocess.Popen(command, stdout=stdout, stderr=stderr)
    code = child.wait(timeout=45)
assert code == 0
deadline = time.monotonic() + 30
while time.monotonic() < deadline and not output.exists():
    time.sleep(.2)
with Image.open(output) as im:
    assert im.size == (1800, 1600)
for source, name in [(svg, 'review.svg'), (output, 'review.png'),
                     (E / 'stdout.log', 'browser_stdout.log'), (E / 'stderr.log', 'browser_stderr.log')]:
    assert not (Q / name).exists()
    shutil.copyfile(source, Q / name)
receipt = {'scope': 'Browser static source and fixed-region display only, not Godot/runtime/UI/package.',
           'command': command, 'pid': child.pid, 'exit_code': code,
           'sources': {name: {'path': str(p), 'sha256': sha(p)} for name, p in sources.items()},
           'binding_sha256': sha(Q / 'selected_regions_v3.json'),
           'svg_sha256': sha(svg), 'png_sha256': sha(output),
           'production_adopted': False, 'native_accepted': False}
with (Q / 'browser_receipt.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'capture': str(Q / 'review.png'), 'exit_code': code}))
