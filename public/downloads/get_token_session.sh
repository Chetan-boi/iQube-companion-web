#!/bin/zsh
# get_token_session.sh — read the four session values iQube Companion needs from your own Android phone.
#
#   AccessToken, RefreshToken, userid (evUserId), userVehicleid
#
# How it works: the official TVS Connect Android app writes these values to the phone's system log
# when its dashboard loads. This script restarts the app over USB, waits for the dashboard, reads the
# log, and then (by default) hands the values straight to iQube Companion without ever showing them.
#
# Requirements: an Android phone with TVS Connect signed in, USB debugging enabled, and `adb`
# (brew install android-platform-tools). Use it only with your own account.
#
# Usage:
#   ./get_token_session.sh            # import straight into iQube Companion (recommended)
#   ./get_token_session.sh --print    # print the four values instead, to paste into Settings yourself
set -euo pipefail

PKG="com.tvsm.connect"
APP="/Applications/iQube Companion.app"
BIN="$APP/Contents/MacOS/iQube Companion"
TIMEOUT=120
MODE="import"
[[ "${1:-}" == "--print" ]] && MODE="print"

bold() { print -P "%B$1%b"; }
fail() { print -P "%F{red}Error:%f $1" >&2; exit 1; }

bold "iQube Companion — session helper"
echo "This reads your own TVS Connect session from your phone. Treat the values like a password."
echo

command -v adb >/dev/null 2>&1 || fail "adb not found. Install it with:  brew install android-platform-tools"

STATE="$(adb get-state 2>/dev/null || true)"
case "$STATE" in
  device) ;;
  unauthorized) fail "Phone is connected but not authorised. Unlock it and tap Allow on the USB debugging prompt, then run this again." ;;
  *) fail "No phone found. Connect it with a USB cable, enable USB debugging (Settings > Developer options), and run this again." ;;
esac

adb shell pm list packages 2>/dev/null | grep -q "package:$PKG" \
  || fail "TVS Connect is not installed on this phone."

if [[ "$MODE" == "import" && ! -x "$BIN" ]]; then
  fail "iQube Companion is not in /Applications. Install it first, or run with --print."
fi

# Private temp file, removed on exit no matter what.
umask 077
LOG="$(mktemp -t tvs-session)"
cleanup() { rm -f "$LOG"; adb logcat -c >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

echo "1. Unlock your phone and keep it unlocked."
echo "2. Restarting TVS Connect on the phone..."
adb logcat -c
adb shell am force-stop "$PKG"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
  || fail "Could not open TVS Connect on the phone."
echo "3. Wait for the dashboard to show your battery level (up to ${TIMEOUT}s)..."

# Stream the log until all four values have appeared, or time out.
adb logcat > "$LOG" 2>/dev/null &
LOGCAT_PID=$!
trap 'kill $LOGCAT_PID 2>/dev/null; cleanup' EXIT INT TERM

ACCESS="" REFRESH="" USERID="" VEHICLE=""
for (( i = 0; i < TIMEOUT; i += 2 )); do
  sleep 2
  ACCESS="$(grep -oE 'AccessToken: eyJ[A-Za-z0-9._-]+' "$LOG" | tail -1 | cut -d' ' -f2 || true)"
  REFRESH="$(grep -oE 'RefreshToken: eyJ[A-Za-z0-9._-]+' "$LOG" | tail -1 | cut -d' ' -f2 || true)"
  USERID="$(grep -oE 'evUserId: [0-9]+' "$LOG" | tail -1 | awk '{print $NF}' || true)"
  VEHICLE="$(grep -oE 'fetchingDataFor[^:]*: [0-9]+' "$LOG" | tail -1 | awk '{print $NF}' || true)"
  [[ -n "$ACCESS" && -n "$REFRESH" && -n "$USERID" && -n "$VEHICLE" ]] && break
  (( i % 10 == 0 )) && printf "   still waiting... (%ds)\n" "$i"
done
kill $LOGCAT_PID 2>/dev/null || true

missing=()
[[ -z "$ACCESS"  ]] && missing+=("AccessToken")
[[ -z "$REFRESH" ]] && missing+=("RefreshToken")
[[ -z "$USERID"  ]] && missing+=("userid")
[[ -z "$VEHICLE" ]] && missing+=("userVehicleid")
if (( ${#missing[@]} )); then
  fail "Did not find: ${missing[*]}. Make sure the phone stays unlocked and the TVS Connect dashboard fully loads, then try again."
fi

echo
bold "Found all four values."
printf "   AccessToken    %d characters\n" "${#ACCESS}"
printf "   RefreshToken   %d characters\n" "${#REFRESH}"
printf "   userid         %s\n" "$USERID"
printf "   userVehicleid  %s\n" "$VEHICLE"
echo

if [[ "$MODE" == "print" ]]; then
  bold "Paste these into iQube Companion > Settings > TVS session:"
  echo "AccessToken:   $ACCESS"
  echo "RefreshToken:  $REFRESH"
  echo "userid:        $USERID"
  echo "userVehicleid: $VEHICLE"
  echo
  echo "Clear your terminal afterwards (Cmd+K) so the tokens are not left on screen."
  exit 0
fi

pkill -x "iQube Companion" 2>/dev/null || true
sleep 1
printf '%s\n%s\n%s\n%s\n' "$ACCESS" "$REFRESH" "$USERID" "$VEHICLE" | "$BIN" --import-credentials >/dev/null \
  || fail "Could not save the session to the Keychain."
open "$APP"
bold "Done. The session is saved in your Keychain and iQube Companion has restarted."
echo "Your battery level should appear in the menu bar within a few seconds."
echo "The temporary log has been deleted and the phone's log cleared."
