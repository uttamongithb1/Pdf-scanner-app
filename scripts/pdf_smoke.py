#!/usr/bin/env python3
"""Verify the ACTUAL Kotlin writer with synthetic images and an independent PDF reader.
Requires kotlinc, java, Pillow and PyMuPDF (test-only, never bundled with app).
Set KOTLINC/JAVA to absolute executable paths if not on PATH.
"""
from pathlib import Path
import os
import subprocess
import tempfile
from PIL import Image
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='lumen-pdf-') as directory:
    target = Path(directory)
    fixtures = [('red', (220,20,20), (800,1200)), ('green',(20,180,20),(1200,800)), ('blue',(20,20,220),(500,500))]
    for name, colour, size in fixtures:
        Image.new('RGB',size,colour).save(target / f'{name}.jpg',quality=90)
    subprocess.run([os.environ.get('KOTLINC','kotlinc'),
                    str(ROOT / 'android/app/src/main/kotlin/com/lumen/pdfscanner/JpegPdfWriter.kt'),
                    str(ROOT / 'test/native/JpegPdfSmoke.kt'), '-include-runtime', '-d', str(target / 'writer.jar')], check=True)
    subprocess.run([os.environ.get('JAVA','java'), '-jar', str(target / 'writer.jar'), str(target)],check=True)
    pdf = pymupdf.open(target / 'smoke.pdf')
    assert len(pdf) == 3 and not pdf.is_repaired
    assert pdf.metadata['title'] == 'विद्यालय — Invoice'
    for index,(width,height,dominant) in enumerate([(595.28,841.89,0),(792,612,1),(180,180,2)]):
        page=pdf[index]
        assert abs(page.rect.width-width)<.01 and abs(page.rect.height-height)<.01
        pix=page.get_pixmap(matrix=pymupdf.Matrix(.2,.2))
        colour=pix.pixel(pix.width//2,pix.height//2)
        assert colour[dominant] > max(v for i,v in enumerate(colour) if i!=dominant)+100
    raw=(target/'smoke.pdf').read_bytes()
    xref=int(raw.split(b'startxref\n')[-1].splitlines()[0])
    assert raw[xref:xref+4] == b'xref'
    rows=raw[xref:].splitlines(); count=int(rows[1].split()[1])
    assert count == 13
    for object_id,line in enumerate(rows[3:3+count-1],1):
        offset=int(line[:10])
        assert raw[offset:].startswith(f'{object_id} 0 obj'.encode())
    fifty = pymupdf.open(target/'fifty.pdf')
    assert len(fifty) == 50 and not fifty.is_repaired
    assert fifty[49].get_pixmap(matrix=pymupdf.Matrix(.1,.1)).width > 0
    assert b'%%EOF' not in (target/'incomplete.part').read_bytes()
    print('PASS: actual Kotlin PDF writer compiled; Unicode title, geometry, page order/rendering, xref offsets, fifty-page output and incomplete-job checks.')
