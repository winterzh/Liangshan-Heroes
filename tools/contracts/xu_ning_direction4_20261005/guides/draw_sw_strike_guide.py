from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
p=Path(__file__).parent
im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
f=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
d.text((12,12),'SW: BLUE left arm front; RED right arm rear. Arms CROSS.',fill='black',font=f)
d.ellipse((395,170,525,300),fill='#ccc',outline='black',width=3)
d.line([(405,250),(355,265)],fill='black',width=5)
d.polygon([(390,320),(605,325),(650,610),(430,640)],fill='#ddd',outline='black',width=3)
d.line([(455,630),(305,740),(245,880)],fill='black',width=26)
d.line([(610,625),(765,780),(880,870)],fill='black',width=26)
d.line([(120,745),(890,375)],fill='#875b35',width=14)
d.polygon([(120,745),(180,730),(161,700)],fill='#777')
for pts,col in [([(605,325),(540,460),(300,659)],'#0075d4'), ([(390,320),(380,540),(555,536)],'#dc3333')]:
 d.line(pts,fill=col,width=24)
 for x,y in [pts[0],pts[-1]]: d.ellipse((x-15,y-15,x+15,y+15),fill=col)
im.save(p/'sw_strike_guide.png')
