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
# The header banner is deliberately not the captured one: the rebuild drops the old
# domain from it. Pointing the capture at the replacement keeps the rest comparable
# instead of leaving a banner-shaped difference on every page.
BANNER = re.compile(rb'(?:\.\./)*/?images/testpubFINAL3_edited\.png')
# The same repair lib/ofpr/links.rb makes to the stored articles: the dead download
# host becomes the live one and the mirror pointer that then duplicates it goes. The
# rule lives in the Ruby; this mirrors it so the comparison stays about the layout.
DEAD_HOST = re.compile(rb'https?://ftp\.armedassault\.info/', re.I)
INSECURE_HOST = re.compile(rb'http://files\.ofpisnotdead\.com/', re.I)
ANCHOR = re.compile(rb'<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>', re.I | re.S)
POINTER = re.compile(rb'\b(?:ftp|mirror)\s*#?\s*\d\b', re.I)
EMPTY_SMALL = re.compile(rb'(?:&nbsp;|\s)*<small>\s*</small>', re.I)
EMPTY_WRAPPER = re.compile(rb'<(small|center|b)>\s*</\1>', re.I)
DANGLING_OR = re.compile(rb'\s+or\b\s*(?=</)', re.I)
TAGS = re.compile(rb'<[^>]*>')


# The Ruby repairs one article at a time, so a file linked by two articles on a
# listing page is not a duplicate. Splitting on the item bodies keeps that scope.
BODY_START = re.compile(rb'(?=<div class="item(?:Intro|Full)Text">)')


def repair_links(html):
    html = INSECURE_HOST.sub(b'https://files.ofpisnotdead.com/',
                             DEAD_HOST.sub(b'https://files.ofpisnotdead.com/files/', html))
    return b''.join(dedupe(part) for part in BODY_START.split(html))


def dedupe(html):
    seen = {}
    for href, _ in ANCHOR.findall(html):
        seen[href] = seen.get(href, 0) + 1
    if not any(n > 1 for n in seen.values()):
        return html

    kept = {}

    def drop(match):
        href, label = match.group(1), match.group(2)
        words = TAGS.sub(b'', label).replace(b'&nbsp;', b' ').strip()
        if seen.get(href, 0) < 2 or not words or not POINTER.search(words):
            return match.group(0)
        kept[href] = kept.get(href, 0) + 1
        return match.group(0) if kept[href] == seen[href] else b''

    html = ANCHOR.sub(drop, html)
    for _ in range(4):
        tidied = DANGLING_OR.sub(b'', EMPTY_WRAPPER.sub(b'', EMPTY_SMALL.sub(b'', html)))
        if tidied == html:
            break
        html = tidied
    return html
PUBLIC = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'public'))


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        rel = urllib.parse.unquote(self.path.split('?', 1)[0]).lstrip('/')
        full = os.path.join(ROOT, rel)
        if rel.endswith('.html') and os.path.isfile(full):
            body = SCRIPT.sub(b'', LINK.sub(b'', open(full, 'rb').read()))
            body = BANNER.sub(b'/images/banner.jpg', HOST.sub(rb'\1="/', body))
            body = repair_links(body)
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        # An asset the rebuild adds has no counterpart in the mirror.
        if not os.path.isfile(full) and os.path.isfile(os.path.join(PUBLIC, rel)):
            self.directory = PUBLIC
        super().do_GET()


if __name__ == '__main__':
    http.server.ThreadingHTTPServer(
        ('127.0.0.1', int(sys.argv[1])),
        functools.partial(Handler, directory=ROOT)).serve_forever()
