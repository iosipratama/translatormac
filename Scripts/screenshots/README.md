# App Store screenshots

`capture.sh` takes the six App Store screenshots from a Debug build:

```sh
bitrig build -destination generic/platform=macOS
Scripts/screenshots/capture.sh dark            # 1-translate-without-internet.png, …
Scripts/screenshots/capture.sh light           # 1-translate-without-internet-light.png, …
Scripts/screenshots/capture.sh light ~/Pictures/shots   # another folder
```

Files go to `~/Desktop/translate-screenshots` unless you name a folder. Each is the
full window at 1000×587 points (2000×1174 pixels), with rounded corners on a
transparent background:

| File | Screen |
|---|---|
| `1-translate-without-internet` | English → Japanese: hotel Wi-Fi request |
| `2-your-words-stay-on-your-mac` | Japanese → English: a clinic's appointment confirmation |
| `3-say-it-right` | English → Japanese: shellfish allergy, with pronunciation |
| `4-every-translation-kept` | Recent, German → English entry selected |
| `5-saved-phrases` | Saved, Kyoto taxi phrase selected |
| `6-made-for-mac` | English → German with the Translation menu open (2010 wide: the menu overhangs the window) |
| `6-made-for-mac-no-menu` | The same screen without the menu |

## How it works

The script launches the app with `-screenshotMode YES`. In Debug builds that
unlocks Pro, lets the window shrink to 1000×587, and fills Recent and Saved with
a sample week of travel kept in memory, so your real history is untouched. The
sample trip lives in `Offline Translator/ScreenshotMode.swift`; the sentences
typed on the Translate screens live in `capture.sh`. Release builds ignore the flag.

## Before running

- French, German and Japanese downloaded in System Settings › General ›
  Language & Region › Translation Languages.
- Accessibility and Screen Recording access for the app running the script.
- Leave the Mac alone while it runs (about two minutes): it pastes text and
  opens menus. It restores your clipboard and light/dark setting afterwards.
