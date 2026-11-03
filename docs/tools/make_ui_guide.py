#!/usr/bin/env python3
"""Convert docs/PANDUAN-APLIKASI-KASIRGO.md into a printable PDF (Bahasa Indonesia).

Usage:
    python3 docs/tools/make_ui_guide.py [OUTPUT_PDF]

Defaults to docs/panduan-aplikasi-kasirgo.pdf.
"""
import os
import re
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, PageBreak,
    Table, TableStyle, HRFlowable, Preformatted, Image,
)

PRIMARY = colors.HexColor('#0284C7')
PRIMARY_DARK = colors.HexColor('#075985')
ACCENT = colors.HexColor('#06B6D4')
INK = colors.HexColor('#0F172A')
MUTED = colors.HexColor('#64748B')
BORDER = colors.HexColor('#E2E8F0')
SOFT = colors.HexColor('#F1F5F9')
GREEN = colors.HexColor('#10B981')
AMBER = colors.HexColor('#F59E0B')

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, os.pardir, 'PANDUAN-APLIKASI-KASIRGO.md')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, os.pardir, 'panduan-aplikasi-kasirgo.pdf')

FONT_DIR = '/usr/share/fonts/truetype/dejavu'
pdfmetrics.registerFont(TTFont('DVSans', os.path.join(FONT_DIR, 'DejaVuSans.ttf')))
pdfmetrics.registerFont(TTFont('DVSans-Bold', os.path.join(FONT_DIR, 'DejaVuSans-Bold.ttf')))
pdfmetrics.registerFont(TTFont('DVMono', os.path.join(FONT_DIR, 'DejaVuSansMono.ttf')))
pdfmetrics.registerFontFamily('DVSans', normal='DVSans', bold='DVSans-Bold',
                              italic='DVSans', boldItalic='DVSans-Bold')


def _escape(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


URL_RE = re.compile(r'https?://[^\s<>\'"]+')


def inline(text):
    text = _escape(text)
    text = URL_RE.sub(lambda m: '<a href="%(u)s" color="#0284C7"><font size="7.5">%(u)s</font></a>' % {'u': m.group(0)}, text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'`([^`]+)`', r'<font face="DVMono" color="#075985">\1</font>', text)
    return text


def code_block(lines):
    rows = []
    for ln in lines:
        cell = _escape(ln).replace(' ', '&nbsp;')
        rows.append(Paragraph(cell if cell else '&nbsp;', S['code']))
    t = Table([[r] for r in rows], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), SOFT),
        ('BOX', (0, 0), (-1, -1), 0.6, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    return t


styles = getSampleStyleSheet()
S = {}
S['body'] = ParagraphStyle('body', parent=styles['BodyText'], fontName='DVSans',
                           fontSize=9.8, leading=15, textColor=INK, spaceAfter=6,
                           alignment=TA_LEFT)
S['h1'] = ParagraphStyle('h1', parent=styles['Heading1'], fontName='DVSans-Bold',
                         fontSize=20, leading=25, textColor=PRIMARY_DARK,
                         spaceBefore=4, spaceAfter=10)
S['h2'] = ParagraphStyle('h2', parent=styles['Heading2'], fontName='DVSans-Bold',
                         fontSize=13, leading=17, textColor=PRIMARY,
                         spaceBefore=12, spaceAfter=6)
S['h3'] = ParagraphStyle('h3', parent=styles['Heading3'], fontName='DVSans-Bold',
                         fontSize=11, leading=15, textColor=INK,
                         spaceBefore=9, spaceAfter=4)
S['step'] = ParagraphStyle('step', parent=S['body'], leftIndent=16, firstLineIndent=-16,
                           spaceAfter=4)
S['note'] = ParagraphStyle('note', parent=S['body'], leftIndent=10, rightIndent=10,
                           fontSize=9, leading=14, textColor=PRIMARY_DARK,
                           backColor=colors.HexColor('#E0F2FE'), borderPadding=6,
                           spaceAfter=8)
S['code'] = ParagraphStyle('code', parent=S['body'], fontName='DVMono', fontSize=8,
                           leading=11.5, spaceAfter=0)
S['cell'] = ParagraphStyle('cell', parent=S['body'], fontSize=8.6, leading=12,
                           spaceAfter=0)
S['cell_h'] = ParagraphStyle('cell_h', parent=S['cell'], fontName='DVSans-Bold',
                             textColor=colors.white)


def footer(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setStrokeColor(BORDER)
    canvas.setLineWidth(0.7)
    canvas.line(20 * mm, 14 * mm, w - 20 * mm, 14 * mm)
    canvas.setFillColor(MUTED)
    canvas.setFont('DVSans', 7.8)
    canvas.drawString(20 * mm, 9.5 * mm, 'KasirGo - Panduan Aplikasi & Struktur UI')
    canvas.drawRightString(w - 20 * mm, 9.5 * mm, 'Halaman %d' % doc.page)
    canvas.restoreState()


def parse(src):
    """Parse markdown blocks into a list of reportlab flowables."""
    with open(src, encoding='utf-8') as f:
        lines = [ln.rstrip('\n') for ln in f]

    story = []
    i = 0
    n = len(lines)
    while i < n:
        ln = lines[i]

        # Blank
        if not ln.strip():
            i += 1
            continue

        # Horizontal rule
        if ln.strip() == '---':
            story.append(Spacer(1, 4))
            story.append(HRFlowable(width='100%', thickness=0.7, color=BORDER,
                                    spaceAfter=8))
            i += 1
            continue

        # Headings
        if ln.startswith('# '):
            story.append(Paragraph(inline(ln[2:]), S['h1']))
            i += 1
            continue
        if ln.startswith('## '):
            story.append(Paragraph(inline(ln[3:]), S['h2']))
            i += 1
            continue
        if ln.startswith('### '):
            story.append(Paragraph(inline(ln[4:]), S['h3']))
            i += 1
            continue

        # Blockquote (note)
        if ln.startswith('> '):
            buf = [ln[2:]]
            j = i + 1
            while j < n and lines[j].startswith('> '):
                buf.append(lines[j][2:])
                j += 1
            story.append(Paragraph(inline(' '.join(buf)), S['note']))
            i = j
            continue

        # Markdown image ![alt](path)
        mimg = re.match(r'^!\[[^\]]*\]\((.+?)\)\s*$', ln)
        if mimg:
            rel = mimg.group(1)
            img_path = os.path.join(os.path.dirname(SRC), rel)
            if os.path.isfile(img_path):
                ir = ImageReader(img_path)
                iw, ih = ir.getSize()
                max_w = 170 * mm
                max_h = 250 * mm
                scale = min(max_w / iw, max_h / ih, 1.0)
                w = iw * scale
                h = ih * scale
                story.append(Image(img_path, width=w, height=h))
                story.append(Spacer(1, 8))
            i += 1
            continue

        # Fenced code block
        if ln.strip().startswith('```'):
            i += 1
            buf = []
            while i < n and not lines[i].strip().startswith('```'):
                buf.append(lines[i])
                i += 1
            i += 1  # skip closing fence
            story.append(code_block(buf))
            story.append(Spacer(1, 5))
            continue

        # Table
        if ln.lstrip().startswith('|'):
            rows = []
            while i < n and lines[i].lstrip().startswith('|'):
                row = lines[i].strip().strip('|').split('|')
                cleaned = [c.strip() for c in row]
                if not all(re.fullmatch(r':?-{2,}:?', c) for c in cleaned):
                    rows.append(cleaned)
                i += 1
            if rows:
                header = [Paragraph(inline(c), S['cell_h']) for c in rows[0]]
                body = [[Paragraph(inline(c), S['cell']) for c in r] for r in rows[1:]]
                table_data = [header] + body
                t = Table(table_data, repeatRows=1, hAlign='LEFT')
                t.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), PRIMARY),
                    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, SOFT]),
                    ('GRID', (0, 0), (-1, -1), 0.5, BORDER),
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ('LEFTPADDING', (0, 0), (-1, -1), 6),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                    ('TOPPADDING', (0, 0), (-1, -1), 4),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ]))
                story.append(t)
                story.append(Spacer(1, 8))
            continue

        # Ordered list item
        m = re.match(r'^(\d+)\.\s+(.*)$', ln)
        if m:
            num = m.group(1)
            buf = [m.group(2)]
            j = i + 1
            while j < n:
                nxt = lines[j]
                if nxt.strip() == '':
                    j += 1
                    continue
                if re.match(r'^(\d+)\.\s+', nxt) or nxt.startswith(('#', '##', '###', '>', '|', '```')) or nxt.strip() == '---':
                    break
                if nxt.startswith(' ') or nxt.startswith('\t'):
                    buf.append(nxt.strip())
                    j += 1
                    continue
                break
            story.append(Paragraph('<b>%s.</b> %s' % (num, inline(' '.join(buf))), S['step']))
            i = j
            continue

        # Regular paragraph (may span until blank or structural line)
        buf = [ln.strip()]
        j = i + 1
        while j < n:
            nxt = lines[j]
            if nxt.strip() == '' or nxt.startswith(('#', '>', '|', '```')) or nxt.strip() == '---' or re.match(r'^(\d+)\.\s+', nxt):
                break
            buf.append(nxt.strip())
            j += 1
        story.append(Paragraph(inline(' '.join(buf)), S['body']))
        i = j

    return story


def main():
    story = parse(SRC)

    doc = BaseDocTemplate(OUT, pagesize=A4,
                          leftMargin=20 * mm, rightMargin=20 * mm,
                          topMargin=20 * mm, bottomMargin=20 * mm,
                          title='KasirGo - Panduan Aplikasi & Struktur UI',
                          author='KasirGo')
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id='f')
    doc.addPageTemplates([PageTemplate(id='p', frames=[frame], onPage=footer)])
    doc.build(story)
    print('OK -> %s (%d bytes)' % (OUT, os.path.getsize(OUT)))


if __name__ == '__main__':
    main()