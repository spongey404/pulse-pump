#!/usr/bin/env python3
"""Builds review/REPORT.md from the crawl's audit-*.jsonl files and review/static-findings.json (hand-checked findings).

usage: bin/review-report.py [review-dir]
"""
import glob, json, os, sys, collections

d = sys.argv[1] if len(sys.argv) > 1 else "review"
screens, entries = [], []
for f in sorted(glob.glob(f"{d}/audit-*-light.jsonl")):
    state = os.path.basename(f)[len("audit-"):-len("-light.jsonl")]
    for line in open(f):
        line = line.strip()
        if not line: continue
        o = json.loads(line); o["state"] = state
        (screens if o["type"] == "screen" else entries).append(o)

static = []
sf = f"{d}/static-findings.json"
if os.path.exists(sf): static = json.load(open(sf))
notes = []
nf = f"{d}/unsure.json"
if os.path.exists(nf): notes = json.load(open(nf))

PRIMARY = ("start", "continue", "post", "log", "finish", "save", "create", "add", "sign", "done", "open", "back")
def severity(e):
    s = e["status"]
    if s == "UNVERIFIED": return "Unverified"
    if s in ("TRAP",): return "Blocking"
    if s == "DEAD END":
        text = (e["element"] + " " + e["id"]).lower()
        return "Blocking" if any(p in text for p in PRIMARY) else "Visible"
    if s in ("PLACEHOLDER", "INCONSISTENT", "OFF-SYSTEM"): return "Visible"
    if s == "FAKE AFFORDANCE": return "Minor"
    return None

flags = []
for e in entries:
    sev = severity(e)
    if sev: flags.append((sev, e["status"], f'{e["state"]} · {e["screen"]}', e["element"], e["note"] or e["destination"], e.get("shot", "")))
for s in static: flags.append((s["severity"], s["status"], s["where"], s["what"], s["note"], s.get("shot", "")))
order = {"Blocking": 0, "Visible": 1, "Minor": 2, "Unverified": 3}
flags.sort(key=lambda x: (order[x[0]], x[1], x[2]))

out = ["# Ore design review", ""]
out.append(f"Second review. Screens crawled: {len(screens)} · elements tapped or skipped: {len(entries)} · states: {', '.join(sorted({s['state'] for s in screens}))}")
out.append("")
out.append("Statuses: OK · DEAD END (tap does nothing) · PLACEHOLDER (blank / coming soon) · FAKE AFFORDANCE (looks tappable, isn't) · TRAP (no way back) · INCONSISTENT (contradicts another screen) · OFF-SYSTEM (breaks the design rules) · UNVERIFIED (the crawl flagged it, not confirmed) · SKIPPED (not tapped on purpose: ends the session, deletes, spends, posts or leaves the app).")
out.append("")
ff = f"{d}/fixes.md"
if os.path.exists(ff): out.append(open(ff).read())
out.append("## Flags")
if not flags: out.append("\nNone.")
for sev in ("Blocking", "Visible", "Minor", "Unverified"):
    group = [f for f in flags if f[0] == sev]
    out.append(f"\n### {sev} ({len(group)})\n")
    if sev == "Unverified": out.append("Flags the tap crawl raised that no one has confirmed by hand. The crawl cannot tell a control that changes the page in place from one that does nothing, so treat these as leads, not findings.\n")
    if not group: out.append("None."); continue
    out.append("| status | where | element | note | screenshot |"); out.append("|---|---|---|---|---|")
    for _, st, where, what, note, shot in group:
        out.append(f"| {st} | {where} | {what} | {note} | {shot} |")

out.append("\n## Screen map\n")
by_parent = collections.defaultdict(list)
for s in screens: by_parent[(s["state"], s["parent"])].append(s)
def tree(state, key, depth):
    for s in by_parent.get((state, key), []):
        out.append("  " * depth + f'- **{s["title"]}** `{s["key"]}` — via “{s["via"]}” — {s["shot"]}')
        tree(state, s["key"], depth + 1)
for state in sorted({s["state"] for s in screens}):
    out.append(f"\n### {state}\n")
    tree(state, "", 0)

out.append("\n## Tap audit by screen\n")
per = collections.OrderedDict()
for e in entries: per.setdefault((e["state"], e["screen"]), []).append(e)
shots = {(s["state"], s["key"]): s["shot"] for s in screens}
for (state, key), es in per.items():
    out.append(f"\n### {state} · `{key}`" + (f" — {shots.get((state, key), '')}" if shots.get((state, key)) else "") + "\n")
    out.append("| element | action | destination | status | screenshot |"); out.append("|---|---|---|---|---|")
    for e in es:
        action = "tap" if e["status"] != "SKIPPED" else "—"
        out.append(f'| {e["element"].replace("|", "/")} ({e["kind"]}) | {action} | {e["destination"] or e["note"]} | {e["status"]} | {e.get("shot", "")} |')

out.append("\n## Not sure how to build — the choice made\n")
for n in notes: out.append(f"- **{n['what']}** — {n['choice']}")
if not notes: out.append("None recorded.")
open(f"{d}/REPORT.md", "w").write("\n".join(out) + "\n")
print(f"wrote {d}/REPORT.md ({len(flags)} flags)")
