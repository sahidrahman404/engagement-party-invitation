#!/usr/bin/env bash
#
# Renders assets/svg/icon.svg into the bitmap icons browsers and iOS ask for:
#
#   favicon.ico          16/32/48, for the tab strip and anything that still
#                        probes /favicon.ico blindly
#   apple-touch-icon.png 180x180 opaque, for "Add to Home Screen" on iOS
#
#   ./tools/build-icons.sh
#
# Both live at the site root because browsers and iOS request them there by
# path even when no <link> points at them.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
icon="$root/assets/svg/icon.svg"

die() { printf 'build-icons: %s\n' "$1" >&2; exit 1; }

chrome=""
for c in google-chrome-stable google-chrome chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then chrome=$c; break; fi
done
[ -n "$chrome" ] || die "need Chrome or Chromium on PATH to render the icon"

if command -v magick >/dev/null 2>&1; then im=(magick)
elif command -v convert >/dev/null 2>&1; then im=(convert)
else die "need ImageMagick (magick or convert) to write the ico"
fi

master=$(mktemp -t icon-master.XXXXXX.png)
trap 'rm -f "$master"' EXIT

# Rendered once at 512 and downsampled, rather than rasterising the SVG at each
# size — Chrome antialiases the curves better than a nearest-size resize does.
"$chrome" \
  --headless \
  --disable-gpu \
  --no-sandbox \
  --hide-scrollbars \
  --default-background-color=00000000 \
  --window-size=512,512 \
  --virtual-time-budget=4000 \
  --screenshot="$master" \
  "file://$icon" >/dev/null 2>&1

[ -s "$master" ] || die "Chrome produced no render"

# iOS composites any alpha against black, so the touch icon is flattened onto
# the cream ground rather than shipped with a transparent edge.
"${im[@]}" "$master" \
  -resize 180x180 \
  -filter Lanczos \
  -background '#FDFAE0' -alpha remove -alpha off \
  -strip \
  "$root/apple-touch-icon.png"

# One .ico holding all three sizes; Windows and older Safari pick per context.
"${im[@]}" "$master" \
  -filter Lanczos \
  -define icon:auto-resize=48,32,16 \
  -background '#FDFAE0' -alpha remove -alpha off \
  -strip \
  "$root/favicon.ico"

for f in apple-touch-icon.png favicon.ico; do
  read -r w h bytes < <("${im[@]}" identify -format '%w %h %B\n' "$root/$f" | head -1)
  printf 'build-icons: wrote %-22s (%sx%s, %s bytes)\n' "$f" "$w" "$h" "$bytes"
done
