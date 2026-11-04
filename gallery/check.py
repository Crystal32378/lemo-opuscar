#!/usr/bin/env python3
"""Offline integrity checks: python3 gallery/check.py (not browser QA)."""
from hashlib import sha256
from html.parser import HTMLParser
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent

class References(HTMLParser):
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        for key in ('href', 'src', 'poster'):
            value = attrs.get(key, '')
            if value and not value.startswith(('https://', '#')):
                assert (ROOT / value).is_file(), f'Missing local reference: {value}'
        if tag == 'video':
            assert 'controls' in attrs and 'playsinline' in attrs
            assert 'autoplay' not in attrs, 'Do not autoplay visitor films'

References().feed((ROOT / 'index.html').read_text(encoding='utf-8'))
# every preserved work: its files must match the hashes recorded in its CREDITS.md, and its source ZIP must be intact
WORKS = {
    'murphy-sea-without-water': {
        'Sea-Without-Water.mp4': '2f8b1b968d24aa89f1fc9b9a2d59b43daad08937a4be4134570fcb5e4d9f43cd',
        'Sea-Without-Water-source.zip': '0d9ab74eaacef7922c166b47313faca33a8b1523fd8215bec9a1f10233d91719',
    },
    'opus-one-line': {
        'one-line-pelican.mp4': '4d59abe40bf04aaed2db464c03bb6cdbc48b616d02c8796dcdce888693a11150',
        'one-line-pelican-source.zip': 'f0ea9dcc947713fd4f1a864475c7cf41e684bfe14ff01dc45d250beee883b900',
    },
}
for name, expected in WORKS.items():
    work = ROOT / 'works' / name
    for filename, digest in expected.items():
        assert sha256((work / filename).read_bytes()).hexdigest() == digest, f'{name}/{filename}'
        if filename.endswith('.zip'):
            with ZipFile(work / filename) as source:
                assert source.testzip() is None, f'{name}/{filename}'
print(f'PASS: local references, playback attributes, MP4/ZIP hashes and ZIP integrity for {len(WORKS)} works')
