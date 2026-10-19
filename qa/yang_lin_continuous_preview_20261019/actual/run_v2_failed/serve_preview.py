"""Temporary loopback preview and owned result collector; no user/profile access."""
from pathlib import Path
import argparse,hashlib,http.server,json,os,threading,time,urllib.parse
parser=argparse.ArgumentParser();parser.add_argument('--html',required=True);parser.add_argument('--ready',required=True);parser.add_argument('--build-id',required=True);parser.add_argument('--port',type=int,default=8769)
args=parser.parse_args();page=Path(args.html).resolve();ready=Path(args.ready).resolve()
payload=page.read_bytes()
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path=urllib.parse.urlsplit(self.path).path
        if path in ['/','/viewer.html']:
            data=payload;kind='text/html; charset=utf-8'
        elif path=='/hold.svg':
            time.sleep(18)
            data=b'<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>';kind='image/svg+xml'
            timer=threading.Timer(2,self.server.shutdown);timer.daemon=True;timer.start()
        else:self.send_error(404);return
        self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data)
    def do_POST(self):
        if urllib.parse.urlsplit(self.path).path!='/report':self.send_error(404);return
        size=int(self.headers.get('Content-Length','0'))
        if not 0<size<=20*1024*1024:self.send_error(413);return
        raw=self.rfile.read(size)
        try:
            report=json.loads(raw)
            assert report.get('buildId')==args.build_id
            with (ready.parent/'posted_report.json').open('xb') as stream:stream.write(raw)
        except (ValueError,AssertionError,FileExistsError):self.send_error(409);return
        self.send_response(200);self.send_header('Content-Length','2');self.end_headers();self.wfile.write(b'OK')
with http.server.ThreadingHTTPServer(('127.0.0.1',args.port),Handler) as server:
    with ready.open('x',encoding='utf-8') as stream:stream.write(json.dumps({'pid':os.getpid(),'port':args.port,'address':'127.0.0.1','html_sha256':hashlib.sha256(payload).hexdigest()})+'\n')
    timer=threading.Timer(45,server.shutdown);timer.daemon=True;timer.start()
    print(json.dumps({'ready':True,'pid':os.getpid(),'port':args.port}),flush=True)
    server.serve_forever(poll_interval=.1)
print('preview_server_stopped',flush=True)
