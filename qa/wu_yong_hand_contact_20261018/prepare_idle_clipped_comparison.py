"""Keep the first native output; isolate each comparison panel in new Controls."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent
old=Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2b_20261018')
E=Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2c_20261018')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not E.exists()
previous=Path(json.loads((old/'latest.json').read_text())['receipt'])
receipt=json.loads(previous.read_text());assert receipt['complete'] and receipt['native_checks']==19
binding=json.loads((old/'prepared_binding.json').read_text());P=E/'prepared'
for row in binding['frozen']:
    src=Path(binding['project'])/row['path'];assert sha(src)==row['sha256']
    dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
script=(P/'preview.gd').read_text()
script=script.replace('var images: Array=[]','''var panels: Array=[]
	for row in range(2):
		for col in range(2):
			var panel:=Stage.new();panel.data=stage.data;panel.textures=stage.textures;panel.row=row;panel.col=col
			panel.position=Vector2(col*512,row*512);panel.size=Vector2(512,512);panel.clip_contents=true
			root.add_child(panel);panels.append(panel)
	var images: Array=[]''')
script=script.replace('stage.direction=direction;stage.queue_redraw()','for panel in panels:panel.direction=direction;panel.queue_redraw()')
script=script.replace('extends Node2D:', 'extends Control:')
script=script.replace('var direction: String="se"', 'var direction: String="se"\n\tvar row: int=0\n\tvar col: int=0')
script=script.replace('draw_rect(Rect2(0,0,1024,1024)', 'draw_rect(Rect2(0,0,512,512)')
start=script.index('\t\tfor row in range(2):',script.index('func _draw()'))
block=script[start:];lines=block.splitlines();assert 'for col in range(2)' in lines[1]
remainder='\n'.join(line[2:] for line in lines[2:])+'\n'
remainder=remainder.replace('var at:=Vector2(col*512,row*512)','var at:=Vector2.ZERO')
script=script[:start]+remainder
(P/'preview.gd').write_text(script,encoding='utf-8')
with (Q/'idle_repair_v2c_preview.gd.txt').open('x',encoding='utf-8') as f:f.write(script)
binding.update(project=str(P),previous_receipt=str(previous),scope='Idle-only comparison with clipped panels. Same source PNGs, fixed transforms and cart as v2b; no new gait, Unit or physical hidden-hand acceptance.')
binding['frozen']=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
save(E/'prepared_binding.json',binding);save(Q/'idle_repair_v2c_binding.json',binding)
save(Q/'idle_repair_v2b_display_limitation.json',{'native_checks_passed':19,'screenshots':4,'pngs_and_registration_unchanged':True,'limitation':'Magnified lower panels draw outside their cells and obscure upper comparison. Preserve originals; v2c gives every panel an independent clipped Control. This is a QA display correction, not an art or runtime adoption.','receipt':str(previous),'successor':str(E)})
runner=(Q/'run_idle_repair_v2b.py').read_text().replace('wu_yong_idle_rear_repair_v2b_20261018','wu_yong_idle_rear_repair_v2c_20261018').replace("previous['native_checks']==43","previous['native_checks']==19")
with (Q/'run_idle_repair_v2c.py').open('x',encoding='utf-8') as f:f.write(runner)
print(json.dumps({'prepared':str(P),'source_png_changes':0,'panel_clipping':True}))
