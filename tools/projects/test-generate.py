# test-generate.py
import json, subprocess, sys, tempfile, pathlib
d = pathlib.Path(__file__).parent
data = [
  {"name":"alpha","managed":True,"last_commit_epoch":1,"dirty":0,"unpushed":0,
   "status_age_days":3,"hot_bytes":10,"hot_budget":1000000000,"over_budget":False,
   "database":"postgres","dump_age_hours":5,"deploy":"srv","service_state":"active","error":""},
  {"name":"zzz-test-b","managed":False,"last_commit_epoch":0,"dirty":0,"unpushed":0,
   "status_age_days":-1,"hot_bytes":5,"hot_budget":0,"over_budget":False,
   "database":"none","dump_age_hours":-1,"deploy":"none","service_state":"none","error":""},
]
tj = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False); json.dump(data, tj); tj.close()
th = tempfile.mktemp(suffix=".html")
subprocess.run([sys.executable, str(d/"generate.py"), tj.name, th], check=True)
html = open(th).read()
assert "alpha" in html, "alpha row"
assert "unmanaged" in html.lower(), "unmanaged flag"
assert "os.css" in html, "brand stylesheet linked"
assert "active" in html, "service state shown"
print("PASS")
