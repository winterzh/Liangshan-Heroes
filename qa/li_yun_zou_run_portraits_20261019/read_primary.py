from pathlib import Path
import argparse,datetime,hashlib,json,urllib.parse,urllib.request
from bs4 import BeautifulSoup
parser=argparse.ArgumentParser();parser.add_argument('chapter',type=int,choices=[43,49]);args=parser.parse_args()
Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/li_yun_zou_run_portraits_20261019');E.mkdir(parents=True,exist_ok=True)
url='https://zh.wikisource.org/zh-hans/'+urllib.parse.quote(f'水滸傳_(120回本)/第{args.chapter:03d}回',safe='/()_')
request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 source-verification'})
with urllib.request.urlopen(request,timeout=35) as response:raw=response.read();status=response.status;final=response.url
assert status==200;name=f'chapter{args.chapter}'
with (E/(name+'.original.html')).open('xb') as f:f.write(raw)
body=BeautifulSoup(raw,'html.parser').select_one('.mw-parser-output');assert body
lines=[line.strip() for line in body.get_text('\n',strip=True).splitlines() if line.strip()]
terms=['李云','李雲','青眼'] if args.chapter==43 else ['邹润','鄒潤','肉瘤','独角','獨角']
matches=[{'line':i+1,'text':line} for i,line in enumerate(lines) if any(term in line for term in terms)];assert matches
with (Q/(name+'.txt')).open('x',encoding='utf-8') as f:f.write('\n'.join(lines)+'\n')
source={'url':url,'final_url':final,'status':status,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'raw_html_sha256':hashlib.sha256(raw).hexdigest(),'raw_html_retained':str(E/(name+'.original.html')),
    'extracted_text_sha256':hashlib.sha256((Q/(name+'.txt')).read_bytes()).hexdigest(),'matches':matches,
    'scope':'Primary novel text only. A matching nickname does not prescribe supernatural anatomy or approve existing game skills.'}
with (Q/(name+'_source.json')).open('x',encoding='utf-8') as f:f.write(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'chapter':args.chapter,'status':status,'match_lines':[r['line'] for r in matches]},ensure_ascii=False))
