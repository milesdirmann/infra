#!/usr/bin/env python3
"""generate.py <in_json> <out_html> -- render the projects overview page."""
import json, sys, html, datetime

def human_bytes(n):
    n = float(n)
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1000:
            return f"{n:.0f} {unit}"
        n /= 1000
    return f"{n:.0f} TB"

DOT = {"go": "go", "hold": "hold", "stop": "stop"}

def row(p):
    warns = []
    if p["error"]:
        warns.append("scan error")
    if not p["managed"]:
        warns.append("unmanaged")
    if p["over_budget"]:
        warns.append("over budget")
    if p["database"] != "none" and p["dump_age_hours"] > 26:
        warns.append("stale dump")
    if p["managed"] and p["status_age_days"] > 30:
        warns.append("status stale")
    state = "go"
    if warns:
        state = "stop" if ("scan error" in warns or "over budget" in warns) else "hold"
    cls = DOT[state]
    name = html.escape(p["name"])
    facts = []
    if p["managed"]:
        facts.append(f"{p['dirty']} dirty" if p["dirty"] else "clean")
        if p["unpushed"]:
            facts.append(f"{p['unpushed']} unpushed")
        facts.append(f"status {p['status_age_days']}d")
    else:
        facts.append("no AGENTS.md")
    facts.append(human_bytes(p["hot_bytes"]))
    if p["deploy"] == "srv":
        facts.append(f"svc {html.escape(p['service_state'])}")
    warn_html = f' <span class="warn-tag">{html.escape(", ".join(warns))}</span>' if warns else ""
    return (f'<tr><td><span class="dot {cls}"></span><b>{name}</b>{warn_html}</td>'
            f'<td class="m">{html.escape(" · ".join(facts))}</td></tr>')

def main():
    data = json.load(open(sys.argv[1]))
    data.sort(key=lambda p: (not p["managed"], p["name"]))
    today = datetime.date.today().isoformat()
    rows = "\n".join(row(p) for p in data)
    out = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PROJECTS / Source of Truth</title>
<link rel="stylesheet" href="../brand/os.css">
<style>.warn-tag{{font-family:var(--mono);font-size:10px;color:var(--hold);margin-left:8px}}</style>
</head><body><div class="wrap">
<header><div class="mast-top">
<span class="eyebrow">Personal OS / Projects 002</span>
<span class="eyebrow">generated hourly</span></div>
<h1>Projects</h1>
<p class="mast-sub">Every project on the server, with facts that cannot lie.
Generated from a scan, not hand maintained. Last generated {today}.</p></header>
<section><div class="sec-head"><h2>All projects</h2>
<span class="eyebrow">PRJ / live scan</span></div>
<table><thead><tr><th>Project</th><th>State</th></tr></thead>
<tbody>
{rows}
</tbody></table></section>
<footer><span>Personal OS · milesdirmann/infra</span>
<span>regenerated each hour on the CX33</span></footer>
</div></body></html>"""
    open(sys.argv[2], "w").write(out)

if __name__ == "__main__":
    main()
