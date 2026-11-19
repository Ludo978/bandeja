#!/usr/bin/env bash
# Generates bundled-fonts/: Roboto Condensed as bitmap fonts for the watches without Roboto Condensed
# vector fonts (Descent G2, Instinct 3 AMOLED, Venu 2, 2 Plus, 2S, 3 and 3S, vivoactive 5, D2 Air X10,
# Approach S50), which otherwise draw with their system fonts, too large for the app's labels.
# One folder per screen size, each with the sizes its screens draw: monkey.jungle adds each watch's
# folder to its build only.
#
# Usage: scripts/make-fonts.sh [roboto dir]
#   roboto dir: a folder holding RobotoCondensed-Bold.ttf and RobotoCondensed-Regular.ttf; by default
#   the Roboto 2.138 release (Apache License 2.0) is downloaded from github.com/googlefonts/roboto.
#
# Each set is a style, a character set and the em sizes it comes in; Fonts asks for an em size and
# gets the set's nearest one. A folder's sizes cover what the screens draw at its screen sizes, the
# labels down to three quarters of their size (Layout.fitSize()), and the glance's line on its
# watches. The output is the same on every run, so a folder regenerated with sizes added keeps its
# other fonts byte for byte. macOS only (CoreText, swiftc).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/bundled-fonts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ $# -ge 1 ]]; then
    FONTS="$1"
else
    curl -sSL -o "$WORK/roboto.zip" https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-unhinted.zip
    unzip -q "$WORK/roboto.zip" -d "$WORK/roboto"
    FONTS="$WORK/roboto"
fi
BOLD="$FONTS/RobotoCondensed-Bold.ttf"
REGULAR="$FONTS/RobotoCondensed-Regular.ttf"
[[ -f "$BOLD" && -f "$REGULAR" ]] || { echo "Roboto Condensed not found in $FONTS" >&2; exit 1; }

swiftc -O -o "$WORK/fontgen" "$ROOT/scripts/fontgen.swift" 2>/dev/null

# Character sets. Full: ASCII, Latin-1, Latin Extended-A and common punctuation (team names, French,
# mixed-case lines). Caps: what the large labels and values hold. Digits: the number style's (Fonts:
# digits and ": - . %"). Title: the glance's "Bandeja".
python3 - "$WORK" <<'EOF'
import sys
work = sys.argv[1]
full = [chr(c) for c in range(0x20, 0x7F)] + [chr(c) for c in range(0xA0, 0x180)] \
    + [chr(c) for c in (0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026, 0x20AC)]
caps = list(" !\"#%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_·") \
    + [chr(c) for c in range(0xC0, 0xDF) if c != 0xD7] + ["Œ", "Ÿ"]
digits = list(" %+-./0123456789:·")
title = list("Bandej")
for name, chars in (("full", full), ("caps", caps), ("digits", digits), ("title", title)):
    open(f"{work}/{name}.txt", "w", encoding="utf-8").write("".join(chars))
EOF

# "a b" as the numbers from a to b.
span() { seq -s ' ' "$1" "$2"; }

# The folders: name, the largest size the screens take from the full sets (above it, the capitals
# sets), then the em sizes of each set: bold with the full character set (the screens' up to the
# largest, and the glance's line, in the glance's scope), regular with it, bold and regular capitals,
# the number style's digits; then the glance title's line heights, each watch's system glance font's.
# 390 and 416 px, two folders. 390-416 is 1.1's set, for the Descent G2 and the Instinct 3 AMOLED, kept as
# it was so their builds don't grow. 390-416-tall is the same set for the watches added in 1.2 (the Venu
# 2, 2 Plus and 3S, the vivoactive 5, the D2 Air X10, the Approach S50), whose glance areas are taller:
# with bold 23 to 27 for the glance's line and the titles 39, 41 and 43. 360 px (Venu 2S) and 454 px
# (Venu 3): the same mockup sizes on their screens.
FOLDERS=(
    "390-416|22|$(span 8 22)|$(span 8 22)|$(span 23 32) 41 44 98 104 113 120|$(span 23 32)|$(span 10 32) 43 45 46 48 53 56 60 64 90 96 113 120|33 37 40"
    "390-416-tall|22|$(span 8 27)|$(span 8 22)|$(span 23 32) 41 44 98 104 113 120|$(span 23 32)|$(span 10 32) 43 45 46 48 53 56 60 64 90 96 113 120|33 37 39 40 41 43"
    "360|22|$(span 8 23)|$(span 8 22)|$(span 23 28) 38 90 104|$(span 23 28)|$(span 8 28) 40 42 48 55 83 104|37"
    "454|23|$(span 9 28)|$(span 9 23)|$(span 24 35) 48 114 131|$(span 24 35)|$(span 10 35) 50 52 61 70 105 131|45"
)

# The comma-separated sizes, and their resource IDs.
nums() { echo "$1" | xargs | tr ' ' ',' | sed 's/,/, /g'; }
ids() { local out="" s; for s in $2; do out+="${out:+, }Rez.Fonts.$1$s"; done; echo "$out"; }

# Generates one folder: its fonts, fonts.xml and BundledFonts.mc.
generate() {
    local name="$1" fullMax="$2" bold="$3" regular="$4" boldCaps="$5" regularCaps="$6" digits="$7" titles="$8"
    local dir="$OUT/$name" px="${name%-tall}" xml set id file chars sizes scope size attr em
    rm -rf "$dir"
    mkdir -p "$dir/resources/fonts" "$dir/source"
    xml="$dir/resources/fonts/fonts.xml"
    echo "<fonts>" > "$xml"
    # Set id, font file, character set, em sizes, resource scope. The full bold set and the titles are
    # in the glance's scope too (BundledGlanceFonts): the glance's line takes the bold sizes.
    for set in "B|$BOLD|full|$bold|glance" "R|$REGULAR|full|$regular|" "BC|$BOLD|caps|$boldCaps|" \
            "RC|$REGULAR|caps|$regularCaps|" "N|$BOLD|digits|$digits|"; do
        IFS='|' read -r id file chars sizes scope <<<"$set"
        for size in $sizes; do
            "$WORK/fontgen" "$file" "$size" "$WORK/$chars.txt" "$dir/resources/fonts" "$id$size" >/dev/null
            attr=""; [[ -n "$scope" ]] && attr=" scope=\"$scope\""
            echo "    <font id=\"$id$size\" filename=\"$id$size.fnt\" antialias=\"true\"$attr/>" >> "$xml"
        done
    done
    # The glance title as high as the system glance font of each watch: its em size is the line
    # height / 1.1719.
    for size in $titles; do
        em="$(python3 -c "print($size / 1.1719)")"
        "$WORK/fontgen" "$BOLD" "$em" "$WORK/title.txt" "$dir/resources/fonts" "T$size" >/dev/null
        echo "    <font id=\"T$size\" filename=\"T$size.fnt\" antialias=\"true\" scope=\"glance\"/>" >> "$xml"
    done
    echo "</fonts>" >> "$xml"

    # The lookup: each set's sizes and fonts, in the order generated.
    cat > "$dir/source/BundledFonts.mc" <<EOF
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Generated by scripts/make-fonts.sh, which holds the sizes: don't edit by hand.
// Roboto Condensed (Apache License 2.0, bundled-fonts/LICENSE) as bitmap fonts at the sizes the $px px
// screens draw, for the watches without Roboto Condensed vector fonts (monkey.jungle builds this folder
// into theirs only). Fonts.load() and the glance ask for a style and an em size and get the nearest size
// the style comes in.
module BundledFonts {

    // Regular with the full character set, up to FULL_MAX (bold's are BundledGlanceFonts'); bold and
    // regular capitals and digits above it; the number style's digits.
    const REGULAR_SIZES = [$(nums "$regular")] as Array<Number>;
    const BOLD_CAPS_SIZES = [$(nums "$boldCaps")] as Array<Number>;
    const REGULAR_CAPS_SIZES = [$(nums "$regularCaps")] as Array<Number>;
    const NUMBER_SIZES = [$(nums "$digits")] as Array<Number>;
    // Above it, Fonts takes the capitals sets.
    const FULL_MAX = $fullMax;

    function get(style as FontStyle, size as Number) as Graphics.FontType {
        if (style == STYLE_NUMBER) {
            return load(NUMBER_SIZES, [$(ids N "$digits")] as Array<ResourceId>, size);
        }
        if (style == STYLE_REGULAR) {
            return size <= FULL_MAX
                ? load(REGULAR_SIZES, [$(ids R "$regular")] as Array<ResourceId>, size)
                : load(REGULAR_CAPS_SIZES, [$(ids RC "$regularCaps")] as Array<ResourceId>, size);
        }
        return size <= FULL_MAX
            ? BundledGlanceFonts.bold(size)
            : load(BOLD_CAPS_SIZES, [$(ids BC "$boldCaps")] as Array<ResourceId>, size);
    }

    function load(sizes as Array<Number>, fonts as Array<ResourceId>, size as Number) as Graphics.FontType {
        return BundledGlanceFonts.font(fonts[BundledGlanceFonts.nearest(sizes, size)]);
    }
}

// The bold sizes and the title the glance draws with too (in its scope).
(:glance)
module BundledGlanceFonts {

    // Bold with the full character set: the screens' up to BundledFonts.FULL_MAX, and the glance's line.
    const BOLD_SIZES = [$(nums "$bold")] as Array<Number>;
    const TITLE_HEIGHTS = [$(nums "$titles")] as Array<Number>;

    // Each font loaded, kept: the sizes asked for that share a bundled size share its font.
    var _loaded as Dictionary<ResourceId, Graphics.FontType> = {} as Dictionary<ResourceId, Graphics.FontType>;

    function bold(size as Number) as Graphics.FontType {
        return font(([$(ids B "$bold")] as Array<ResourceId>)[nearest(BOLD_SIZES, size)]);
    }

    // "Bandeja" in bold, its line as high as height (the system glance font's).
    function title(height as Number) as Graphics.FontType {
        return font(([$(ids T "$titles")] as Array<ResourceId>)[nearest(TITLE_HEIGHTS, height)]);
    }

    function font(id as ResourceId) as Graphics.FontType {
        var font = _loaded[id];
        if (font == null) {
            font = WatchUi.loadResource(id) as Graphics.FontType;
            _loaded[id] = font;
        }
        return font;
    }

    // The index of the size closest to size, the smaller one on a tie.
    function nearest(sizes as Array<Number>, size as Number) as Number {
        var best = 0;
        for (var i = 1; i < sizes.size(); i++) {
            if ((sizes[i] - size).abs() < (sizes[best] - size).abs()) {
                best = i;
            }
        }
        return best;
    }
}
EOF
    echo "bundled-fonts/$name: $(ls "$dir/resources/fonts" | grep -c '\.fnt$') fonts, $(du -sh "$dir/resources" | cut -f1)"
}

# The folders of 1.1 kept the set at the top of bundled-fonts/: gone, now in 390-416.
rm -rf "$OUT/resources" "$OUT/source"
for folder in "${FOLDERS[@]}"; do
    IFS='|' read -r name fullMax bold regular boldCaps regularCaps digits titles <<<"$folder"
    generate "$name" "$fullMax" "$bold" "$regular" "$boldCaps" "$regularCaps" "$digits" "$titles"
done
cp "$FONTS/LICENSE" "$OUT/LICENSE" 2>/dev/null || true
