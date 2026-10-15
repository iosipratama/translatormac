#!/bin/zsh
# Captures the App Store screenshots from a Debug build in screenshot mode
# (see ScreenshotMode.swift): Pro unlocked, a sample trip in Recent and Saved,
# and the window at 1000×587.
#
# usage: Scripts/screenshots/capture.sh [dark|light] [output folder]
#   dark  (default) writes 1-translate-without-internet.png, …
#   light           writes 1-translate-without-internet-light.png, …
#
# Build first with `bitrig build -destination generic/platform=macOS`.
# Needs French, German and Japanese downloaded in System Settings, and
# Accessibility and Screen Recording access for the app running this script.
# Your clipboard and system appearance are restored afterwards.
set -e

MODE=${1:-dark}
OUT=${2:-$HOME/Desktop/translate-screenshots}
[[ $MODE == light ]] && SUFFIX=-light || SUFFIX=
HERE=${0:A:h}
WORK=$(mktemp -d)
APP=${APP:-$(ls -td ~/Library/Bitrig/Users/*/Builds/*/DerivedData/Build/Products/Debug/"Translate Offline.app" 2>/dev/null | head -1)}
[[ -d $APP ]] || { echo "No Debug build found; run bitrig build first, or set APP=/path/to/Translate Offline.app"; exit 1 }
mkdir -p "$OUT"

echo "Compiling the window capture helper…"
swiftc -O "$HERE/WindowShot.swift" -o "$WORK/WindowShot" 2>/dev/null

CLIPBOARD=$(pbpaste)
SYSTEM_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
PID=
cleanup() {
    [[ -n $PID ]] && kill $PID 2>/dev/null
    printf '%s' "$CLIPBOARD" | pbcopy
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $SYSTEM_DARK"
    rm -rf "$WORK"
}
trap cleanup EXIT

# Everything below talks to the Debug build by process ID, never by name, so
# a copy installed in /Applications is never touched.
app() { osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID)" "$@" -e 'end tell' >/dev/null }
front() { osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PID) to true"; sleep 0.6 }

# Starts a fresh copy (the text box has focus right after launch) at 1000×587.
launch() {
    [[ -n $PID ]] && { kill $PID 2>/dev/null; sleep 1.5 }
    "$APP/Contents/MacOS/Translate Offline" -screenshotMode YES -translationQuality fast -appearance $MODE \
        -sourceLanguage $1 -targetLanguage $2 -liveTranslate YES -showPronunciation YES >/dev/null 2>&1 &
    PID=$!
    sleep 5
    front
    app -e 'set position of front window to {200, 120}' -e 'set size of front window to {1000, 587}'
}

# Pastes rather than types, so Caps Lock and keyboard layouts can't change the text.
translate() {
    front
    printf '%s' "$1" | pbcopy
    app -e 'keystroke "a" using command down' -e 'key code 51' -e 'keystroke "v" using command down' \
        -e 'delay 0.6' -e 'key code 36 using command down'
    sleep 9
}

shot() { front; "$WORK/WindowShot" $PID "$OUT/$1$SUFFIX.png" }

ROWS='outline 1 of scroll area 1 of group 2 of splitter group 1 of group 1 of front window'
select_row() { app -e "set selected of row $1 of $ROWS to true"; sleep 1.5 }

echo "1/6 Translate without internet"
launch en ja
translate "Hi, I'm in room 1204 and the Wi-Fi hasn't worked since last night, so could someone please take a look before my video call tomorrow morning?"
shot 1-translate-without-internet

echo "2/6 Your words stay on your Mac"
launch ja en
translate "診察のご予約は明日午前10時で承りました。当日は保険証とお薬手帳をお持ちのうえ、受付までお越しください。"
shot 2-your-words-stay-on-your-mac

echo "3/6 Say it right"
launch en ja
translate "I have a severe shellfish allergy, so could you tell me whether this dish contains any shrimp or crab?"
shot 3-say-it-right

echo "4/6 Every translation, kept"
launch en ja
app -e 'keystroke "2" using command down'; sleep 2
select_row 9    # the German key-box message
shot 4-every-translation-kept

echo "5/6 Saved phrases"
app -e 'keystroke "3" using command down'; sleep 2
select_row 3    # the Kyoto taxi phrase, with pronunciation
shot 5-saved-phrases

echo "6/6 Made for Mac"
launch en de
translate "Could you recommend a quiet restaurant near the hotel where we could have a business dinner for four on Friday evening?"
shot 6-made-for-mac-no-menu
# Menu bar menus follow the system appearance, not the app's, so match it
# for this shot. The window sits right under the menu so it covers the sidebar.
osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $([[ $MODE == dark ]] && echo true || echo false)"
sleep 2
app -e 'set position of front window to {304, 31}'
front
app -e 'ignoring application responses' -e 'click menu bar item "Translation" of menu bar 1' -e 'end ignoring'
sleep 2
shot 6-made-for-mac
app -e 'key code 53'

echo "Done: $OUT"
