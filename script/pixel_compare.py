"""Render one page of each type twice and compare the pixels.

`rake compare` diffs the tag, class and id skeleton, which cannot see text, colour or
position. This renders the capture and the app in the same browser at the same size and
counts the pixels that differ. It needs Chrome, Pillow and numpy, and both servers:

    python3 script/reference_server.py 9500 &
    CONSENT= bundle exec puma -p 9292 &
    python3 script/pixel_compare.py [out-dir]
"""

import os
import subprocess
import sys

import numpy as np
from PIL import Image

OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else 'tmp/pixels')
REF = os.environ.get('REF_BASE', 'http://127.0.0.1:9500')
APP = os.environ.get('BASE', 'http://127.0.0.1:9292')
SIZE = os.environ.get('SIZE', '1280,1500')
PAIRS = [
    ('river', '/index.html', '/'),
    ('river-paged', '/index.html%3Fstart=40.html', '/?start=40'),
    ('index-php', '/index.php.html', '/index.php'),
    ('article-root', '/2510-xmas-gift-from-bis.html', '/2510-xmas-gift-from-bis'),
    ('article-mid', '/utilities/276-campedit1-0.html', '/utilities/276-campedit1-0'),
    ('article-deep', '/addons/aircrafts/2232-franze-s-f-a-18e-f.html',
     '/addons/aircrafts/2232-franze-s-f-a-18e-f'),
    ('section', '/addons/boats.html', '/addons/boats'),
    ('section-paged', '/addons/boats.html%3Fstart=10.html', '/addons/boats?start=10'),
    ('menu-list', '/patches.html', '/patches'),
    ('menu-list-paged', '/patches.html%3Fstart=10.html', '/patches?start=10'),
    ('search-empty', '/search.html', '/search'),
    ('search-results',
     '/search.html%3Fsearchword=martin&ordering=newest&searchphrase=all.html',
     '/search?searchword=martin&ordering=newest&searchphrase=all'),
    ('menu-page', '/mods.html', '/mods'),
]
# Antialiasing moves a channel by a point or two without moving anything visible.
TOLERANCE = 8


def shot(url, out):
    if os.path.exists(out):
        os.remove(out)
    subprocess.run(['google-chrome', '--headless=new', '--disable-gpu', '--no-sandbox',
                    f'--user-data-dir={OUT}/chrome', '--virtual-time-budget=9000',
                    f'--window-size={SIZE}', f'--screenshot={out}', url],
                   capture_output=True, timeout=180)


def main():
    os.makedirs(OUT, exist_ok=True)
    print('%-18s %10s %9s  %s' % ('page type', 'diff px', 'of total', 'verdict'))
    worst, failed = [], 0
    for key, ref, app in PAIRS:
        a, b = f'{OUT}/{key}-ref.png', f'{OUT}/{key}-app.png'
        shot(REF + ref, a)
        shot(APP + app, b)
        if not (os.path.exists(a) and os.path.exists(b)):
            print('%-18s %10s' % (key, 'NO SHOT'))
            failed += 1
            continue
        ia, ib = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
        if ia.size != ib.size:
            print('%-18s size %s vs %s' % (key, ia.size, ib.size))
            failed += 1
            continue
        d = np.abs(np.asarray(ia, np.int16) - np.asarray(ib, np.int16)).max(axis=2)
        n = int((d > TOLERANCE).sum())
        print('%-18s %10d %9d  %s' % (key, n, d.size, 'IDENTICAL' if n == 0
                                      else '%.3f%% differ' % (100.0 * n / d.size)))
        if n:
            worst.append((n, key, d))
    for n, key, d in sorted(worst, reverse=True):
        ys, xs = np.where(d > TOLERANCE)
        print('  %-16s rows %d-%d, cols %d-%d' % (key, ys.min(), ys.max(), xs.min(), xs.max()))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
