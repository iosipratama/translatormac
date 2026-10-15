# Translate Offline

A simple macOS app for offline text translation using Apple's on-device translation framework.

### Features
- Offline translation, powered by Apple's on-device models
- Translates as you type; ⌘↩ translates right away
- Pronunciation for languages written in other scripts, and read-aloud with the system voice
- Recent and Saved translations in the sidebar
- macOS native UI (SwiftUI): sidebar, toolbar language menus, full menu-bar commands
- Free with 10 translations a day; a one-time Pro purchase removes the limit
                        
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
