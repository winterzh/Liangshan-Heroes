from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
base=Path(__file__).parent
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',26)
for direction in ['sw','ne']:
 im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
 d.ellipse((445,210,580,350),fill='#cccccc',outline='black',width=5)
 d.polygon([(430,350),(620,340),(665,650),(380,650)],fill='#dddddd',outline='black',width=4)
 d.line([(440,650),(400,880)],fill='black',width=28);d.line([(590,650),(660,880)],fill='black',width=28)
 if direction=='sw':
  d.line([(510,290),(420,310)],fill='black',width=7)
  d.line([(190,730),(900,345)],fill='#875b35',width=16)
  left=[(620,360),(620,490),(350,643)];right=[(430,360),(345,480),(555,532)]
  d.polygon([(190,730),(240,690),(260,735)],fill='#666666')
 else:
  d.line([(550,275),(625,240)],fill='black',width=7)
  d.line([(280,820),(890,280)],fill='#875b35',width=16)
  left=[(430,360),(500,350),(760,395)];right=[(620,360),(710,610),(445,674)]
  d.polygon([(890,280),(820,315),(860,335)],fill='#666666')
 d.line(left,fill='#0075d4',width=24);d.line(right,fill='#dc3333',width=24)
 for points,color in [(left,'#0075d4'),(right,'#dc3333')]:
  x,y=points[-1];d.ellipse((x-18,y-18,x+18,y+18),fill=color)
 d.text((25,25),direction.upper()+' GEOMETRY ONLY - LEFT forward / RIGHT rear',font=font,fill='black')
 d.text((25,70),'BLUE = anatomical LEFT arm, RED = anatomical RIGHT arm',font=font,fill='black')
 d.text((25,115),'Repaint normal costume; no diagram colors or labels in sprite',font=font,fill='black')
 im.save(base/('grip_'+direction+'.png'))
