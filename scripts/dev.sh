#!/usr/bin/env bash
# Build, test, run and export Connect IQ projects from the command line.
#
# Usage: scripts/dev.sh [-p <project dir>] <command> [device]
#   build [device]   compile a debug .prg (device defaults to fr265)
#   test [device]    compile with the (:test) functions and run them in the simulator
#   run [device]     compile and launch in the simulator
#   export           package the signed .iq for the store (all products, release mode)
#   export-beta      package the private beta, bin/bandeja-beta.iq: the app under its beta ID and
#                    the name "Bandeja beta", in release mode like export (no debug tools)
#   sim              start the simulator if it isn't running
#   deploy [device]  compile and copy to a watch plugged in over USB (GARMIN/Apps/<NAME>.PRG);
#                    the watch installs it when unplugged
#   logs             copy GARMIN/Apps/LOGS (crash reports CIQ_LOG.*) from the watch to bin/logs/
#   fit [count]      copy the newest activity FIT files (default 1) from the watch to bin/fit/
#                    deploy, logs and fit need libmtp (brew install libmtp)
#
# -p picks another project folder; default is the repo root.
# Builds use strict type checking and fail on any compiler warning.
#
# Environment:
#   CIQ_KEY   developer key (default ~/.garmin/developer_key.der)
#   CIQ_SDK   SDK folder (default: the SDK Manager's current SDK)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT"
if [[ "${1:-}" == "-p" ]]; then
    PROJECT="$(cd "$2" && pwd)"
    shift 2
fi
CMD="${1:-}"
DEVICE="${2:-fr265}"

KEY="${CIQ_KEY:-$HOME/.garmin/developer_key.der}"
SDK="${CIQ_SDK:-$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null || true)}"
SDK="${SDK%/}"
NAME="$(basename "$PROJECT")"
OUT="$PROJECT/bin"
JUNGLE="$PROJECT/monkey.jungle"

# The app ID of the private beta (store app "Bandeja beta"). Garmin never publishes a beta, so the
# beta can't use manifest.xml's ID, which stays for the public release. Never change it:
# each new beta version is uploaded under it.
BETA_ID="11803f603c474b86af7d65c5cf70c437"

die() { echo "error: $*" >&2; exit 1; }

[[ -x "$SDK/bin/monkeyc" ]] || die "Connect IQ SDK not found. Install it with the SDK Manager or set CIQ_SDK."
[[ -f "$KEY" ]] || die "developer key not found at $KEY. Set CIQ_KEY."

# Fails when a translation lacks a string ID of resources/strings/strings.xml or has one it doesn't:
# the watch would silently show the English for a missing one.
check_translations() {
    local base="$PROJECT/resources/strings/strings.xml" lang missing
    for lang in "$PROJECT"/resources-*/strings/strings.xml; do
        [[ -f "$lang" ]] || continue
        missing="$(diff <(grep -o 'string id="[^"]*"' "$base" | sort) <(grep -o 'string id="[^"]*"' "$lang" | sort) \
            | sed -n 's/^< string id="\(.*\)"/missing \1/p; s/^> string id="\(.*\)"/unknown \1/p')" || true
        [[ -z "$missing" ]] || die "${lang#"$PROJECT"/}: $(echo $missing)"
    done
}

# Runs monkeyc and fails on errors or warnings.
compile() {
    local log
    check_translations
    log="$(mktemp)"
    if ! "$SDK/bin/monkeyc" -f "$JUNGLE" -y "$KEY" -l 3 -w "$@" 2>&1 | tee "$log"; then
        rm -f "$log"
        die "build failed"
    fi
    if grep -q "^WARNING" "$log"; then
        rm -f "$log"
        die "build has warnings"
    fi
    rm -f "$log"
}

sim_running() { nc -z 127.0.0.1 1234 >/dev/null 2>&1; }

start_sim() {
    sim_running && return 0
    "$SDK/bin/connectiq" >/dev/null 2>&1 &
    # A start either listens within a few seconds or never does (then the test run retries).
    for _ in $(seq 1 30); do
        sim_running && return 0
        sleep 1
    done
    echo "simulator did not start" >&2
    return 1
}

# Quits the simulator, and any transport a killed monkeydo run left behind (later runs hang on it),
# then starts a fresh one.
restart_sim() {
    local sim="ConnectIQ.app/Contents/MacOS/simulator"
    pkill -f "$sim" 2>/dev/null || true
    pkill -f "$SDK/bin/shell" 2>/dev/null || true
    # Relaunching while the old one is still quitting fails to start: wait until it's gone.
    for _ in $(seq 1 30); do
        pgrep -f "$sim" >/dev/null || break
        sleep 0.5
    done
    pkill -9 -f "$sim" 2>/dev/null || true
    start_sim
}

# Watch access over MTP (libmtp). The awk filters read all their input: stopping early
# would break the pipe, and pipefail would then end the script silently.

mtp_ready() {
    command -v mtp-sendfile >/dev/null || die "mtp-sendfile not found: brew install libmtp"
    if pgrep -qi openmtp; then
        die "quit OpenMTP first: only one app at a time can talk to the watch"
    fi
    # macOS's camera import agent grabs MTP devices; it restarts on its own when needed.
    pkill -x ptpcamerad 2>/dev/null || true
}

# Sets APPS_ID, LOGS_ID and ACTIVITY_ID to the MTP ids of GARMIN/Apps, GARMIN/Apps/LOGS
# and GARMIN/Activity. The watch renumbers ids on every connection.
find_garmin_folders() {
    read -r APPS_ID LOGS_ID ACTIVITY_ID <<<"$(mtp-folders 2>/dev/null | awk -F'\t' '
        $2 == "GARMIN" { garmin = 1; next }
        $2 ~ /^[^ ]/ { garmin = 0 }
        garmin && $2 ~ /^  [^ ]/ { inapps = ($2 == "  Apps"); if (inapps) apps = $1 }
        garmin && $2 == "  Activity" { activity = $1 }
        garmin && inapps && $2 == "    LOGS" { logs = $1 }
        END { print apps, logs, activity }' || true)"
    [[ "${APPS_ID:-}" =~ ^[0-9]+$ ]] || die "watch not found: plug it in, quit Garmin Express, and check the cable"
}

# Prints "<id> <NAME>" for each file in folder id $1, from the mtp-files listing in $2.
files_in() {
    awk -v parent="$1" '
        /^File ID:/ { id = $3 }
        /Filename:/ { file = $2 }
        /Parent ID:/ && $3 == parent { print id, toupper(file) }' <<<"$2"
}

# Copies local file $1 into watch folder $2 (e.g. /GARMIN/Apps) under the name $3.
send_file() {
    local tmp sent
    tmp="$(mktemp -d)"
    cp "$1" "$tmp/$3"
    sent="$(mtp-sendfile "$tmp/$3" "$2" 2>&1 || true)"
    rm -rf "$tmp"
    [[ "$sent" == *"New file ID"* ]]
}

# Copies $1 to GARMIN/Apps/$2.
deploy_to_watch() {
    local prg="$1" name="$2" files id
    mtp_ready
    find_garmin_folders
    files="$(mtp-files 2>/dev/null || true)"

    # MTP never overwrites, so remove a copy the watch hasn't installed yet.
    # Delete by exact id only: an unresolved id (-1) means "every object" in MTP.
    id="$(files_in "$APPS_ID" "$files" | awk -v n="$name" '$2 == n { print $1 }')"
    if [[ "$id" =~ ^[0-9]+$ ]] && (( id > 0 )); then
        mtp-delfile -n "$id" >/dev/null 2>&1 || die "could not remove the previous $name"
    fi
    send_file "$prg" /GARMIN/Apps "$name" || die "copy to the watch failed"
    echo "Copied to GARMIN/Apps/$name. Unplug the watch to install it."
}

# Copies the files of watch folder id $1 listed on stdin as "<id> <NAME>" to $2.
fetch_files() {
    local dest="$1" id file
    mkdir -p "$dest"
    while read -r id file; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        rm -f "$dest/$file"
        if mtp-getfile "$id" "$dest/$file" >/dev/null 2>&1; then
            echo "$dest/$file"
        fi
    done
}

mkdir -p "$OUT"

case "$CMD" in
    build)
        compile -d "$DEVICE" -o "$OUT/$NAME-$DEVICE.prg"
        ;;
    test)
        # The simulator names an app's storage after the first 13 characters of the .prg name, so
        # "bandeja-fr265-test" would share storage with the app build "bandeja-fr265" (and leftover
        # data from one makes the other's writes fail). The "test-" prefix keeps them apart.
        prg="$OUT/test-$DEVICE-$NAME.prg"
        compile -d "$DEVICE" -o "$prg" --unit-test
        # The simulator gets slower with each test run (about 40 s fresh, 170 s on the second run
        # in the same instance), so every run gets a fresh one.
        log="$(mktemp)"
        # A run with no result line never reached the tests (the fresh simulator wasn't ready):
        # try once more. A FAILED run isn't retried.
        for attempt in 1 2; do
            restart_sim || continue
            # monkeydo -t exits 1 even when every test passes (SDK 9.3.0): the result line decides.
            "$SDK/bin/monkeydo" "$prg" "$DEVICE" -t 2>&1 | tee "$log" || true
            grep -q "^PASSED\|^FAILED" "$log" && break
            echo "no test results, retrying ($attempt)" >&2
        done
        if grep -q "^PASSED" "$log"; then
            rm -f "$log"
        else
            rm -f "$log"
            die "unit tests failed"
        fi
        ;;
    run)
        compile -d "$DEVICE" -o "$OUT/$NAME-$DEVICE.prg"
        start_sim || die "simulator did not start"
        "$SDK/bin/monkeydo" "$OUT/$NAME-$DEVICE.prg" "$DEVICE" &
        ;;
    export)
        compile -e -r -o "$OUT/$NAME.iq"
        ;;
    export-beta)
        [[ "$PROJECT" == "$ROOT" ]] || die "export-beta is for the app, not -p $NAME"
        # manifest.xml with the beta's ID and name, and a jungle mirroring monkey.jungle that points
        # back at the sources, all generated in bin/beta. Release mode, as the store build: the beta
        # is what real matches run (speed, battery), so the (:debug) tools (sensor lock fixtures,
        # the match menu's crash item) stay in the sideloaded debug build (deploy).
        beta="$OUT/beta"
        rm -rf "$beta"
        mkdir -p "$beta/resources/strings" "$beta/resources-fre/strings"
        sed -e "s/ id=\"[0-9a-f]\{32\}\"/ id=\"$BETA_ID\"/" -e 's/name="@Strings.AppName"/name="@Strings.BetaAppName"/' \
            "$PROJECT/manifest.xml" >"$beta/manifest.xml"
        grep -q "id=\"$BETA_ID\"" "$beta/manifest.xml" && grep -q "@Strings.BetaAppName" "$beta/manifest.xml" \
            || die "could not make the beta manifest from manifest.xml"
        for res in resources resources-fre; do
            printf '<strings>\n    <string id="BetaAppName">Bandeja beta</string>\n</strings>\n' \
                >"$beta/$res/strings/strings.xml"
        done
        cat >"$beta/monkey.jungle" <<'JUNGLE'
project.manifest = manifest.xml
base.sourcePath = ../../source
base.resourcePath = ../../resources;resources
base.lang.fre = ../../resources-fre;resources-fre
JUNGLE
        # monkey.jungle's device lines: the extra source and resource folders (launcher icon sizes,
        # bundled fonts), seen from bin/beta, and the code left out per watch.
        sed -E -n -e 's#^([a-z0-9]+\.(resource|source)Path = \$\([a-z0-9]+\.(resource|source)Path\));(.*)$#\1;../../\4#p' \
            -e '/^[a-z0-9]+\.excludeAnnotations = /p' "$PROJECT/monkey.jungle" >>"$beta/monkey.jungle"
        JUNGLE="$beta/monkey.jungle"
        compile -e -r -o "$OUT/$NAME-beta.iq"
        echo "Beta package: $OUT/$NAME-beta.iq (app ID $BETA_ID)"
        ;;
    sim)
        start_sim || die "simulator did not start"
        ;;
    deploy)
        compile -d "$DEVICE" -o "$OUT/$NAME-$DEVICE.prg"
        if [[ "$NAME" == "spike" ]]; then
            echo "warning: this replaces the store-installed spike; Connect hides its developer fields until it's reinstalled from the store" >&2
        fi
        deploy_to_watch "$OUT/$NAME-$DEVICE.prg" "$(echo "$NAME" | tr '[:lower:]' '[:upper:]').PRG"
        ;;
    logs)
        mtp_ready
        find_garmin_folders
        [[ "${LOGS_ID:-}" =~ ^[0-9]+$ ]] || die "no GARMIN/Apps/LOGS folder on the watch"
        files_in "$LOGS_ID" "$(mtp-files 2>/dev/null || true)" | fetch_files "$OUT/logs"
        ;;
    fit)
        count="${2:-1}"
        [[ "$count" =~ ^[0-9]+$ ]] || die "fit takes a number of files"
        mtp_ready
        find_garmin_folders
        [[ "${ACTIVITY_ID:-}" =~ ^[0-9]+$ ]] || die "no GARMIN/Activity folder on the watch"
        # Activity files are named by start time, so the newest sort last.
        files_in "$ACTIVITY_ID" "$(mtp-files 2>/dev/null || true)" | sort -k2 | tail -n "$count" \
            | fetch_files "$OUT/fit"
        ;;
    *)
        sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
