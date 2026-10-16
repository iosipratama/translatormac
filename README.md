# Translate Offline

A simple macOS and iPhone app for offline text translation using Apple's on-device translation framework.

### Project layout
One multiplatform target (`TranslatorMac`, bundle ID `iosipratama.TranslatorMac`), so Pro is a universal purchase across Mac and iPhone.
- `Offline Translator/Shared/`: models used by both apps (translation engine, history, Pro, settings keys)
- `Offline Translator/Mac/`: the Mac app's windows, menus and screens; not compiled for iOS
- `Offline Translator/iOS/`: the iPhone app's screens; not compiled for macOS

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
- Free with 5 translations a day; Pro (yearly or lifetime) removes the limit
                        
### Requirements
- macOS 26+
- On-device language models installed, from System Settings or the app's own download prompt
- Settings › General › Quality picks the models, both offline (`TranslationQuality`):
  - Fast (default): the downloaded per-language models (`.lowLatency`)
  - Best quality: Apple Intelligence (`.highFidelity`), every language with no downloads but slower; needs macOS 26.4 and Apple Intelligence turned on


### In-app purchases
- Pro is offered as a choice of plans, listed in `PurchaseStore.offeredPlans`; each plan's product is in `ProPlan`
  - Lifetime: `iosipratama.TranslatorMac.pro` (non-consumable, the original product)
  - Yearly: `iosipratama.TranslatorMac.pro.yearly` (auto-renewable subscription)
  - Weekly is defined but not offered: `iosipratama.TranslatorMac.pro.weekly`
- Any active plan unlocks Pro; anyone whose original download is older than 1.2, the first free version, gets Pro automatically
- `Translate Offline.storekit` lets local runs buy either plan without App Store Connect; its prices are placeholders
