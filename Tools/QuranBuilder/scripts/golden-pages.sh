#!/bin/zsh
# Captures the Quran migration's golden pages on a simulator, from this app or from the Mushaf
# reference project, for side-by-side visual sign-off (QURAN_MIGRATION_PLAN.md, Q3 — no pixel diff).
#
#   golden-pages.sh <flavour> <simulator-udid> <App.app> <output-dir> <set>
#
#   flavour  noor | mushaf      which app's launch options to speak (-quran… or Mushaf's -debug…)
#   set      pages              Mushaf mode, the golden pages, paper / sepia / dark
#            separated          separated mode at each golden page's first ayah, three themes
#            spreads            the spread holding each golden page, rendered offscreen at iPad Pro
#                               11" landscape (1210×834 pt) — iPadOS refuses a scripted rotation
#
# Output directory: pass the git-ignored Screenshots/quran-migration/M5/M5.1/ (or a subfolder) to
# keep milestone captures together; files are named p<page>-<theme>.png. Name a copy per device and
# screen as <device>-<screen>-<theme>.png when filing them there (e.g. iphone17pro-mushaf-p50-dark.png).
# Environment: GOLDEN_IMMERSIVE=YES hides the bars on an iPhone in Mushaf mode, for both flavours
# (-quranImmersive for noor, Mushaf's -debugImmersive for mushaf) so the two stay comparable; the
# default is NO, which leaves the bars and so produces what the script always produced. iPad ignores
# it. GOLDEN_DEVICE=iphone17pro prefixes names as <device>-<set>-p<page>-<theme>.png.
#
# Needs a DEBUG build (the launch options are compiled out of Release). English, light appearance,
# the reader's theme pinned (follow-system off), a 9:41 status bar (not drawn in an immersive
# capture, which hides it). A Mushaf capture is pixel-for-
# pixel what the reference project draws; the chrome around the page differs by design.
set -u
flavour=$1 udid=$2 app=$3 out=$4 set=$5
case $flavour in
  noor) bundle=com.Sa3dola.ThawabForGod ;;
  mushaf) bundle=com.saadsherif.mushaf ;;
  *) echo "flavour must be noor or mushaf" >&2; exit 2 ;;
esac
mkdir -p "$out"

pages=(1 2 50 76 187 201 293 604)
# The first ayah of each golden page in the Madani V2 layout (mushaf_page.first_ayah).
typeset -A firstAyah=(1 1:1 2 2:1 50 3:1 76 3:195 187 9:1 201 9:87 293 17:105 604 112:1)
themes=(paper sepia dark)

xcrun simctl boot "$udid" 2>/dev/null
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl ui "$udid" appearance light
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi --operatorName ""
xcrun simctl install "$udid" "$app"

common=(-AppleLanguages "(en)" -AppleLocale en_US)

# args <mode> <theme> <page|surah:ayah>
args() {
  local mode=$1 theme=$2 where=$3
  if [[ $flavour == noor ]]; then
    local a=(-quranResetSettings YES -quranFollowSystem NO -quranMode $mode -quranTheme $theme)
    if [[ $where == *:* ]]; then a+=(-quranSurah ${where%%:*} -quranAyah ${where##*:}); else a+=(-quranPage $where); fi
    if [[ ${GOLDEN_IMMERSIVE:-NO} == YES && $mode == mushaf ]]; then a+=(-quranImmersive YES); fi
  else
    local a=(-debugFollowSystem NO -debugMode $mode -debugTheme $theme)
    if [[ $where == *:* ]]; then a+=(-debugSurah ${where%%:*} -debugAyah ${where##*:}); else a+=(-debugPage $where); fi
    if [[ ${GOLDEN_IMMERSIVE:-NO} == YES && $mode == mushaf ]]; then a+=(-debugImmersive YES); fi
  fi
  print -r -- "${a[@]}"
}

# fname <screen> <theme>: p50-dark by default; <device>-<set>-p50-dark when GOLDEN_DEVICE is set
# (the M5 screenshots' <device>-<screen>-<theme> convention).
fname() { print -r -- "${GOLDEN_DEVICE:+$GOLDEN_DEVICE-$set-}$1-$2"; }

running() { xcrun simctl spawn "$udid" launchctl list 2>/dev/null | grep -q "$bundle"; }

capture() { # name, launch args...
  local name=$1; shift
  for attempt in 1 2 3; do
    xcrun simctl terminate "$udid" $bundle 2>/dev/null
    xcrun simctl launch "$udid" $bundle $common "$@" >/dev/null
    sleep 6
    # A launch that died (see the M4 report: an intermittent launch-time crash outside the
    # reader) would capture the home screen; try again rather than keep it.
    running && break
    echo "relaunching $name (attempt $attempt died)" >&2
  done
  xcrun simctl io "$udid" screenshot "$out/$name.png" >/dev/null 2>&1
}

spread() { # name, theme, page
  xcrun simctl terminate "$udid" $bundle 2>/dev/null
  local data=$(xcrun simctl get_app_container "$udid" $bundle data)
  rm -f "$data/Documents/spread.png"
  if [[ $flavour == noor ]]; then
    xcrun simctl launch "$udid" $bundle $common $(args mushaf $2 $3) -quranRenderSpread 1210x834 >/dev/null
  else
    xcrun simctl launch "$udid" $bundle $common $(args mushaf $2 $3) -debugRenderSpread 1210x834 >/dev/null
  fi
  for _ in {1..40}; do [[ -f "$data/Documents/spread.png" ]] && break; sleep 0.5; done
  sleep 0.5
  cp "$data/Documents/spread.png" "$out/$1.png" 2>/dev/null || echo "no spread for $1" >&2
}

for theme in $themes; do
  for page in $pages; do
    case $set in
      pages) capture "$(fname "p$page" $theme)" $(args mushaf $theme $page) ;;
      separated) capture "$(fname "p$page" $theme)" $(args separated $theme ${firstAyah[$page]}) ;;
      spreads) first=$(( page - (page - 1) % 2 )); spread "$(fname "p$first-$(( first + 1 ))" $theme)" $theme $page ;;
    esac
  done
done
# (The spread the plan names on its own, 49|50, is page 50's unit.)

xcrun simctl terminate "$udid" $bundle 2>/dev/null
xcrun simctl status_bar "$udid" clear
echo "golden pages ($flavour, $set): $(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ') files in $out"
