"""Serve the captured mirror so a browser can render it.

The captures link their assets relatively, so each page has to be served at the path it
had in the mirror or its stylesheets do not resolve. The cookie notice is stripped,
because the app renders with it off by default.

    python3 script/reference_server.py 9500 [mirror-path]
"""

import functools
import http.server
import os
import re
import sys
import urllib.parse

ROOT = os.path.abspath(sys.argv[2] if len(sys.argv) > 2
                       else '../ofp-archive-catalog/ofpr-mirror')
LINK = re.compile(rb'<link[^>]*fmalertcookies[^>]*>')
# Some pages were mirrored with the site's own host written into their urls. That host
# answers nothing now, so a browser shows a hole where the original showed the image.
# The app strips it too, so taking it off here compares like with like.
HOST = re.compile(rb'(src|href)="https?://(?:ofpr\.info\.paradoxstudio\.uk|test\.ofpr\.info)/',
                  re.I)
SCRIPT = re.compile(
    rb'<script type="text/javascript">var d = new Date\(\);var acceptCookie.*?</script>',
    re.S)


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        rel = urllib.parse.unquote(self.path.split('?', 1)[0]).lstrip('/')
        full = os.path.join(ROOT, rel)
        if rel.endswith('.html') and os.path.isfile(full):
            body = SCRIPT.sub(b'', LINK.sub(b'', open(full, 'rb').read()))
            body = HOST.sub(rb'\1="/', body)
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()


if __name__ == '__main__':
    http.server.ThreadingHTTPServer(
        ('127.0.0.1', int(sys.argv[1])),
        functools.partial(Handler, directory=ROOT)).serve_forever()
