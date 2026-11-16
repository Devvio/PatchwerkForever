"""An addon's README.md as the HTML that CurseForge's description editor keeps.

    python cf_html.py            every project's README: converts it and checks the result
    python cf_html.py <folder>   prints one addon's description as HTML

Why: a description put into CurseForge as Markdown comes out with its paragraphs run together (the
headings, tables and lists are kept, the paragraph breaks are not). As HTML, with every paragraph in
its own <p>, it is shown as written. release.py writes this beside each zip as
CurseForge-description.html.

It reads only what the READMEs here use: headings, paragraphs, bullet and numbered lists, tables,
fenced code, a rule, and bold, italic, code and links inside a line. The first heading (the addon's
name) is left out: CurseForge shows the project's name above the description itself.
"""
import html
import os
import re
import sys
from html.parser import HTMLParser

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.join(HERE, "..", "addons")


def inline(text):
    """One line's worth of text: code, links, bold and italic."""
    codes = []

    def keep(m):
        codes.append("<code>%s</code>" % html.escape(m.group(1), quote=False))
        return "\x00%d\x00" % (len(codes) - 1)

    s = re.sub(r"`([^`]*)`", keep, text)
    s = html.escape(s, quote=False)
    s = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)",
               lambda m: '<a href="%s">%s</a>' % (m.group(2).replace('"', "%22"), m.group(1)), s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", s)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], s)


def cells(row):
    """A table row's cells. A | inside `code` is part of the cell."""
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|"):
        row = row[:-1]
    out, cell, code = [], "", False
    for ch in row:
        if ch == "`":
            code = not code
        if ch == "|" and not code:
            out.append(cell.strip())
            cell = ""
        else:
            cell += ch
    out.append(cell.strip())
    return out


def to_html(text):
    lines = text.replace("\r\n", "\n").split("\n")
    out = []
    i = 0
    first_heading = True
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
        elif line.startswith("```"):
            body = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                body.append(lines[i])
                i += 1
            i += 1
            out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(body), quote=False))
        elif re.match(r"#{1,6} ", line):
            level = len(line.split(" ", 1)[0])
            i += 1
            if level == 1 and first_heading:
                first_heading = False
                continue
            first_heading = False
            out.append("<h%d>%s</h%d>" % (level, inline(line[level + 1:].strip()), level))
        elif re.match(r"(-{3,}|\*{3,})\s*$", line):
            out.append("<hr>")
            i += 1
        elif line.startswith("|") and i + 1 < len(lines) and re.match(r"\|[\s:|-]+\|\s*$", lines[i + 1]):
            head = cells(line)
            i += 2
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            table = ["<table>", "<thead>", "<tr>" + "".join("<th>%s</th>" % inline(c) for c in head) + "</tr>", "</thead>", "<tbody>"]
            table += ["<tr>" + "".join("<td>%s</td>" % inline(c) for c in row) + "</tr>" for row in rows]
            out.append("\n".join(table + ["</tbody>", "</table>"]))
        elif re.match(r"([-*]|\d+\.) ", line):
            tag = "ol" if line[0].isdigit() else "ul"
            mark = r"\d+\. " if tag == "ol" else r"[-*] "
            items = []
            while i < len(lines) and (re.match(mark, lines[i]) or (items and lines[i].startswith("  ") and lines[i].strip())):
                if re.match(mark, lines[i]):
                    items.append(re.sub("^" + mark, "", lines[i]).strip())
                else:
                    items[-1] += " " + lines[i].strip()            # (an item carried on to the next line)
                i += 1
            out.append("<%s>\n%s\n</%s>" % (tag, "\n".join("<li>%s</li>" % inline(item) for item in items), tag))
        else:
            para = []
            while i < len(lines) and lines[i].strip() and not re.match(r"(#{1,6} |```|\||([-*]|\d+\.) |(-{3,}|\*{3,})\s*$)", lines[i]):
                para.append(lines[i].strip())
                i += 1
            out.append("<p>%s</p>" % inline(" ".join(para)))
    return "\n".join(out) + "\n"


class Count(HTMLParser):
    """What a description holds, tag by tag, and whether every tag that opens is closed in order."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.open, self.seen, self.text, self.wrong = [], {}, [], []

    def handle_starttag(self, tag, attrs):
        self.seen[tag] = self.seen.get(tag, 0) + 1
        if tag != "hr":
            self.open.append(tag)

    def handle_endtag(self, tag):
        if not self.open or self.open.pop() != tag:
            self.wrong.append(tag)

    def handle_data(self, data):
        if "code" not in self.open:
            self.text.append(data)


def check(text, page):
    """Compares a README with its HTML: the same number of each thing, nothing of Markdown left over."""
    md = re.sub(r"```.*?```", "", text.replace("\r\n", "\n"), flags=re.S)
    c = Count()
    c.feed(page)
    plain = "".join(c.text)
    wrong = []
    if c.open or c.wrong:
        wrong.append("tags not closed in order: %s %s" % (c.open, c.wrong))
    want = {
        "h2": len(re.findall(r"^## ", md, re.M)), "h3": len(re.findall(r"^### ", md, re.M)),
        "li": len(re.findall(r"^([-*]|\d+\.) ", md, re.M)),
        "tr": len(re.findall(r"^\|", md, re.M)) - len(re.findall(r"^\|[\s:|-]+\|\s*$", md, re.M)),
        "hr": len(re.findall(r"^-{3,}\s*$", md, re.M)), "pre": text.count("```") // 2,
        "a": len(re.findall(r"\[[^\]]+\]\(https?://", md)),
    }
    for tag, n in want.items():
        if c.seen.get(tag, 0) != n:
            wrong.append("%d <%s>, the README has %d" % (c.seen.get(tag, 0), tag, n))
    if not c.seen.get("p"):
        wrong.append("no paragraphs")
    for left in ("**", "`", "](", "\x00"):
        if left in plain:
            wrong.append("Markdown left in the text: %r near %r" % (left, plain[max(0, plain.index(left) - 30):plain.index(left) + 30]))
    if re.search(r"(^|\s)\*\S|\S\*(\s|$)", plain):
        wrong.append("a * left in the text")
    return wrong, c.seen


def main():
    if len(sys.argv) > 1:
        with open(os.path.join(ADDONS, sys.argv[1], "README.md"), encoding="utf-8") as f:
            sys.stdout.reconfigure(encoding="utf-8")
            sys.stdout.write(to_html(f.read()))
        return 0
    from release import PROJECTS
    bad = 0
    for key in sorted(PROJECTS):
        folder = PROJECTS[key]["main"]
        with open(os.path.join(ADDONS, folder, "README.md"), encoding="utf-8") as f:
            text = f.read()
        page = to_html(text)
        wrong, seen = check(text, page)
        print("%-40s %5d chars: %s" % (folder, len(page), ", ".join("%d %s" % (seen[t], t) for t in ("p", "h2", "li", "tr", "a") if seen.get(t))))
        for w in wrong:
            bad += 1
            print("  WRONG: " + w)
    print("all descriptions convert cleanly" if not bad else "%d problem(s)" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
