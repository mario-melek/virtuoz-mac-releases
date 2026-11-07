#!/bin/bash
# Runs Virtuoz's own self test (start, database, window, tools, a short demo export) in a sandbox folder.
#   bash build/selftest.sh /path/to/Virtuoz.app [auto]
# "auto": the app downloads its own ffmpeg and Python like on a member's Mac (slower); otherwise it uses the computer's.
# SELFTEST_FLAGS: extra app flags (--software-graphics on a Mac with no graphics card, like GitHub's Intel Macs).
# SELFTEST_SKIP_PAINT=1: the window check is reported but not judged (an Intel build run under Rosetta 2).
# SELFTEST_SKIP_EXPORT=1: the demo export is reported but not judged (a VM with no graphics at all).
# SELFTEST_SKIP_TOOLS: tools not judged here, e.g. "python claude" on a bare build Mac (install.sh installs them).
set -uo pipefail
APP="$1"; MODE="${2:-}"
SB=$(mktemp -d); REPORT="$SB/report.json"
export CZ_USERDATA="$SB/userdata" CZ_WORKSPACE="$SB/workspace" CZ_HIDDEN=1 CZ_SELF_TEST=1
[ "$MODE" = auto ] || export CZ_RUNTIME_AUTO=0
mkdir -p "$CZ_USERDATA" "$CZ_WORKSPACE"
echo "self test of $APP (sandbox $SB)"
"$APP/Contents/MacOS/Virtuoz" --self-test="$REPORT" --cz-sandbox="$SB" --mute-audio ${SELFTEST_FLAGS:-} &
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
python3 - "$REPORT" "${SELFTEST_SKIP_TOOLS:-}" <<'PY'
import json, os, sys
r = json.load(open(sys.argv[1])); skip = sys.argv[2].split()
m = lambda ok: "FAIL" if ok is False else "ok  "
for s in r.get("steps") or []: print(m(s.get("ok")), "start ·", s.get("name"), s.get("error") or "")
db = r.get("db") or {}; print(m(db.get("ok")), "database", db.get("error") or "")
print(m(r.get("paint") != "blank"), "window paint:", r.get("paint"))
bad = [s.get("name") for s in r.get("steps") or [] if s.get("ok") is False]
if db.get("ok") is False: bad.append("database")
if r.get("paint") == "blank" and not os.environ.get("SELFTEST_SKIP_PAINT"): bad.append("paint")
for t, v in (r.get("tools") or {}).items():
    ok = (v or {}).get("ok"); print(m(ok), "tool", t, (v or {}).get("error") or "", "(not judged here)" if t in skip else "")
    if ok is False and t not in skip: bad.append(t)
ex = r.get("export") or {}; print(m(ex.get("ok")), "demo export", ex.get("error") or "")
if ex.get("ok") is False and not os.environ.get("SELFTEST_SKIP_EXPORT"): bad.append("export")
print("report ok:", r.get("ok"), "| judged failures:", bad or "none")
sys.exit(1 if bad else 0)
PY
RES=$?
L=$(find "$CZ_USERDATA" -name 'main.log' | head -1)
[ -n "$L" ] && { echo '--- graphics and export lines of main.log'; grep -E 'graphics|gpu|webgl|export|self-test' "$L" | cut -c1-300 | tail -n 40; }
[ $RES -eq 0 ]
