"""Replay one frozen SVG/source composition in a new external directory only."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,time
from PIL import Image
Q=Path(__file__).resolve().parent
version,index,output=sys.argv[1],int(sys.argv[2]),Path(sys.argv[3]).resolve()
assert version in ['v1','v2','v3'] and 0<=index<4
assert output.is_relative_to(Path('D:/CodexEvidence/shuihu/yang_lin_leg_rig_sources_20261019').resolve()) and not output.exists()
(output/'images').mkdir(parents=True)
archive=Q/('browser_rig_'+version)
model=json.loads((archive/'model.json').read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for source in model['sources']['sources']:
    path=Q/source['source'];assert sha(path)==source['sha256']
    shutil.copyfile(path,output/'images'/(source['key'].split('_v')[0]+'.png'))
svg=output/'replay.svg';shutil.copyfile(archive/f'phase_{index:02d}.svg',svg)
png=output/'replay.png'
command=['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--force-device-scale-factor=1','--window-size=1700,900','--virtual-time-budget=2000','--user-data-dir='+str(output/'profile'),'--screenshot='+str(png),svg.as_uri()]
with (output/'stdout.log').open('xb') as stdout,(output/'stderr.log').open('xb') as stderr:
    child=subprocess.Popen(command,stdout=stdout,stderr=stderr);code=child.wait(timeout=45)
assert code==0
deadline=time.monotonic()+30
while time.monotonic()<deadline and not png.exists():time.sleep(.2)
with Image.open(png) as im:assert im.size==(1700,900)
receipt={'scope':'Replay of one frozen static SVG composition only; does not execute IK or native gait.',
         'version':version,'phase_index':index,'command':command,'pid':child.pid,'exit_code':code,
         'source_model_sha256':sha(archive/'model.json'),'svg_sha256':sha(svg),'png_sha256':sha(png),
         'png_byte_identical_to_frozen':sha(png)==sha(archive/f'phase_{index:02d}.png'),
         'production_adopted':False,'native_accepted':False}
with (output/'receipt.json').open('x',encoding='utf-8') as stream:stream.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'capture':str(png),'png_byte_identical_to_frozen':receipt['png_byte_identical_to_frozen'],'native_accepted':False}))
