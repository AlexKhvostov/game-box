"""Local static preview with the same bounded byte ranges as production nginx."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re, argparse
p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8768);p.add_argument('--directory',default='telegram-web/landing');a=p.parse_args()
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kw):super().__init__(*args,directory=a.directory,**kw)
    def send_head(self):
        self.byte_range=None
        match=re.fullmatch(r'bytes=(\d+)-(\d+)',self.headers.get('Range',''))
        path=Path(self.translate_path(self.path))
        if match and path.is_file():
            start,end=map(int,match.groups());length=path.stat().st_size
            if not 0<=start<=end<length:self.send_error(416);return
            self.send_response(206);self.send_header('Content-Type',self.guess_type(str(path)))
            self.send_header('Content-Length',end-start+1);self.send_header('Content-Range',f'bytes {start}-{end}/{length}')
            self.end_headers();self.byte_range=(start,end);return path.open('rb')
        return super().send_head()
    def copyfile(self,source,output):
        if self.byte_range:
            start,end=self.byte_range;source.seek(start);output.write(source.read(end-start+1))
        else:super().copyfile(source,output)
ThreadingHTTPServer(('127.0.0.1',a.port),Handler).serve_forever()
