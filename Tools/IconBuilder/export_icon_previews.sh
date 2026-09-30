#!/bin/zsh
#
# export_icon_previews.sh
# Tools/IconBuilder
#
# Exports the pictures the App icon picker in Settings draws, one per Icon Composer bundle.
#
# Run from the repository root, after changing any of `ThawabForGod/Resources/AppIcon*.icon`:
#
#     zsh Tools/IconBuilder/export_icon_previews.sh
#
# The picker cannot draw the icons themselves. An alternate icon compiled from a `.icon` bundle
# is not an image the app can load by name — `UIImage(named:)` finds nothing — so the tiles need
# plain PNGs, and a PNG exported by hand goes stale the first time the artwork changes. This asks
# Icon Composer's own renderer for them, so a preview is the icon rather than a drawing of it.
#
# Each image set carries a light and a dark rendition, at 2x and 3x of the 60-point tile. The
# dark one is not decoration: on a device in dark mode the Home Screen shows the icon's dark
# rendition, and a picker showing the light one would be previewing an icon the reader never sees.
#
# `ictool` ships inside Icon Composer, inside Xcode. It is not the `/usr/bin/ictool` on the
# `PATH`, which is a different tool that shares the name and rejects `--export-image`.

set -euo pipefail

ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
SOURCES="ThawabForGod/Resources"
CATALOG="ThawabForGod/Resources/Assets.xcassets/AppIconImages"
POINTS=60

if [[ ! -x "$ICTOOL" ]]; then
    echo "ictool not found at $ICTOOL — is Xcode 26 or later selected?" >&2
    exit 1
fi

# Bundle name → preview name. The preview names are what `AppIconChoice.previewAssetName` asks
# for; change one side and the other together.
typeset -A previews=(
    AppIcon       IconPreview-Default
    AppIcon-Green IconPreview-Green
    AppIcon-Night IconPreview-Night
    AppIcon-Sand  IconPreview-Sand
)

for bundle preview in "${(@kv)previews}"; do
    input="$SOURCES/$bundle.icon"
    output="$CATALOG/$preview.imageset"
    mkdir -p "$output"

    for rendition in Default Dark; do
        for scale in 2 3; do
            "$ICTOOL" "$input" --export-image \
                --output-file "$output/$preview-$rendition@${scale}x.png" \
                --platform iOS --rendition "$rendition" \
                --width "$POINTS" --height "$POINTS" --scale "$scale" > /dev/null
        done
    done

    cat > "$output/Contents.json" <<JSON
{
  "images" : [
    {
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "$preview-Default@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "$preview-Default@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "$preview-Dark@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "$preview-Dark@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

    echo "Exported $preview"
done
