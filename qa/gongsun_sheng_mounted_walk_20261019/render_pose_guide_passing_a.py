"""Render an authored SVG anatomy guide; never edits a production PNG."""
from pathlib import Path
import hashlib,json,shutil,subprocess,time
from PIL import Image
Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019/pose_guide_se_passing_a')
assert not E.exists();(E/'images').mkdir(parents=True)
src=Q/'native_originals/horse_contact_a_se_v3.png';shutil.copyfile(src,E/'images/target.png');assert src.read_bytes()==(E/'images/target.png').read_bytes()
shutil.copyfile(Q/'se_passing_a_pose_guide.svg',E/'guide.svg')
browser=Path('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe');out=E/'guide.png'
command=[str(browser),'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--window-size=1254,1254','--virtual-time-budget=2000','--user-data-dir='+str(E/'profile'),'--screenshot='+str(out),(E/'guide.svg').as_uri()]
with (E/'stdout.log').open('xb') as stdout,(E/'stderr.log').open('xb') as stderr:
    child=subprocess.Popen(command,stdout=stdout,stderr=stderr);code=child.wait(timeout=40)
deadline=time.monotonic()+30
while time.monotonic()<deadline:
    if out.is_file():
        try:
            with Image.open(out) as im:im.verify()
            break
        except (OSError,SyntaxError):pass
    time.sleep(.2)
assert out.is_file()
dst=Q/'se_passing_a_pose_guide.png';shutil.copyfile(out,dst)
record={'scope':'Authored QA vector pose annotation rendered in isolated headless browser; not a painted production asset or imagegen deliverable.','command':command,'launcher_pid':child.pid,'launcher_exit_code':code,'source_png_unchanged_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'guide_png_sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'guide_svg_sha256':hashlib.sha256((Q/'se_passing_a_pose_guide.svg').read_bytes()).hexdigest()}
with (Q/'pose_guide_passing_a_receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'guide':str(dst),'scope':'QA annotation only, original PNG bytes unchanged'}))
