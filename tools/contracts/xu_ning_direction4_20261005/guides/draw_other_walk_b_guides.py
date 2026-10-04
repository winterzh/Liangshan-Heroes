from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).parent
f=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
for direction in ['sw','ne','nw']:
 im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
 d.text((15,15),direction.upper()+' WALK B: BLUE anatomical LEFT / RED RIGHT leg',font=f,fill='black')
 d.text((15,48),'Pose guide only: keep arm geometry from identity reference',font=f,fill='black')
 d.ellipse((440,170,570,300),fill='#cccccc',outline='black',width=4)
 end={'sw':(395,265),'ne':(620,205),'nw':(395,205)}[direction]
 d.line([(500,235),end],fill='black',width=5)
 d.polygon([(430,320),(620,320),(620,630),(410,630)],fill='#dddddd',outline='black',width=4)
 if direction=='sw':
  right=[(450,620),(560,780),(620,935)];left=[(570,620),(445,755),(355,665)]
  d.polygon([(598,915),(635,915),(644,958),(560,965)],fill='#dc3333',outline='black',width=3)
  d.polygon([(332,649),(370,655),(390,698),(345,720)],fill='#0075d4',outline='black',width=3)
 else:
  left=[(450,620),(425,735),(405,810)]
  right=[(570,620),(650,780),(720,940)]
  d.polygon([(385,790),(425,790),(455,830),(390,845)],fill='#0075d4',outline='black',width=3)
  d.polygon([(692,914),(733,927),(751,980),(710,991)],fill='#dc3333',outline='black',width=3)
 d.line(left,fill='#0075d4',width=28);d.line(right,fill='#dc3333',width=28)
 im.save(p/('walk_b_'+direction+'_guide.png'))
