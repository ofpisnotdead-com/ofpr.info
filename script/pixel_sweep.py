"""Pixel-compare many pages of every type, not one of each.

`script/pixel_compare.py` checks one page per type. This walks the mirror and samples
N of each, so a defect that only shows on some content cannot hide. Same requirements:
Chrome, Pillow, numpy, and both servers running.

    python3 script/pixel_sweep.py [per-type] [out-dir]
"""

import glob
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

MIRROR = os.environ.get('MIRROR', '../ofp-archive-catalog/ofpr-mirror')
REF = os.environ.get('REF_BASE', 'http://127.0.0.1:9500')
# The facsimile, which is what the capture is compared with.
APP = os.environ.get('BASE', 'http://127.0.0.1:9292') + '/archive'
SIZE = os.environ.get('SIZE', '1280,1500')
PER = int(sys.argv[1]) if len(sys.argv) > 1 else 6
OUT = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'tmp/sweep')
TOLERANCE = 8


def spread(items, n):
    items = sorted(items)
    if len(items) <= n:
        return items
    step = len(items) / float(n)
    return [items[int(i * step)] for i in range(n)]


def app_url(rel):
    path, _, query = rel.partition('?')
    path = path[:-len('.html')] if path.endswith('.html') else path
    if path == 'index':
        path = ''
    query = query[:-len('.html')] if query.endswith('.html') else query
    return '/' + path + ('?' + query if query else '')


def collect():
    root = os.path.abspath(MIRROR)
    def rel(p):
        return os.path.relpath(p, root)

    def usable(paths):
        return [rel(p) for p in paths if '/_source/' not in p]
    groups = {
        'river': spread(usable([p for p in glob.glob(f'{root}/index.html?start=*.html')
                       if 'newlang' not in p]), PER),
        'section': spread(usable([p for p in glob.glob(f'{root}/addons/*.html')
                       + glob.glob(f'{root}/missions/*.html') if '?' not in p]), PER),
        'section-paged': spread(usable(glob.glob(f'{root}/addons/*.html?start=*.html')
                       + glob.glob(f'{root}/missions/*.html?start=*.html')), PER),
        'article-root': spread(usable([p for p in glob.glob(f'{root}/[0-9]*-*.html') if '?' not in p]), PER),
        'article-deep': spread(usable(glob.glob(f'{root}/*/*/[0-9]*-*.html')), PER),
        'article-mid': spread(usable(glob.glob(f'{root}/*/[0-9]*-*.html')), PER),
        'search': spread(usable(glob.glob(f'{root}/search.html?*.html')), PER),
    }
    return groups


def shot(url, out):
    if os.path.exists(out):
        os.remove(out)
    subprocess.run(['google-chrome', '--headless=new', '--disable-gpu', '--no-sandbox',
                    f'--user-data-dir={OUT}/chrome', '--virtual-time-budget=9000',
                    f'--window-size={SIZE}', f'--screenshot={out}', url],
                   capture_output=True, timeout=180)


def main():
    os.makedirs(OUT, exist_ok=True)
    totals = {}
    offenders = []
    for kind, pages in collect().items():
        same = differ = 0
        for i, rel in enumerate(pages):
            a, b = f'{OUT}/{kind}-{i}-ref.png', f'{OUT}/{kind}-{i}-app.png'
            shot(REF + '/' + rel.replace('?', '%3F'), a)
            shot(APP + app_url(rel), b)
            if not (os.path.exists(a) and os.path.exists(b)):
                differ += 1
                offenders.append((kind, rel, 'no shot'))
                continue
            ia, ib = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
            if ia.size != ib.size:
                differ += 1
                offenders.append((kind, rel, 'size'))
                continue
            d = np.abs(np.asarray(ia, np.int16) - np.asarray(ib, np.int16)).max(axis=2)
            n = int((d > TOLERANCE).sum())
            if n:
                differ += 1
                offenders.append((kind, rel, f'{n} px'))
            else:
                same += 1
        totals[kind] = (same, differ)
        print('%-16s %2d identical, %2d differ' % (kind, same, differ))
    print('total: %d identical, %d differ' % (sum(s for s, _ in totals.values()),
                                              sum(d for _, d in totals.values())))
    for kind, rel, why in offenders:
        print('  %-16s %-56s %s' % (kind, rel, why))
    return 0


if __name__ == '__main__':
    sys.exit(main())
