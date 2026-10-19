from pathlib import Path
import datetime,hashlib,json,urllib.parse,urllib.request
from bs4 import BeautifulSoup
Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/du_xing_portrait_20261019');E.mkdir(parents=True,exist_ok=True)
url='https://zh.wikisource.org/zh-hans/'+urllib.parse.quote('水滸傳_(120回本)/第047回',safe='/()_')
request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 source-verification'})
with urllib.request.urlopen(request,timeout=35) as response:raw=response.read();status=response.status;final_url=response.url
assert status==200
with (E/'chapter47.original.html').open('xb') as f:f.write(raw)
soup=BeautifulSoup(raw,'html.parser');body=soup.select_one('.mw-parser-output');assert body
lines=[line.strip() for line in body.get_text('\n',strip=True).splitlines() if line.strip()]
matches=[{'line':i+1,'text':line} for i,line in enumerate(lines) if '杜兴' in line or '杜興' in line or '鬼脸' in line or '鬼臉' in line or '姓杜' in line]
assert matches
with (Q/'chapter47.txt').open('x',encoding='utf-8') as f:f.write('\n'.join(lines)+'\n')
source={'url':url,'final_url':final_url,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':status,
    'raw_html_sha256':hashlib.sha256(raw).hexdigest(),'raw_html_retained':str(E/'chapter47.original.html'),
    'extracted_text_sha256':hashlib.sha256((Q/'chapter47.txt').read_bytes()).hexdigest(),'matches':matches,
    'scope':'Primary novel text. Costume and exact facial design are not approved merely by a matching name.'}
with (Q/'chapter47_source.json').open('x',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':status,'matches':matches},ensure_ascii=False))
