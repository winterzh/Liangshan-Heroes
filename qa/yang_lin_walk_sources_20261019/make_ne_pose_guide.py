"""Debug anatomy overlay rendered by browser, not a painted character asset or PNG edit."""
from pathlib import Path
import hashlib, json, shutil, subprocess, time
from PIL import Image
Q = Path(__file__).resolve().parent
E = Path('D:/CodexEvidence/shuihu/yang_lin_walk_sources_20261019/ne_pose_guide_v1')
assert not E.exists()
(E/'images').mkdir(parents=True)
source = Q/'native_originals/contact_a_v1.png'
shutil.copyfile(source, E/'images/contact_a.png')
svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="1050" height="1200">
<rect width="1050" height="1200" fill="#F1EEE6"/>
<g font-family="Arial,sans-serif" fill="#192830">
<text x="35" y="45" font-size="28">NE REAR VIEW - OPPOSITE CONTACT B GEOMETRY GUIDE</text>
<text x="35" y="88" font-size="22">Geometry reference only. Do not paint labels, colors or lines in the asset.</text>
<text x="35" y="128" font-size="22">RED: left-screen hip leads AWAY / upper-right.</text>
<text x="35" y="166" font-size="22">BLUE: right-screen hip trails TOWARD viewer / lower-left.</text>
<svg x="80" y="200" width="880" height="880" viewBox="0 627 627 627" overflow="hidden">
<image href="images/contact_a.png" width="1254" height="1254" opacity="0.24"/>
<path d="M400 1000 L320 1100 L250 1160 L220 1180" fill="none" stroke="#176DD0" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M315 1000 L390 1040 L435 1080 L448 1088" fill="none" stroke="#DC3939" stroke-width="25" stroke-linecap="round" stroke-linejoin="round"/>
<g fill="#176DD0" stroke="#FFFFFF" stroke-width="3"><circle cx="400" cy="1000" r="10"/><circle cx="320" cy="1100" r="10"/><circle cx="250" cy="1160" r="8"/></g>
<g fill="#DC3939" stroke="#FFFFFF" stroke-width="3"><circle cx="315" cy="1000" r="10"/><circle cx="390" cy="1040" r="10"/><circle cx="435" cy="1080" r="8"/></g>
<g font-size="15" font-weight="bold"><text x="195" y="988" fill="#A32323">LEFT HIP</text><text x="410" y="994" fill="#0D4B9B">RIGHT HIP</text>
<text x="445" y="1085" fill="#A32323">FORWARD</text><text x="115" y="1190" fill="#0D4B9B">TRAILING</text></g>
</svg>
<text x="35" y="1125" font-size="22">Guide points describe leg ATTACHMENT + overlap, not just boot locations.</text>
<text x="35" y="1163" font-size="22">Keep real cloth/boots, human anatomy, head, hands and one iron spear.</text></g></svg>'''
svg_path, output = E/'guide.svg', E/'guide.png'
svg_path.write_text(svg, encoding='utf-8')
command = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '--headless=new', '--disable-gpu',
           '--no-first-run', '--no-default-browser-check', '--hide-scrollbars', '--force-device-scale-factor=1',
           '--window-size=1050,1200', '--virtual-time-budget=2000', '--user-data-dir='+str(E/'profile'),
           '--screenshot='+str(output), svg_path.as_uri()]
with (E/'stdout.log').open('xb') as stdout, (E/'stderr.log').open('xb') as stderr:
    child = subprocess.Popen(command, stdout=stdout, stderr=stderr)
    code = child.wait(timeout=45)
assert code == 0
deadline = time.monotonic()+30
while time.monotonic()<deadline and not output.exists():
    time.sleep(.2)
with Image.open(output) as im:
    assert im.size == (1050,1200)
for source_file, name in [(svg_path,'ne_pose_guide_v1.svg'), (output,'ne_pose_guide_v1.png')]:
    assert not (Q/name).exists()
    shutil.copyfile(source_file,Q/name)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
receipt = {'scope':'Debug browser pose guide only; not production raster art, native or accepted gait.',
           'source': str(source), 'source_sha256':sha(source), 'command':command,
           'pid':child.pid,'exit_code':code,'svg_sha256':sha(svg_path),'png_sha256':sha(output),
           'no_original_png_pixel_writes':True,'production_adopted':False}
with (Q/'ne_pose_guide_v1_receipt.json').open('x',encoding='utf-8') as stream:
    stream.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'guide':str(Q/'ne_pose_guide_v1.png'),'production_adopted':False}))
