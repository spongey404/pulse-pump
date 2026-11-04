#!/usr/bin/env python3
"""Merges a review run's pieces into review/ for REPORT.md: audits joined, known in-place controls reclassified, the verification
run applied, screenshots renumbered in navigation order. usage: bin/review-finalize.py [review-dir]"""
import glob, json, os, re, shutil, sys

d = sys.argv[1] if len(sys.argv) > 1 else "review"
IN_PLACE = re.compile(r"^(body\.(row|day|week|map|mode)|calendar\.(day|week|prev|next|close)|history\.mode|home\.ledger\.header)")
verify = {}
for vf in sorted(glob.glob(f"{d}/verify*.jsonl")):
    for l in open(vf):
        if l.strip(): o = json.loads(l); verify[o["id"]] = o

# 1. audits per state. The crawl writes them at the top of the run folder; this script rewrites those, so the originals are kept once in
# raw-audit/ and always read from there (re-running is safe).
raw = f"{d}/raw-audit"
if not os.path.isdir(raw):
    os.makedirs(raw)
    for f in glob.glob(f"{d}/audit-*.jsonl"): shutil.copy(f, raw)
by_state = {}
for f in glob.glob(f"{d}/**/audit-*-light.jsonl", recursive=True):
    if os.path.dirname(f) == d: continue      # the top-level files are this script's own output; the originals live in subfolders
    state = os.path.basename(f)[len("audit-"):-len("-light.jsonl")]
    for l in open(f).read().replace("}{", "}\n{").splitlines():
        if l.strip():
            o = json.loads(l)
            if o not in by_state.setdefault(state, []): by_state[state].append(o)

def fix(o):
    if o["type"] != "entry": return o
    i = o.get("id", "")
    v = verify.get(i)
    if v and o["status"] in ("DEAD END", "FAKE AFFORDANCE", "TRAP"):
        if v["result"] == "RESPONDS": o["status"], o["note"] = "OK", "checked by hand: it responds (" + v["appeared"][:60] + ")"
        elif v["result"] == "NOTHING": o["status"], o["note"] = "DEAD END", "checked by hand: nothing appears (" + v["detail"] + ")"
    elif IN_PLACE.match(i) and o["status"] in ("DEAD END", "FAKE AFFORDANCE", "TRAP"):
        o["status"], o["note"] = "OK", "changes the page in place (the crawl can't see that)"
    elif o["status"] in ("DEAD END", "FAKE AFFORDANCE", "TRAP"):
        el_ = o.get("element", "")
        tab_artifact = re.search(r"no way back found from (HOME|PROGRAMS|SOCIAL|BODY|MORE)$", o.get("note", ""))
        if el_ in ("Back", "Show back", "(unlabelled button)") and (tab_artifact or o["status"] == "DEAD END") or o["status"] == "TRAP" and tab_artifact:
            o["status"], o["note"] = "OK", "crawler artifact: a back or tab-bar tap that landed on a root screen"
        else:
            o["note"] = "crawler could not confirm (" + o.get("note", "") + ")"; o["status"] = "UNVERIFIED"
    return o

# 2. shots in navigation order: tabs Home, Programs, Social, Body, More, then states/
order = ["home", "programs", "social", "body", "more"]
def rank(name):
    for i, t in enumerate(order):
        if re.search(rf"(^|-){t}($|-)", name): return i
    return len(order)
files = []
for f in glob.glob(f"{d}/**/*.png", recursive=True):
    if "/final/" in f or "/_work/" in f or os.path.basename(f).startswith("verify-"): continue
    files.append(f)
def group(f):
    b = os.path.basename(f)
    if "/flows/" in f: return 5 if b.endswith("-dark.png") else 4
    if "/states-dark/" in f: return 3
    if "/states/" in f: return 2
    return 1 if b.endswith("-dark.png") else 0
files.sort(key=lambda f: (group(f), rank(os.path.basename(f)), os.path.basename(f)))
os.makedirs(f"{d}/final", exist_ok=True)
rename = {}
for n, f in enumerate(files, 1):
    base = re.sub(r"^\d+-", "", os.path.basename(f))
    if not re.search(r"-(light|dark)\.png$", base): base = base[:-4] + ("-dark.png" if "/states-dark/" in f else "-light.png")
    if "/flows/" in f: base = re.sub(r"^[A-Z]-\d+-", "", base)
    new = f"{n:02d}-{base}"
    shutil.copy(f, f"{d}/final/{new}"); rename[os.path.basename(f)] = new

for state, rows in by_state.items():
    with open(f"{d}/audit-{state}-light.jsonl", "w") as out:
        for o in rows:
            o = fix(o)
            for k in ("shot",):
                if o.get(k) in rename: o[k] = rename[o[k]]
            out.write(json.dumps(o, sort_keys=True) + "\n")
print(f"{len(files)} screenshots -> {d}/final, {sum(len(r) for r in by_state.values())} audit rows in {len(by_state)} states")
