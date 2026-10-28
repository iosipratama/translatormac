# Translate Offline

A simple macOS and iPhone app for offline text translation using Apple's on-device translation framework.

### Project layout
One multiplatform target (`TranslatorMac`, bundle ID `iosipratama.TranslatorMac`), so Pro is a universal purchase across Mac and iPhone.
- `Offline Translator/Shared/`: models used by both apps (translation engine, history, Pro, settings keys)
- `Offline Translator/Mac/`: the Mac app's windows, menus and screens; not compiled for iOS
- `Offline Translator/iOS/`: the iPhone app's screens; not compiled for macOS
- `Config/iOS-Info.plist`: Info.plist entries only the iPhone app has, such as the microphone and speech recognition purpose strings

### iPhone design tokens
Colors live in `Assets.xcassets/Palette` with light and dark values; use the generated symbols (`.canvas`, `.textMuted`, …). Some design-spec names would clash with SwiftUI's own (`secondary`, `background`), so they're renamed:

| Spec | Asset / symbol |
|---|---|
| `bg` | `Canvas` / `.canvas` |
| `surface`, `raised` | `Surface`, `Raised` |
| `line`, `line2` | `Line`, `LineStrong` |
| `text`, `secondary`, `muted`, `faint` | `TextPrimary`, `TextSecondary`, `TextMuted`, `TextFaint` |
| `accent` | `AccentColor` (shared with the Mac) |
| `ink` | `OnAccent` (shared with the Mac) |
| `accentText` | `AccentForeground` (shared with the Mac); the app's text tint |
| `accentTint`, `accentTint2` | `AccentTint`, `AccentTintSubtle` |
| `inv`, `onInv` | `Inverse`, `OnInverse` |
| `danger` | `Danger` |

### Features
- Offline translation, powered by Apple's on-device models
- Translates as you type; ⌘↩ translates right away
- Pronunciation for languages written in other scripts, and read-aloud with the system voice
- Recent and Saved translations in the sidebar
- macOS native UI (SwiftUI): sidebar, toolbar language menus, full menu-bar commands
- Everything unlocked for the first 3 days after the first launch; then free with 5 translations a day. Pro (lifetime or yearly) removes the limit and unlocks Best quality, pronunciation and read-aloud, and Saved phrases, each marked with a PRO tag (`ProTag`) on the free plan
- Recent keeps every translation on every plan, until it's cleared
                        
### Requirements
- macOS 26+
- On-device language models installed, from System Settings or the app's own download prompt
- Settings › General › Quality picks the models, both offline (`TranslationQuality`):
  - Fast (default): the downloaded per-language models (`.lowLatency`)
  - Best quality: Apple Intelligence (`.highFidelity`), every language with no downloads but slower; needs macOS 26.4 and Apple Intelligence turned on


### In-app purchases
- Pro is offered as a choice of plans, listed in `PurchaseStore.offeredPlans`; each plan's product is in `ProPlan`
  - Lifetime, listed first: `iosipratama.TranslatorMac.pro` (non-consumable, the original product)
  - Yearly: `iosipratama.TranslatorMac.pro.yearly` (auto-renewable subscription)
  - Weekly is defined but not offered: `iosipratama.TranslatorMac.pro.weekly`
- Any active plan unlocks Pro; anyone whose original download is older than 1.2, the first free version, gets Pro automatically
- `PurchaseStore.access` (`PlanAccess`) is what every gate asks: Pro, the free days, or the free plan
  - The free days (`FreeAccessPeriod`, `PlanLimits.freeAccessDays`) start at the first launch, recorded in this device's Keychain (`FirstLaunchRecord`) so a reinstall doesn't restart them; nothing leaves the device
  - The iPhone follows the same rules: PRO tags on Read Aloud, pronunciation, the star and Best quality, the free days notice (`FreeAccessNoticeSheet`), and the free days in Settings and the paywall. Its Debug screen (Settings › Debug) has the same testing tools as the Mac's menu
  - Debug builds have a Debug menu in the menu bar (`DebugCommands`): force Pro or Free, jump to any day, restart the free days, show the upgrade screen or either free-days notice, replay onboarding, use up or reset today's free translations, simulate a Mac without Apple Intelligence, and request or reset the rating prompt. Settings › Pro shows the same basics at the bottom
- A translation counts toward the daily limit once it's finished (⌘↩, Copy, Speak, Save, or a 2-second pause), once per text (`TextSession`)
- On the last free day a one-time notice (`FreeAccessNotice`) compares Free and Pro; feature lists come from `PlanFeatures`, matching the website
- A rating is requested from the 10th finished translation or 3rd saved phrase, never after the limit or the Pro sheet, once per version (`ReviewRules`)
- Tests: `bitrig test -scheme TranslatorMac` runs the `TranslatorTests` target (`Tests/`), including StoreKit purchases against `Translate Offline.storekit`
- `Translate Offline.storekit` lets local runs buy either plan without App Store Connect; its prices are placeholders
