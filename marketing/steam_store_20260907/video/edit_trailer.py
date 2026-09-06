"""Assemble selected real-gameplay cuts and a brief illustrated title card.

Usage: py -3 edit_trailer.py --timeline timeline.json --output trailer.mp4
Each timeline entry gives source, start, duration and optional caption.
Source clips are Godot Movie Maker AVI files, not generated gameplay.
"""
import argparse, hashlib, json, pathlib, subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--timeline',required=True)
parser.add_argument('--output',required=True)
parser.add_argument('--source-root',help='Repository root for relative source paths')
parser.add_argument('--work-dir',help='Ignored directory for intermediate encodes')
args = parser.parse_args()
timeline_path=pathlib.Path(args.timeline).resolve()
timeline=json.loads(timeline_path.read_text(encoding='utf-8'))
out=pathlib.Path(args.output).resolve()
out.parent.mkdir(parents=True,exist_ok=True)
source_root=pathlib.Path(args.source_root).resolve() if args.source_root else timeline_path.parent
work=pathlib.Path(args.work_dir).resolve() if args.work_dir else out.parent/'edit_work'
work.mkdir(exist_ok=True)
def resolve_source(value):
    p=pathlib.Path(value)
    return p.resolve() if p.is_absolute() else (source_root/p).resolve()
rendered=[]
for i,cut in enumerate(timeline['cuts']):
    source=resolve_source(cut['source'])
    dest=work/f'cut_{i:02d}.mp4'
    duration=float(cut['duration'])
    cmd=['ffmpeg','-hide_banner','-y','-threads','4']
    still=bool(cut.get('title_card'))
    if still:
        cmd+=['-loop','1','-framerate','30','-i',str(source)]
        if cut.get('audio_source'):
            cmd+=['-ss',str(cut.get('audio_start',0)),'-i',str(resolve_source(cut['audio_source']))]
        else:
            cmd+=['-f','lavfi','-i','anullsrc=r=48000:cl=stereo']
    else:
        cmd+=['-ss',str(cut.get('start',0)),'-i',str(source)]
    filters=['scale=1920:1080:force_original_aspect_ratio=decrease','pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x12100d','setsar=1','fps=30']
    caption=cut.get('caption','')
    if caption:
        filters+=['drawbox=x=1360:y=94:w=504:h=74:color=black@0.68:t=fill',
                  "drawtext=fontfile='C\\:/Windows/Fonts/simhei.ttf':text='"+caption+"':fontcolor=0xeacf94:fontsize=40:x=1388:y=111"]
    if i==0: filters+=['fade=t=in:st=0:d=0.2']
    if i==len(timeline['cuts'])-1: filters+=[f'fade=t=out:st={duration-0.5}:d=0.5']
    cmd+=['-t',str(duration),'-vf',','.join(filters),
          '-af',f'afade=t=in:st=0:d=0.08,afade=t=out:st={duration-(1.2 if still else 0.12)}:d={1.2 if still else 0.12}',
          '-map','0:v:0','-map','1:a:0' if still else '0:a:0',
          '-c:v','libx264','-preset','slow','-profile:v','high','-level','4.1','-pix_fmt','yuv420p',
          '-b:v','7000k','-minrate','7000k','-maxrate','7000k','-bufsize','14000k','-x264-params','nal-hrd=cbr:force-cfr=1',
          '-g','60','-keyint_min','60','-sc_threshold','0',
          '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',str(dest)]
    with (work/f'cut_{i:02d}.console.log').open('w',encoding='utf-8') as log:
        subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
    rendered.append(dest)
concat=work/'concat.txt'
concat.write_text(''.join("file '"+p.as_posix().replace("'","'\\''")+"'\n" for p in rendered),encoding='utf-8')
subprocess.run(['ffmpeg','-hide_banner','-y','-f','concat','-safe','0','-i',str(concat),'-c:v','copy',
                '-af','loudnorm=I=-18:TP=-1.5:LRA=9','-c:a','aac','-b:a','192k','-ar','48000','-ac','2',
                '-movflags','+faststart',str(out)],check=True,stdout=subprocess.DEVNULL)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(out)]))
(out.parent/'ffprobe.json').write_text(json.dumps(probe,indent=2,ensure_ascii=False),encoding='utf-8')
receipt={'output':str(out),'size_bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'timeline':timeline,
         'scope':'Every gameplay segment is rendered from the verified game package. The illustrated end card is promotional artwork. No synthesized gameplay, stat boosts, army spawning, fog removal, health restoration or external music. Only native in-game audio, normalized for trailer playback.'}
(out.parent/'video_receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(receipt,ensure_ascii=False))
