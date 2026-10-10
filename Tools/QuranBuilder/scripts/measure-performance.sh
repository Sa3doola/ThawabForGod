#!/bin/zsh
# Cold launch to the first Mushaf page, and memory while paging 1→604, read from the DEBUG
# `PerformanceProbe` lines — for this app or for the Mushaf reference project, run the same way.
#
#   measure-performance.sh <flavour> <simulator-udid> <App.app> [runs]
#
#   flavour  noor | mushaf
#
# Unchanged at M5.1 on purpose: the probes time the pager, not the chrome, and the reader screen now
# sits above it (the 1→604 figure is this task's regression check). No -quranImmersive is passed, so
# the run includes the navigation and tab bars, as a reader's does. Nothing here writes screenshots.
#
# Simulator numbers are for before/after comparison only, not device figures. Build both sides the
# same way, with optimisation and the DEBUG probes, e.g.
#   xcodebuild build -scheme ThawabForGod -destination 'generic/platform=iOS Simulator' SWIFT_OPTIMIZATION_LEVEL=-O
# (an -Onone build penalises Swift code against system frameworks).
set -u
flavour=$1 udid=$2 app=$3 runs=${4:-5}
case $flavour in
  noor) bundle=com.Sa3dola.ThawabForGod; page=(-quranResetSettings YES -quranMode mushaf -quranPage); through=(-quranPageThrough YES) ;;
  mushaf) bundle=com.saadsherif.mushaf; page=(-debugMode mushaf -debugPage); through=(-debugPageThrough YES) ;;
  *) echo "flavour must be noor or mushaf" >&2; exit 2 ;;
esac
log=$(mktemp)

xcrun simctl boot "$udid" 2>/dev/null
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl install "$udid" "$app"

wait_for() { # pattern, timeout seconds
  for _ in $(seq 1 $(( $2 * 10 ))); do grep -q "$1" "$log" && return 0; sleep 0.1; done
  return 1
}

run() { # launch args...
  : > "$log"
  xcrun simctl terminate "$udid" $bundle 2>/dev/null
  sleep 1
  xcrun simctl launch --console-pty "$udid" $bundle -AppleLanguages "(en)" "$@" > "$log" 2>&1 &
  local pid=$!
  wait_for "$PATTERN" $TIMEOUT || echo "timed out waiting for $PATTERN" >&2
  xcrun simctl terminate "$udid" $bundle 2>/dev/null
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
}

times=()
PATTERN="PerformanceProbe firstPage" TIMEOUT=30
for i in $(seq 1 $runs); do
  run $page 50
  line=$(grep -o "firstPage=[0-9]*ms footprint=[0-9]*MB" "$log")
  echo "launch $i: $line"
  times+=$(echo "$line" | sed -E 's/firstPage=([0-9]+)ms.*/\1/')
done
sorted=(${(on)times})
echo "cold launch to first page: median ${sorted[$(( (runs + 1) / 2 ))]} ms (min ${sorted[1]}, max ${sorted[-1]})"

PATTERN="PerformanceProbe pageThrough pages=" TIMEOUT=300
run $page 1 $through
# Footprint and registered page fonts every 50 pages, then the summary.
grep -o "pageThrough.*" "$log"
rm -f "$log"
