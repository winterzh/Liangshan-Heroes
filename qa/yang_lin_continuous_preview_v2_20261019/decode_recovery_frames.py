"""Read the actual own-canvas recording to inspect intermediate recovery positions."""
from pathlib import Path
import hashlib,json,subprocess,sys
from PIL import Image
E=Path(sys.argv[1]).resolve();target=E/'recovery_frames';target.mkdir(exist_ok=False)
video=E/'continuous_canvas.webm';rows=[]
for index,seconds in enumerate([4.85,5.10,9.85,10.10,12.15,12.45]):
    path=target/f'recovery_{index:02d}_{seconds:.2f}.png'
    command=['ffmpeg','-hide_banner','-loglevel','error','-n','-ss',str(seconds),'-i',str(video),'-frames:v','1',str(path)]
    subprocess.run(command,check=True)
    with Image.open(path) as im:assert im.size==(1600,520)
    rows.append({'file':path.name,'seek_seconds':seconds,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'command':command})
with (target/'extraction_receipt.json').open('x',encoding='utf-8') as f:
    f.write(json.dumps({'source_video_sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'scope':'Decoded original video frames, no overlays, resizing, retouching or alpha cleanup. Seek is approximate codec timestamp selection.','frames':rows},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'decoded_frames':len(rows)}))
