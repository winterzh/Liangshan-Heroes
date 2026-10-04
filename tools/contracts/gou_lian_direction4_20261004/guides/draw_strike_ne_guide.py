from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',26)
d.ellipse((445,210,580,350),fill='#cccccc',outline='black',width=5)
d.line([(550,275),(625,240)],fill='black',width=7)
d.polygon([(430,350),(620,340),(665,650),(380,650)],fill='#dddddd',outline='black',width=4)
d.line([(440,650),(330,890)],fill='black',width=28);d.line([(590,650),(750,855)],fill='black',width=28)
d.line([(180,680),(800,160)],fill='#875b35',width=16)
d.polygon([(800,160),(730,196),(773,222)],fill='#666666')
left=[(430,360),(340,430),(412,485)];right=[(620,360),(710,610),(264,610)]
d.line(left,fill='#0075d4',width=24);d.line(right,fill='#dc3333',width=24)
for points,color in [(left,'#0075d4'),(right,'#dc3333')]:
 x,y=points[-1];d.ellipse((x-18,y-18,x+18,y+18),fill=color)
d.text((25,25),'NE BACK THRUST: LEFT higher front / RIGHT lower rear',font=font,fill='black')
d.text((25,70),'BLUE LEFT at screen-left / RED RIGHT across waist',font=font,fill='black')
d.text((25,115),'Geometry only; no colors/text in production sprite',font=font,fill='black')
im.save(Path(__file__).parent/'strike_ne_guide.png')
