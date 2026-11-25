#!/usr/bin/env bash
# Smoke test of sgc-launch-screensaver and sgc-kill-screensaver with stand-ins for swaymsg, mpv, walker,
# pgrep and pkill. Nothing real is started or killed (no Sway, no mpv, and no screensaver that may be
# running on this machine). Needs jq.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
export LOG="$TMP/calls.log"
BIN="$TMP/bin"
mkdir -p "$BIN" "$HOME/.local/share/sgc-screensaver"
: > "$LOG"

fail() { echo "FAIL: $*" >&2; exit 1; }

# swaymsg: two outputs, "A" is focused; every call is logged
cat > "$BIN/swaymsg" <<'STUB'
#!/bin/sh
echo "swaymsg $*" >> "$LOG"
case "$*" in
  "-t get_outputs -r") echo '[{"name":"A","focused":true},{"name":"B","focused":false}]' ;;
esac
STUB
# pgrep: "is the screensaver already running?" is answered by the file $TMP/running
cat > "$BIN/pgrep" <<'STUB'
#!/bin/sh
[ -e "$RUNNING" ]
STUB
cat > "$BIN/pkill" <<'STUB'
#!/bin/sh
echo "pkill $*" >> "$LOG"
STUB
printf '#!/bin/sh\nexit 0\n' > "$BIN/walker"
chmod +x "$BIN"/*
export RUNNING="$TMP/running"
export PATH="$BIN:$PATH"

LAUNCH="$ROOT/local-bin/sgc-launch-screensaver"
KILL="$ROOT/local-bin/sgc-kill-screensaver"

echo "== --version matches the VERSION line"
want=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$LAUNCH" | head -1)
[ "$("$LAUNCH" --version)" = "sgc-screensaver $want" ] || fail "--version output differs from VERSION"

echo "== a missing video makes the launcher fail without starting anything"
# the user data dir has no sgc.mp4 yet and /usr/share/sgc-screensaver may not exist on this machine
if [ ! -f /usr/share/sgc-screensaver/sgc.mp4 ]; then
  if "$LAUNCH"; then fail "launcher succeeded without a video"; fi
  ! grep -q "exec -- mpv" "$LOG" || fail "mpv was started without a video"
fi

echo "== launcher starts one fullscreen mpv per output and restores the focus"
echo fake > "$HOME/.local/share/sgc-screensaver/sgc.mp4"
: > "$LOG"
"$LAUNCH"
[ "$(grep -c 'exec -- mpv' "$LOG")" = 2 ] || fail "expected one mpv per output (2)"
grep 'exec -- mpv' "$LOG" | grep -q -- '--fullscreen' || fail "mpv is not fullscreen"
grep 'exec -- mpv' "$LOG" | grep -q -- '--wayland-app-id=org.sgc.screensaver' || fail "wrong app id"
grep 'exec -- mpv' "$LOG" | grep -q "$HOME/.local/share/sgc-screensaver/sgc.mp4" || fail "wrong video path"
[ "$(grep 'focus output' "$LOG" | tail -1)" = "swaymsg focus output A" ] || fail "focus was not restored to the first output"

echo "== launcher does nothing when the screensaver is already running"
: > "$LOG"
touch "$RUNNING"
"$LAUNCH"
! grep -q "exec -- mpv" "$LOG" || fail "second mpv started while one is running"
rm "$RUNNING"

echo "== kill script targets only the screensaver's app id and always succeeds"
: > "$LOG"
"$KILL"
grep -qF -- 'pkill -f wayland-app-id=org.sgc.screensaver' "$LOG" || fail "kill script uses a different pattern"

echo "OK"
