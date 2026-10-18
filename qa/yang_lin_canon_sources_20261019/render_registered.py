"""Compare fixed scale with manually identified boot-contact midpoint anchors."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys, time
from PIL import Image
Q = Path(__file__).resolve().parent
E = Path(sys.argv[1]).resolve()
assert E.is_relative_to(Path('D:/CodexEvidence/shuihu/yang_lin_canon_sources_20261019').resolve())
assert not E.exists()
(E / 'images').mkdir(parents=True)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
binding = json.loads((Q / 'selected_regions_v3.json').read_text(encoding='utf-8'))
source = Q / binding['source']
assert sha(source) == binding['sha256']
shutil.copyfile(source, E / 'images/idle.png')
# Manual semantic sole points, not alpha bounding boxes; uncertainty remains 10 source pixels.
points = {'se': [[268, 574], [425, 524]], 'sw': [[833, 528], [988, 575]],
          'ne': [[277, 1086], [424, 1135]], 'nw': [[827, 1135], [975, 1082]]}
rows = []
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="820">',
         '<rect width="1800" height="820" fill="#171916"/>',
         '<g fill="#F0E8D8" font-family="Microsoft YaHei, sans-serif">',
         '<text x="25" y="40" font-size="27">杨林四向持枪待机 · 固定比例 / 人工双靴语义锚点 · 浏览器静态候选</text>']
for i, row in enumerate(binding['regions']):
    direction = row['direction']
    p1, p2 = points[direction]
    anchor = [(p1[0]+p2[0])/2, (p1[1]+p2[1])/2]
    target = [313.5, 550]
    delta = [target[0]-anchor[0], target[1]-anchor[1]]
    rows.append({'direction': direction, 'manual_boot_points': points[direction],
                 'source_anchor': anchor, 'target_anchor': target, 'translation': delta,
                 'uniform_source_scale': 1.0, 'uncertainty_source_pixels': 10})
    x, y, w, h = row['region']
    px = 25 + i*440
    parts += [f'<text x="{px}" y="90" font-size="25">{direction.upper()}</text>',
              f'<rect x="{px}" y="110" width="420" height="420" fill="#38413B"/>',
              f'<svg x="{px}" y="110" width="420" height="420" viewBox="0 0 627 627" overflow="hidden">',
              f'<defs><clipPath id="r{i}"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath></defs>',
              f'<g transform="translate({delta[0]} {delta[1]})">',
              f'<image href="images/idle.png" width="1254" height="1254" clip-path="url(#r{i})"/>']
    for bx, by in points[direction]:
        parts.append(f'<circle cx="{bx}" cy="{by}" r="5" fill="#EBCF74"/>')
    parts += ['</g>', '<path d="M303.5 550h20M313.5 540v20" stroke="#76CED0" stroke-width="2"/>', '</svg>']
parts += ['<text x="25" y="590" font-size="23">黄点：人工靴底参照；青色十字：双点中点。四向同一比例，只平移注册，无按包围盒缩放。</text>',
          '<text x="25" y="640" font-size="23">人工点位误差约10源像素；不证明物理接地、步态或接触。枪的后段受身体遮挡仍需动作链核对。</text>',
          '<text x="25" y="690" font-size="23">原PNG保持不变；取图区和透明边界见selected_regions_v3.json，未改写均分格未通过的原检查。</text>',
          '<text x="25" y="740" font-size="23">只比较静态造型/四向体量与锚点；未原生导入、未接入Unit/图鉴/HUD/编译包或剧情状态。</text></g></svg>']
svg, output = E / 'registered.svg', E / 'registered.png'
svg.write_text(''.join(parts), encoding='utf-8')
command = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '--headless=new',
           '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--hide-scrollbars',
           '--force-device-scale-factor=1', '--window-size=1800,820', '--virtual-time-budget=2000',
           '--user-data-dir=' + str(E / 'profile'), '--screenshot=' + str(output), svg.as_uri()]
with (E / 'stdout.log').open('xb') as stdout, (E / 'stderr.log').open('xb') as stderr:
    child = subprocess.Popen(command, stdout=stdout, stderr=stderr)
    code = child.wait(timeout=45)
assert code == 0
deadline = time.monotonic() + 30
while time.monotonic() < deadline and not output.exists():
    time.sleep(.2)
with Image.open(output) as im:
    assert im.size == (1800, 820)
if '--archive-to-project' in sys.argv[2:]:
    for source_file, name in [(svg, 'registered.svg'), (output, 'registered.png'),
                              (E/'stdout.log', 'registered_stdout.log'), (E/'stderr.log', 'registered_stderr.log')]:
        assert not (Q / name).exists()
        shutil.copyfile(source_file, Q / name)
receipt = {'scope': 'Static browser manual-anchor comparison; not native/gameplay acceptance.',
           'command': command, 'pid': child.pid, 'exit_code': code,
           'source_sha256': sha(source), 'binding_sha256': sha(Q/'selected_regions_v3.json'),
           'svg_sha256': sha(svg), 'png_sha256': sha(output), 'registration': rows,
           'executed_helper_sha256': sha(Path(__file__)),
           'production_adopted': False, 'native_accepted': False}
with (E / 'registration.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
if '--archive-to-project' in sys.argv[2:]:
    assert not (Q / 'registration_v1.json').exists()
    shutil.copyfile(E / 'registration.json', Q / 'registration_v1.json')
print(json.dumps({'capture': str(output), 'manual_uncertainty': 10, 'exit_code': code}))
