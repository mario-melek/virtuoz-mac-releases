#!/bin/bash
# Runs Virtuoz's own self test (start, database, window, tools, a short demo export) in a sandbox folder.
#   bash build/selftest.sh /path/to/Virtuoz.app [auto]
# "auto": the app downloads its own ffmpeg and Python like on a member's Mac (slower); otherwise it uses the computer's.
set -uo pipefail
APP="$1"; MODE="${2:-}"
SB=$(mktemp -d); REPORT="$SB/report.json"
export CZ_USERDATA="$SB/userdata" CZ_WORKSPACE="$SB/workspace" CZ_HIDDEN=1 CZ_SELF_TEST=1
[ "$MODE" = auto ] || export CZ_RUNTIME_AUTO=0
mkdir -p "$CZ_USERDATA" "$CZ_WORKSPACE"
echo "self test of $APP (sandbox $SB)"
"$APP/Contents/MacOS/Virtuoz" --self-test="$REPORT" --cz-sandbox="$SB" --mute-audio &
PID=$!
for _ in $(seq 1 600); do kill -0 $PID 2>/dev/null || break; sleep 1; done
if kill -0 $PID 2>/dev/null; then echo "still running after 10 minutes: stopped"; kill -9 $PID; fi
wait $PID; CODE=$?
echo "exit code $CODE"
if [ ! -f "$REPORT" ]; then
  echo "FAILED: no report"
  find "$CZ_USERDATA" -name '*.log' -exec tail -n 60 {} \; 2>/dev/null
  exit 1
fi
python3 - "$REPORT" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
m = lambda ok: "FAIL" if ok is False else "ok  "
for s in r.get("steps") or []: print(m(s.get("ok")), "start ·", s.get("name"), s.get("error") or "")
db = r.get("db") or {}; print(m(db.get("ok")), "database", db.get("error") or "")
print(m(r.get("paint") != "blank"), "window paint:", r.get("paint"))
for t, v in (r.get("tools") or {}).items(): print(m((v or {}).get("ok")), "tool", t, (v or {}).get("error") or "")
ex = r.get("export") or {}; print(m(ex.get("ok")), "demo export", ex.get("error") or "")
print("report ok:", r.get("ok"))
sys.exit(0 if r.get("ok") is not False else 1)
PY
RES=$?
find "$CZ_USERDATA" -name 'main.log' -exec tail -n 40 {} \; 2>/dev/null
[ $RES -eq 0 ] && [ $CODE -eq 0 ]
