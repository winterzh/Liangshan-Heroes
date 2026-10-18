from pathlib import Path
import datetime,hashlib,json,re,urllib.parse,urllib.request
from bs4 import BeautifulSoup
Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/deng_fei_portrait_20261019');E.mkdir(parents=True,exist_ok=True)
url='https://zh.wikisource.org/zh-hans/'+urllib.parse.quote('水滸傳_(120回本)/第044回',safe='/()_')
req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 source-verification'})
with urllib.request.urlopen(req,timeout=35) as response:
    raw=response.read();status=response.status;final_url=response.url
assert status==200
with (E/'chapter44.original.html').open('xb') as f:f.write(raw)
soup=BeautifulSoup(raw,'html.parser');body=soup.select_one('.mw-parser-output');assert body
lines=[s.strip() for s in body.get_text('\n',strip=True).splitlines() if s.strip()]
matches=[]
for i,line in enumerate(lines):
    if re.search('邓飞|鄧飛|红眼|紅眼|铁链|鐵鏈|狻猊',line):matches.append({'line':i+1,'text':line})
assert matches
with (Q/'chapter44.txt').open('x',encoding='utf-8') as f:f.write('\n'.join(lines)+'\n')
row={'url':url,'final_url':final_url,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':status,'raw_html_sha256':hashlib.sha256(raw).hexdigest(),'raw_html_retained':str(E/'chapter44.original.html'),'extracted_text_sha256':hashlib.sha256((Q/'chapter44.txt').read_bytes()).hexdigest(),'matches':matches,'scope':'Primary novel text only; matching lines are evidence to inspect, not automatic approval of every historical/current depiction.'}
with (Q/'chapter44_source.json').open('x',encoding='utf-8') as f:f.write(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':status,'matches':matches},ensure_ascii=False))
