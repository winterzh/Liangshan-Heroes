"""Loopback-only local preview with explicit canvas-evidence capture."""
import hashlib,http.server,json,pathlib,re
E=pathlib.Path(__file__).parent;P=pathlib.Path('D:/CodexEvidence/shuihu/tribute_cart_wheel_layers_20261018/browser_preview');C=E/'canvas_captures';C.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(P),**kwargs)
 def do_POST(self):
  name=self.path.removeprefix('/capture/')
  if not self.path.startswith('/capture/') or not re.fullmatch(r'browser_canvas_(se|sw|ne|nw)_[0-9]+\.[0-9]{2}\.png',name):self.send_error(400);return
  size=int(self.headers.get('Content-Length','0'))
  if self.headers.get('Origin')!='http://127.0.0.1:18762' or not 8<size<5*1024*1024:self.send_error(400);return
  raw=self.rfile.read(size)
  if not raw.startswith(b'\x89PNG\r\n\x1a\n'):self.send_error(400);return
  dest=C/name
  if dest.exists() and dest.read_bytes()!=raw:self.send_error(409,'Capture name already has different bytes');return
  dest.write_bytes(raw);out=json.dumps({'saved':name,'path':str(dest),'sha256':hashlib.sha256(raw).hexdigest()}).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(out)));self.end_headers();self.wfile.write(out)
http.server.ThreadingHTTPServer(('127.0.0.1',18762),Handler).serve_forever()
