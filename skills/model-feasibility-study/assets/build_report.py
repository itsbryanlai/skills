#!/usr/bin/env python3
"""
build_report.py -- render a feasibility study's docs/ into one self-contained
report.html: sidebar nav, inlined figures, print stylesheet, zero dependencies.

Usage:
    python3 build_report.py [STUDY_ROOT] [-o OUTPUT]

Reads, relative to STUDY_ROOT (default: the current directory):

    docs/*.md                          one section per file, ordered by filename
    docs/superseded/*.md               grouped separately at the end of the nav
    docs/figures/*                     inlined as base64 -- output is one file
    experiments/results/metrics.json   substituted into {{dotted.key}} in prose

Two build-time guards, both deliberate:

  * every {{key}} in the docs must resolve against metrics.json, or the build
    fails and names the key. This is what stops a hand-typed headline number
    from drifting away from the generated one.
  * the decision-maker doc (00-*) is warned about past WORD_CAP words. It is
    the one doc that gets read; if it needs a scroll bar it has stopped being
    a summary.

The Markdown subset is the one a study doc actually uses: headings, paragraphs,
lists, tables, fenced code, blockquotes, rules, images, links, bold, italic and
inline code. A literal '|' inside an inline-code span will break a table row --
escape it or restructure the cell.

An image takes both an alt text and a title:

    ![Accuracy against text length, one line per detector.](f.png "Every
    detector collapses below 30 characters; fastText collapses least.")

The alt describes the chart for a screen reader, the title is the visible
caption and states the takeaway. A figure with no title still renders, using
the alt as its caption, and the build warns.
"""

import argparse
import base64
import html
import json
import mimetypes
import re
import sys
from pathlib import Path

WORD_CAP = 900  # the decision-maker doc; roughly two screens

# --------------------------------------------------------------------------
# inline markdown


def inline(text, ctx):
    spans = []

    def stash(m):
        spans.append(m.group(1))
        return "\x00%d\x00" % (len(spans) - 1)

    text = re.sub(r"`([^`]+)`", stash, text)
    text = html.escape(text, quote=False)
    text = re.sub(r'!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)',
                  lambda m: ctx.image(m.group(1), m.group(2), m.group(3)), text)
    text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
                  lambda m: ctx.link(m.group(1), m.group(2)), text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"\x00(\d+)\x00",
                  lambda m: "<code>%s</code>" % html.escape(spans[int(m.group(1))]), text)
    return text


# --------------------------------------------------------------------------
# block markdown

LIST_RE = re.compile(r"^(\s*)([-*+]|\d+\.)\s+(.*)$")
STOP_RE = re.compile(r"^(#{1,6}\s|```|>|\s*([-*+]|\d+\.)\s)")


def render(md, ctx):
    lines = md.split("\n")
    out, i, n = [], 0, len(lines)
    while i < n:
        line = lines[i]
        if not line.strip():
            i += 1
            continue

        if line.startswith("```"):
            i += 1
            buf = []
            while i < n and not lines[i].startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1
            out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(buf)))
            continue

        m = re.match(r"(#{1,6})\s+(.*)", line)
        if m:
            lvl = len(m.group(1))
            out.append("<h%d>%s</h%d>" % (lvl, inline(m.group(2), ctx), lvl))
            i += 1
            continue

        if re.fullmatch(r"-{3,}|\*{3,}|_{3,}", line.strip()):
            out.append("<hr>")
            i += 1
            continue

        if line.lstrip().startswith("|") and i + 1 < n and \
                re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            i, block = table(lines, i, ctx)
            out.append(block)
            continue

        if line.startswith(">"):
            buf = []
            while i < n and lines[i].startswith(">"):
                buf.append(lines[i][1:].lstrip())
                i += 1
            out.append("<blockquote>%s</blockquote>" % render("\n".join(buf), ctx))
            continue

        if LIST_RE.match(line):
            i, block = listblock(lines, i, ctx)
            out.append(block)
            continue

        buf = []
        while i < n and lines[i].strip() and not STOP_RE.match(lines[i]) \
                and not lines[i].lstrip().startswith("|") \
                and not re.fullmatch(r"-{3,}|\*{3,}|_{3,}", lines[i].strip()):
            buf.append(lines[i].strip())
            i += 1
        para = " ".join(buf)
        solo = re.fullmatch(r'!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)',
                            para.strip())
        out.append(ctx.figure(solo.group(1), solo.group(2), solo.group(3)) if solo
                   else "<p>%s</p>" % inline(para, ctx))
    return "\n".join(out)


def table(lines, i, ctx):
    cells = lambda l: [c.strip() for c in l.strip().strip("|").split("|")]
    header = cells(lines[i])
    i += 2
    rows = []
    while i < len(lines) and lines[i].lstrip().startswith("|"):
        rows.append(cells(lines[i]))
        i += 1
    th = "".join("<th>%s</th>" % inline(c, ctx) for c in header)
    body = "".join(
        "<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c, ctx) for c in r)
        for r in rows)
    return i, ('<div class="tw"><table><thead><tr>%s</tr></thead>'
               "<tbody>%s</tbody></table></div>" % (th, body))


def listblock(lines, i, ctx):
    base = len(lines[i]) - len(lines[i].lstrip())
    ordered = bool(re.match(r"^\s*\d+\.\s", lines[i]))
    items = []
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            if nxt.strip() and LIST_RE.match(nxt) and \
                    len(nxt) - len(nxt.lstrip()) >= base:
                i += 1
                continue
            break
        m = LIST_RE.match(line)
        indent = len(line) - len(line.lstrip())
        if m and indent == base:
            items.append([m.group(3)])
            i += 1
            continue
        if indent > base and items:
            items[-1].append(line[base:])
            i += 1
            continue
        break

    out = []
    for parts in items:
        inner = inline(parts[0], ctx)
        if len(parts) > 1:
            inner += render("\n".join(parts[1:]), ctx)
        out.append("<li>%s</li>" % inner)
    tag = "ol" if ordered else "ul"
    return i, "<%s>%s</%s>" % (tag, "".join(out), tag)


# --------------------------------------------------------------------------
# document context: figures, cross-links, metrics


class Ctx:
    def __init__(self, doc_dir, root, anchors, report):
        self.doc_dir = doc_dir
        self.root = root
        self.anchors = anchors
        self.report = report

    def _resolve(self, src):
        p = (self.doc_dir / src).resolve()
        return p if p.exists() else None

    def _data_uri(self, path):
        mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        raw = path.read_bytes()
        self.report["inlined_bytes"] += len(raw)
        return "data:%s;base64,%s" % (mime, base64.b64encode(raw).decode())

    def _img_tag(self, alt, src):
        path = self._resolve(src)
        if path is None:
            self.report["missing_figures"].append(src)
            return '<span class="missing">missing figure: %s</span>' % html.escape(src)
        self.report["figures"] += 1
        return '<img alt="%s" src="%s">' % (html.escape(alt, quote=True),
                                            self._data_uri(path))

    def image(self, alt, src, title=None):
        return self._img_tag(alt, src)

    def figure(self, alt, src, title=None):
        # alt describes the chart for a screen reader; the title is the visible
        # caption and carries the takeaway. They are different jobs -- falling
        # back to alt gives a caption that narrates axes instead of a finding.
        tag = self._img_tag(alt, src)
        caption = title or alt
        if not title:
            self.report["uncaptioned"] += 1
        cap = "<figcaption>%s</figcaption>" % inline(caption, self) if caption else ""
        return "<figure>%s%s</figure>" % (tag, cap)

    def link(self, text, href):
        if re.match(r"^(https?:|mailto:|#)", href):
            ext = ' target="_blank" rel="noopener"' if href.startswith("http") else ""
            return '<a href="%s"%s>%s</a>' % (html.escape(href, quote=True), ext, text)
        path, _, frag = href.partition("#")
        target = (self.doc_dir / path).resolve() if path else None
        if target is not None and target in self.anchors:
            return '<a href="#%s">%s</a>' % (self.anchors[target], text)
        try:
            rel = target.relative_to(self.root) if target else Path(href)
        except ValueError:
            rel = Path(href)
        tail = "#" + frag if frag else ""
        return '<a href="%s%s">%s</a>' % (html.escape(str(rel), quote=True), tail, text)


METRIC_RE = re.compile(r"\{\{([A-Za-z0-9_.\-]+)\}\}")


def apply_metrics(md, metrics, missing, used):
    def sub(m):
        key = m.group(1)
        node = metrics
        for part in key.split("."):
            if isinstance(node, dict) and part in node:
                node = node[part]
            else:
                missing.add(key)
                return m.group(0)
        used.add(key)
        return html.escape(str(node), quote=False) if not isinstance(node, (dict, list)) \
            else m.group(0)
    return METRIC_RE.sub(sub, md)


# --------------------------------------------------------------------------
# assembly

CSS = """
:root{--bg:#fff;--fg:#1a1c1e;--muted:#5c6470;--line:#e3e6ea;--accent:#1f6feb;
--code-bg:#f5f6f8;--side:#fafbfc;--warn:#b42318}
@media(prefers-color-scheme:dark){:root{--bg:#14161a;--fg:#e6e8ea;--muted:#98a1ad;
--line:#2a2f37;--accent:#6aa6ff;--code-bg:#1d2127;--side:#181b20;--warn:#ff8a7a}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
font:16px/1.65 ui-sans-serif,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
-webkit-font-smoothing:antialiased}
.layout{display:flex;align-items:flex-start}
nav{position:sticky;top:0;flex:0 0 270px;height:100vh;overflow-y:auto;
background:var(--side);border-right:1px solid var(--line);padding:28px 20px}
nav .title{font-weight:650;font-size:15px;line-height:1.35;margin-bottom:4px}
nav .sub{font-size:12px;color:var(--muted);margin-bottom:20px}
nav .group{font-size:11px;letter-spacing:.07em;text-transform:uppercase;
color:var(--muted);margin:22px 0 8px}
nav a{display:block;padding:6px 10px;margin:1px -10px;border-radius:6px;
color:var(--muted);text-decoration:none;font-size:13.5px;line-height:1.4}
nav a:hover{color:var(--fg);background:rgba(127,127,127,.09)}
nav a.active{color:var(--accent);background:rgba(127,127,127,.11);font-weight:560}
main{flex:1;min-width:0;padding:56px 48px 25vh;max-width:56rem}
section{scroll-margin-top:24px}
section+section{margin-top:72px;padding-top:56px;border-top:1px solid var(--line)}
h1,h2,h3,h4{line-height:1.25;font-weight:640}
h1{font-size:30px;margin:0 0 24px;letter-spacing:-.015em}
h2{font-size:21px;margin:40px 0 14px;letter-spacing:-.01em}
h3{font-size:17px;margin:30px 0 10px}
h4{font-size:15px;margin:24px 0 8px;color:var(--muted)}
p,li{color:var(--fg)}
p{margin:0 0 15px}
ul,ol{margin:0 0 15px;padding-left:22px}
li{margin:5px 0}
a{color:var(--accent)}
hr{border:0;border-top:1px solid var(--line);margin:32px 0}
blockquote{margin:20px 0;padding:2px 18px;border-left:3px solid var(--line);
color:var(--muted)}
code{background:var(--code-bg);padding:.12em .38em;border-radius:4px;font-size:.87em;
font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
pre{background:var(--code-bg);padding:14px 16px;border-radius:8px;overflow-x:auto;
border:1px solid var(--line)}
pre code{background:none;padding:0;font-size:13px;line-height:1.55}
.tw{overflow-x:auto;margin:0 0 20px}
table{border-collapse:collapse;font-size:14px;width:100%}
th,td{padding:8px 13px;text-align:left;border-bottom:1px solid var(--line);
vertical-align:top}
th{font-weight:600;font-size:12px;letter-spacing:.03em;text-transform:uppercase;
color:var(--muted);border-bottom:1.5px solid var(--line);white-space:nowrap}
tbody tr:hover{background:rgba(127,127,127,.05)}
figure{margin:26px 0;padding:0}
figure img{max-width:100%;height:auto;display:block;border:1px solid var(--line);
border-radius:8px;background:#fff}
figcaption{margin-top:9px;font-size:13px;line-height:1.5;color:var(--muted)}
p img{max-width:100%;height:auto;border-radius:6px}
.missing{color:var(--warn);font-size:13px}
.banner{margin:0 0 24px;padding:11px 15px;border-radius:8px;font-size:14px;
background:rgba(180,35,24,.09);border:1px solid rgba(180,35,24,.3)}
@media(max-width:900px){.layout{display:block}
nav{position:static;height:auto;width:auto;border-right:0;
border-bottom:1px solid var(--line)}
main{padding:32px 20px 15vh}}
@media print{nav{display:none}main{padding:0;max-width:none}
section+section{page-break-before:always;border-top:0}
figure,table,pre{page-break-inside:avoid}a{color:inherit;text-decoration:none}}
"""

JS = """
const links=[...document.querySelectorAll('nav a[data-sec]')];
const map=new Map(links.map(a=>[a.dataset.sec,a]));
const visible=new Set();
const sections=[...document.querySelectorAll('section')];
const io=new IntersectionObserver(entries=>{
  for(const e of entries){e.isIntersecting?visible.add(e.target.id):visible.delete(e.target.id);}
  const current=sections.find(s=>visible.has(s.id));
  links.forEach(a=>a.classList.remove('active'));
  if(current&&map.has(current.id))map.get(current.id).classList.add('active');
},{rootMargin:'-8% 0px -70% 0px'});
sections.forEach(s=>io.observe(s));
"""


def doc_title(md, fallback):
    for line in md.split("\n"):
        if line.startswith("# "):
            return line[2:].strip()
    return fallback


def collect(root):
    docs = root / "docs"
    if not docs.is_dir():
        sys.exit("no docs/ directory under %s" % root)
    main = sorted(p for p in docs.glob("*.md"))
    old = sorted(p for p in (docs / "superseded").glob("*.md")) \
        if (docs / "superseded").is_dir() else []
    if not main and not old:
        sys.exit("no markdown files in %s" % docs)
    return main, old


def build(root, out):
    root = root.resolve()
    main, old = collect(root)
    metrics_path = root / "experiments" / "results" / "metrics.json"
    metrics = json.loads(metrics_path.read_text()) if metrics_path.exists() else {}

    anchors, entries = {}, []
    for path in main + old:
        slug = "doc-" + re.sub(r"[^a-z0-9]+", "-", path.stem.lower()).strip("-")
        anchors[path.resolve()] = slug
        entries.append((path, slug, path in old))

    missing_keys, used_keys = set(), set()
    report = {"figures": 0, "uncaptioned": 0, "inlined_bytes": 0, "missing_figures": []}
    sections, nav_main, nav_old = [], [], []

    for path, slug, superseded in entries:
        md = apply_metrics(path.read_text(), metrics, missing_keys, used_keys)
        md = re.sub(r"\A---\n.*?\n---\n", "", md, flags=re.S)
        title = doc_title(md, path.stem)
        words = len(re.findall(r"\S+", md))
        if path.stem.startswith("00") and not superseded and words > WORD_CAP:
            print("  warn  %s is %d words (cap %d) -- the decision-maker doc "
                  "should fit two screens" % (path.name, words, WORD_CAP),
                  file=sys.stderr)
        ctx = Ctx(path.parent, root, anchors, report)
        banner = ('<div class="banner"><strong>Superseded.</strong> Kept for the '
                  "record; a later section overturns it. Do not quote from here."
                  "</div>") if superseded else ""
        sections.append('<section id="%s">%s%s</section>'
                        % (slug, banner, render(md, ctx)))
        item = '<a href="#%s" data-sec="%s">%s</a>' % (slug, slug, html.escape(title))
        (nav_old if superseded else nav_main).append(item)

    if missing_keys:
        sys.exit("metrics.json does not define: %s\n"
                 "Every {{key}} must resolve -- that is the guard against "
                 "hand-typed numbers drifting." % ", ".join(sorted(missing_keys)))

    readme = root / "README.md"
    site = doc_title(readme.read_text(), root.name) if readme.exists() else root.name

    nav = ['<div class="title">%s</div>' % html.escape(site),
           '<div class="sub">Feasibility study</div>'] + nav_main
    if nav_old:
        nav += ['<div class="group">Superseded</div>'] + nav_old

    out.write_text(
        "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
        "<title>%s</title>\n<style>%s</style>\n</head>\n<body>\n"
        '<div class="layout">\n<nav>%s</nav>\n<main>%s</main>\n</div>\n'
        "<script>%s</script>\n</body>\n</html>\n"
        % (html.escape(site), CSS, "\n".join(nav), "\n".join(sections), JS))

    size = out.stat().st_size / 1e6
    print("wrote %s  (%d sections, %d figures inlined, %.1f MB)"
          % (out, len(sections), report["figures"], size))
    if report["missing_figures"]:
        print("  warn  figures not found: %s"
              % ", ".join(sorted(set(report["missing_figures"]))), file=sys.stderr)
    if report["uncaptioned"]:
        print('  warn  %d figure(s) have no caption -- write it as the title: '
              '![screen-reader description](fig.png "The takeaway sentence.") '
              "The caption states the finding, not the axes."
              % report["uncaptioned"], file=sys.stderr)
    if metrics and not used_keys:
        print("  warn  metrics.json exists but no {{key}} is used in the docs -- "
              "headline numbers are hand-typed and will drift", file=sys.stderr)
    if size > 8:
        print("  warn  %.1f MB is large to email; downsample the figures" % size,
              file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("root", nargs="?", default=".", help="study root (default: .)")
    ap.add_argument("-o", "--output", default=None,
                    help="output file (default: STUDY_ROOT/report.html)")
    args = ap.parse_args()
    root = Path(args.root)
    build(root, Path(args.output) if args.output else root / "report.html")


if __name__ == "__main__":
    main()
