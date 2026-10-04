from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
p=Path(__file__).parent
im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
f=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
d.text((15,15),'BACK VIEW NE: blue LEFT shoulder and FRONT hand',font=f,fill='black')
d.text((15,48),'Red RIGHT shoulder and REAR hand across lower back',font=f,fill='black')
d.ellipse((445,180,580,315),fill='#cccccc',outline='black',width=4)
d.line([(550,235),(610,205)],fill='black',width=6)
d.polygon([(430,330),(620,330),(660,650),(390,650)],fill='#dddddd',outline='black',width=4)
d.line([(440,650),(405,880)],fill='black',width=26)
d.line([(590,650),(655,860)],fill='black',width=26)
d.line([(330,950),(620,150)],fill='#875b35',width=14)
d.polygon([(620,150),(591,198),(620,205)],fill='#666666')
left=[(430,345),(445,390),(545,357)]
right=[(620,345),(665,600),(432,669)]
for points,color in [(left,'#0075d4'),(right,'#dc3333')]:
 d.line(points,fill=color,width=24)
 for x,y in [points[0],points[-1]]:d.ellipse((x-14,y-14,x+14,y+14),fill=color)
im.save(p/'ne_compact_guide.png')
