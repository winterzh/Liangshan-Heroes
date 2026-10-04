from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).parent
im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
f=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
d.text((15,15),'SE WALK B: RED right leg down-front on SCREEN LEFT',font=f,fill='black')
d.text((15,48),'BLUE left leg folded back on SCREEN RIGHT',font=f,fill='black')
d.ellipse((440,170,570,300),fill='#cccccc',outline='black',width=4)
d.line([(550,230),(620,265)],fill='black',width=5)
d.polygon([(430,320),(620,320),(620,630),(410,630)],fill='#dddddd',outline='black',width=4)
d.line([(260,520),(900,330)],fill='#875b35',width=14)
d.line([(430,335),(400,430),(400,479)],fill='black',width=20)
d.line([(620,335),(650,360),(660,401)],fill='black',width=20)
d.line([(450,620),(400,780),(415,930)],fill='#dc3333',width=28)
d.polygon([(389,913),(429,913),(485,955),(402,964)],fill='#dc3333',outline='black',width=3)
d.line([(570,620),(640,755),(690,615)],fill='#0075d4',width=28)
d.polygon([(675,594),(706,607),(742,650),(708,681),(677,646)],fill='#0075d4',outline='black',width=3)
d.polygon([(900,330),(846,332),(860,362)],fill='#666666')
im.save(p/'se_walk_b_guide.png')
