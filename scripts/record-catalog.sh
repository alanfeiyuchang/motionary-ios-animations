#!/usr/bin/env bash
# Records a short looping video + poster of every effect (zh and en) for the documentation site.
# Usage: scripts/record-catalog.sh <out-dir> <shard-index> <shard-count>
# Output: <out-dir>/media/<id>.<lang>.mp4, <out-dir>/media/<id>.<lang>.jpg, and (shard 0) <out-dir>/catalog.json
# ONLY_MISSING_FROM=<media-url>: record only the effects that lack any of their four files there (the
# published site's media folder), or whose clip there is shorter than MIN_SECONDS (default 2), split
# across the shards, instead of every effect. (simctl writes frames only when the screen changes, so an
# effect that settles gives a clip shorter than CLIP_SECONDS; that is fine. A 1-frame clip is not.)
set -euo pipefail
OUT="${1:-catalog-out}"
SHARD="${2:-0}"
SHARDS="${3:-1}"
BUNDLE_ID="com.motionlexicon.MotionLab"
CLIP_SECONDS="${CLIP_SECONDS:-4}"
MIN_SECONDS="${MIN_SECONDS:-2}"
mkdir -p "$OUT/media" "$OUT/raw"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[x for rt,xs in d.items() if "iOS" in rt for x in xs if x["name"].startswith("iPhone") and "Pro" in x["name"] and "Max" not in x["name"]]
c=c or [x for rt,xs in d.items() if "iOS" in rt for x in xs if x["name"].startswith("iPhone")]
print(c[-1]["udid"])')
echo "Simulator: $UDID (shard $SHARD/$SHARDS)"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true

xcodebuild -project MotionLab.xcodeproj -scheme MotionLab -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build > build.log 2>&1 \
  || { grep -E "error:" build.log | sort -u; exit 1; }
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/MotionLab.app

# Export the catalog (every shard needs the id list; shard 0 publishes it).
xcrun simctl launch "$UDID" "$BUNDLE_ID" -ML_exportCatalog YES -ML_noIntro YES >/dev/null
sleep 6
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
cp "$CONTAINER/Documents/catalog.json" "$OUT/catalog.json"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
# Let first-boot system banners expire before recording.
sleep 30

# The shard is decided by an effect's position in the full catalog, before the "missing" filter: every
# shard job runs that filter on its own, and a transient network error must not move an effect to a
# different shard (it would then be recorded by none).
IDS=$(ONLY_MISSING_FROM="${ONLY_MISSING_FROM:-}" python3 -c "
import concurrent.futures, json, os, subprocess, time, urllib.error, urllib.request
ids=[e['id'] for e in json.load(open('$OUT/catalog.json'))['effects']]
ids=[i for n,i in enumerate(ids) if n % $SHARDS == $SHARD]
base=os.environ['ONLY_MISSING_FROM'].rstrip('/')
def exists(url):
    for attempt in range(5):
        try:
            urllib.request.urlopen(urllib.request.Request(url, method='HEAD'), timeout=30)
            return True
        except urllib.error.HTTPError as e:
            if e.code == 404: return False
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            pass
        time.sleep(1.5 * (attempt + 1))
    return True  # unreachable is not the same as missing: leave it for the next run
def seconds(url):
    for attempt in range(3):
        r=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',url],capture_output=True,text=True,timeout=90)
        try: return float(r.stdout.strip())
        except ValueError: time.sleep(2)
    return $MIN_SECONDS  # could not be measured: do not treat as short
def published(i):
    for name in (f'{i}.{l}.{x}' for l in ('zh', 'en') for x in ('mp4', 'jpg')):
        if not exists(f'{base}/{name}'): return False
    return all(seconds(f'{base}/{i}.{l}.mp4') >= $MIN_SECONDS for l in ('zh', 'en'))
if base:
    with concurrent.futures.ThreadPoolExecutor(6) as pool:
        ids=[i for i, ok in zip(ids, pool.map(published, ids)) if not ok]
print('\n'.join(ids))")
[ -n "${ONLY_MISSING_FROM:-}" ] && echo "Missing from $ONLY_MISSING_FROM, this shard: $(echo "$IDS" | grep -c . || true)"

# Runs a command with a time limit (macOS has no GNU timeout); a hung simctl call must not stall the shard.
limit() { local secs="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

# The simulator's recorder can break for the rest of a session (every later file comes out empty), so
# an empty or hung recording reboots the simulator and tries that clip once more.
reboot_simulator() {
  echo "rebooting the simulator"
  limit 60 xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  limit 60 xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  limit 180 xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
  sleep 20
}

record() { # id lang
  record_once "$@" && return 0
  reboot_simulator
  # Second take: a clip that is still short is kept (a demo that barely changes the screen gives few
  # frames, see MIN_SECONDS above) and padded with its last frame, rather than leaving no preview.
  record_once "$@" keep-short || true
}

record_once() { # id lang [keep-short]; returns 1 when the recorder produced nothing usable
  local id="$1" lang="$2" keep="${3:-}" raw="$OUT/raw/$1.$2.mov"
  limit 20 xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  if ! limit 30 xcrun simctl launch "$UDID" "$BUNDLE_ID" -ML_stage "$id" -ML_noIntro YES -app.language "$lang" -app.appearance 2 >/dev/null; then
    echo "skip $id.$lang: launch failed or timed out"; return 0
  fi
  sleep 1.2
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$raw" >"$OUT/raw/rec.log" 2>&1 &
  local rec=$!
  # Time the clip from when capture actually begins: on a slow machine the recorder can take seconds to
  # start, which used to leave clips of 2 s or a single frame.
  local tries=0
  until grep -q "Recording started" "$OUT/raw/rec.log" 2>/dev/null || [ "$tries" -ge 60 ] || ! kill -0 "$rec" 2>/dev/null; do
    sleep 0.25; tries=$((tries + 1))
  done
  sleep "$CLIP_SECONDS"
  kill -INT "$rec" 2>/dev/null || true
  # Give the recorder up to 10 s to finalize the file, then kill it.
  local waited=0
  while kill -0 "$rec" 2>/dev/null && [ "$waited" -lt 20 ]; do sleep 0.5; waited=$((waited + 1)); done
  if kill -0 "$rec" 2>/dev/null; then
    kill -9 "$rec" 2>/dev/null || true
    echo "skip $id.$lang: recorder hung"; rm -f "$raw"; return 1
  fi
  wait "$rec" 2>/dev/null || true
  [ -s "$raw" ] || { echo "skip $id.$lang: empty recording"; return 1; }
  local got
  got=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$raw" 2>/dev/null || echo 0)
  local pad=""
  if ! python3 -c "import sys; sys.exit(0 if float('${got:-0}' or 0) >= $MIN_SECONDS else 1)"; then
    if [ -z "$keep" ]; then
      echo "skip $id.$lang: clip too short (${got:-0} s)"; rm -f "$raw"; return 1
    fi
    echo "keep $id.$lang: short clip (${got:-0} s), padded to $CLIP_SECONDS s"
    pad=",tpad=stop_mode=clone:stop_duration=$CLIP_SECONDS,trim=duration=$CLIP_SECONDS"
  fi
  # Square crop from the vertical center, 480 px, 30 fps, small h264 that loops cleanly on the web.
  echo "clip $id.$lang: ${got:-?} s raw"
  limit 60 ffmpeg -loglevel error -y -i "$raw" -an \
    -vf "crop=iw:iw:0:(ih-iw)/2,scale=480:480:flags=lanczos,fps=30,format=yuv420p$pad" \
    -c:v libx264 -preset veryfast -crf 30 -movflags +faststart "$OUT/media/$id.$lang.mp4" \
    || { echo "skip $id.$lang: ffmpeg could not encode the clip (${got:-?} s raw)"; rm -f "$OUT/media/$id.$lang.mp4"; return 1; }
  [ -s "$OUT/media/$id.$lang.mp4" ] || { echo "skip $id.$lang: empty encode"; return 1; }
  limit 30 ffmpeg -loglevel error -y -ss 2 -i "$OUT/media/$id.$lang.mp4" -frames:v 1 -q:v 5 -strict unofficial "$OUT/media/$id.$lang.jpg" || true
  # A clip shorter than 2 s has no frame there: take its first frame instead.
  [ -s "$OUT/media/$id.$lang.jpg" ] || limit 30 ffmpeg -loglevel error -y -i "$OUT/media/$id.$lang.mp4" -frames:v 1 -q:v 5 -strict unofficial "$OUT/media/$id.$lang.jpg" || true
  rm -f "$raw"
}

COUNT=0
for id in $IDS; do
  record "$id" zh
  record "$id" en
  COUNT=$((COUNT + 1))
done
echo "Recorded $COUNT effects × 2 languages in shard $SHARD"
