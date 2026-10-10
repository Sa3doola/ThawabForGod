#!/bin/zsh
# The macOS half of golden-pages.sh: launches the Mac app at each golden page and captures its
# window. Opens real windows on this Mac, one after another, and quits each.
#
#   golden-pages-mac.sh <flavour> <App.app> <output-dir> <set>
#
#   flavour  noor | mushaf;  set  pages | separated (as in golden-pages.sh)
#
# Output directory: pass the git-ignored Screenshots/quran-migration/M5/M5.1/. GOLDEN_DEVICE=mac
# names files <device>-<set>-p<page>-<theme>.png. No -quranImmersive here: the Mac has no
# immersive mode, and the window toolbar is part of what the capture should show.
#
# Needs Screen Recording permission for the terminal that runs it (window capture), and a helper
# that prints an app's window id: tools/winid, built from winid.swift beside this script.
set -u
flavour=$1 app=$2 out=$3 set=$4
here=${0:A:h}
winid=$here/tools/winid
[[ -x $winid ]] || { mkdir -p $here/tools && swiftc -O $here/winid.swift -o $winid; } || exit 1
case $flavour in
  noor) owner=Noor; process=ThawabForGod.app/Contents/MacOS/ThawabForGod ;;
  mushaf) owner=Mushaf; process=Mushaf.app/Contents/MacOS/Mushaf ;;
  *) echo "flavour must be noor or mushaf" >&2; exit 2 ;;
esac
mkdir -p "$out"

pages=(1 2 50 76 187 201 293 604)
typeset -A firstAyah=(1 1:1 2 2:1 50 3:1 76 3:195 187 9:1 201 9:87 293 17:105 604 112:1)
themes=(paper sepia dark)
# -ApplePersistenceIgnoreState: never restore a window from the previous run over the launch's
# own page (Mushaf's Mac build restores its last window otherwise).
common=(-ApplePersistenceIgnoreState YES -AppleLanguages "(en)" -AppleLocale en_US)

args() { # mode theme page|surah:ayah
  local mode=$1 theme=$2 where=$3
  if [[ $flavour == noor ]]; then
    local a=(-quranResetSettings YES -quranFollowSystem NO -quranMode $mode -quranTheme $theme)
    if [[ $where == *:* ]]; then a+=(-quranSurah ${where%%:*} -quranAyah ${where##*:}); else a+=(-quranPage $where); fi
  else
    local a=(-debugFollowSystem NO -debugMode $mode -debugTheme $theme)
    if [[ $where == *:* ]]; then a+=(-debugSurah ${where%%:*} -debugAyah ${where##*:}); else a+=(-debugPage $where); fi
  fi
  print -r -- "${a[@]}"
}

capture() { # name, launch args...
  local name=$1; shift
  osascript -e "quit app \"$owner\"" 2>/dev/null; sleep 1; pkill -f "$process" 2>/dev/null; sleep 1
  open -n "$app" --args $common "$@"
  sleep 7
  local id=$($winid $owner)
  if [[ -n $id ]]; then screencapture -o -x -l $id "$out/$name.png"; else echo "no window for $name" >&2; fi
}

for theme in $themes; do
  for page in $pages; do
    case $set in
      pages) capture "${GOLDEN_DEVICE:+$GOLDEN_DEVICE-$set-}p$page-$theme" $(args mushaf $theme $page) ;;
      separated) capture "${GOLDEN_DEVICE:+$GOLDEN_DEVICE-$set-}p$page-$theme" $(args separated $theme ${firstAyah[$page]}) ;;
    esac
  done
done
pkill -f "$process" 2>/dev/null
echo "golden pages (macOS, $flavour, $set): $(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ') files in $out"
