# Refine Keyboard ✨

**[Refine](https://github.com/AnandaDwiprayoga/Refine-Popclip) on your iPhone, as a keyboard.**

Type a rough draft in Bahasa Indonesia, Indonesian chat slang or broken English with Apple's keyboard. Then switch to the Refine keyboard with 🌐 and tap a style. You get natural English in your own voice, and **Replace** swaps it in. 🇮🇩 does the reverse: it translates a message someone sent you into Bahasa Indonesia.

```
you type:   bro sorry telat, td aku cek api nya masih error 500, mungkin dr BE side ya?
✨ gives:   Sorry for the late reply! I just checked and the API is still returning a 500.
            Could it be on the BE side?
```

This is a personal build, installed with a free Apple ID through [SideStore](https://sidestore.io). It isn't on the App Store.

## Buttons

| Button | What it does |
|---|---|
| ✨ My style | Rewrites in your own voice, using your style profile |
| 🙏 Polite | Softer and more diplomatic |
| ✂️ Short | As concise as possible, keeps every fact |
| ✅ Fix | Translates Bahasa and fixes grammar, keeps your wording |
| 🇮🇩 Bahasa | Translates into Bahasa Indonesia. Never replaces anything |

- **What a button acts on:** the selected text if there is any, otherwise the text before the cursor. 🇮🇩 uses the selection, otherwise **the clipboard**. To read a Slack message in Bahasa, copy it and tap 🇮🇩 in any text field.
- **Replace** puts the rewrite in place of the original. **Undo** puts the original back, as long as you haven't moved the cursor.
- **Copy** copies the result. For 🇮🇩, **Insert** types the translation at the cursor.
- The top line always says what will be used ("Selected · 84 chars"). Some apps only give a keyboard part of a long text, so for long drafts use **Select All** first.
- ⚙ holds the settings: your Groq key and "Never send these words".

## How it relates to refine-popclip

The prompts, style profile and privacy guard are **not copied** here. `Vendor/refine-popclip` is a git submodule of the Mac repo, and the keyboard runs its exact `prompt.js` and `redact.js` in JavaScriptCore, through the shared `RefineCore` Swift package in that repo. Tune a prompt once on the Mac with `node test/run.mjs`, and the keyboard picks it up on the next build.

Your personal `local.config.js` (style profile, hidden words, link schemes) is gitignored in refine-popclip, so the submodule doesn't have it. The build copies it from your normal Mac checkout, `../refine-popclip/Refine.popclipext/local.config.js` by default. Change the path in `Local.xcconfig`.

To pull in Mac-side improvements:

```bash
git submodule update --remote Vendor/refine-popclip
```

Then rebuild, and commit the new submodule commit.

## Requirements

- A Mac with **Xcode** (26 or later) and **XcodeGen**: `brew install xcodegen`
- **Node.js** (optional, checks the JS for typos at build time)
- An iPhone on iOS 17 or later, and a free Apple ID
- A free **Groq API key** from [console.groq.com/keys](https://console.groq.com/keys)

## Get the code

```bash
git clone --recurse-submodules https://github.com/AnandaDwiprayoga/Refine-Keyboard-Iphone.git
cd Refine-Keyboard-Iphone
cp Local.example.xcconfig Local.xcconfig   # optional: bundle ID prefix, local.config.js path
```

## Develop in the Simulator

```bash
./build.sh --sim
```

This builds, installs and launches the app in the iOS Simulator; `SIM_DEVICE="iPhone 17 Pro"` picks another device. Then in the Simulator:

1. In the Refine app, tap **Open Settings** → **Keyboards** → turn on **Refine** and **Allow Full Access**.
2. Back in Refine, tap the "Try it" box. If no on-screen keyboard appears, press ⌘K in the Simulator.
3. Switch to Refine with 🌐. Copy your key on the Mac (the Simulator shares the clipboard), then tap ⚙ → **Paste key** → **Allow Paste**.

`./build.sh` with no flag generates `Refine.xcodeproj` and opens it in Xcode. The project is generated from `project.yml`, so edit that file, not the project.

## Install on your iPhone with SideStore

Apps signed with a free Apple ID stop opening after 7 days. SideStore re-signs them on the iPhone itself, so you don't need the Mac each week. Check [docs.sidestore.io](https://docs.sidestore.io) if a step below has changed.

### One-time setup

1. **iPhone:** Settings → Privacy & Security → **Developer Mode** → on (the iPhone restarts).
2. **iPhone:** install **LocalDevVPN** from the App Store. SideStore uses it to talk to the iPhone itself. It doesn't route your internet traffic.
3. **Mac:** download **[iloader](https://github.com/nab138/iloader)**. Connect the iPhone by USB and tap **Trust** on it. In iloader, sign in with your Apple ID, then let it install SideStore and its pairing file.
4. **iPhone:** Settings → General → VPN & Device Management → your Apple ID → **Trust**.
5. **iPhone:** open SideStore and sign in with the same Apple ID.

### Install Refine

1. **Mac:**
   ```bash
   ./build.sh --ipa
   ```
   This makes an unsigned `build/Refine.ipa`. SideStore signs it with your Apple ID.
2. AirDrop `build/Refine.ipa` to the iPhone, or save it to Files.
3. **iPhone:** turn on LocalDevVPN → SideStore → **My Apps** → **+** → pick `Refine.ipa`. When it asks about app extensions, **keep them**: the extension is the keyboard.
4. Open **Refine** → **Open Settings** → **Keyboards** → turn on **Refine** and **Allow Full Access**.
5. Copy your Groq key. In the Refine app's "Try it" box, switch to the Refine keyboard → ⚙ → **Paste key** → **Allow Paste** → **Clear clipboard**.

### Keep it alive (every 7 days)

- **Automatic:** Shortcuts → Automation → **+** → Time of Day (e.g. daily 09:00) → **Run Immediately**. Add the actions *LocalDevVPN: Connect* and *SideStore: Refresh All Apps*.
- **Manual:** open SideStore with LocalDevVPN on and tap **Refresh All** at least once a week.
- If it lapses, Refine won't open (the keyboard stops appearing) until you refresh. Your key and settings are kept.

### Update after changing code or prompts

Run `./build.sh --ipa` again and install the new `Refine.ipa` in SideStore the same way. It updates in place and keeps your key.

### Free Apple ID limits

- **3 active apps,** and SideStore is one of them. The Refine app and its keyboard use the other two (each app extension counts), so there's no room for a third sideloaded app.
- **10 new App IDs per 7 days.** A fresh install of Refine uses 2; updating it uses none.
- Don't also install Refine from Xcode onto the phone while SideStore has it. It would take 2 more slots. Test in the Simulator instead.
- **LiveContainer** (the usual way around the 3-app limit) can't host keyboards, so install Refine directly in SideStore.
- A paid Apple Developer account ($99/year) removes the 7-day and 3-app limits.

## Privacy

- **Nothing is sent while you type.** Only when you tap a style button is that text sent to Groq, and only after the privacy guard from refine-popclip has replaced links, emails, keys, passwords, phone and card numbers, code and your hidden words with placeholders. If the model drops a placeholder, the result is thrown away and never shown.
- **Why Full Access:** iOS blocks a keyboard from the network and the clipboard without it. Refine uses the network only for that one request to `api.groq.com`, and the clipboard only when you tap 🇮🇩, Copy or Paste key/list. iOS asks before each clipboard read.
- **Your key** is stored in the keyboard's keychain on this iPhone only (not synced, not shared with the host app). Remove it from ⚙.
- **Groq data controls:** turn off data retention under Settings → Data Controls at console.groq.com.
- Text you refine could contain instructions aimed at the model. The prompt treats it as data only, and Replace always shows you the result first.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Allow Full Access to use Refine" | Settings → General → Keyboard → Keyboards → Refine → Allow Full Access. |
| "Groq rejected the key" | Copy a fresh key from console.groq.com/keys → ⚙ → Paste key. |
| Refine doesn't appear when I tap 🌐 | Some fields (passwords, phone numbers) and some apps block third-party keyboards. Or the 7-day signature lapsed: refresh in SideStore. |
| Replace says "The text changed" | Tap the style again. Refine only replaces text it has seen, so a draft you edited after tapping isn't overwritten. |
| Only part of my text was refined | That app gives keyboards only part of the text before the cursor. Select All first, then tap the style. |
| My style doesn't sound like me | The build didn't find your `local.config.js`. Look for "Bundled your local.config.js" in the build log, or set `REFINE_LOCAL_CONFIG` in `Local.xcconfig`. |
| Emoji show as boxes in the Simulator | A Simulator font issue. They show normally on the iPhone. |

## Project structure

```
refine-keyboard/
├── Vendor/refine-popclip/     # git submodule: prompt.js, redact.js, RefineCore Swift package
├── project.yml                # XcodeGen spec (the .xcodeproj is generated and gitignored)
├── Config/Base.xcconfig       # defaults; includes your gitignored Local.xcconfig
├── Local.example.xcconfig     # template for bundle ID prefix, team, local.config.js path
├── build.sh                   # --sim | --ipa | open in Xcode
├── HostApp/                   # the one-screen setup app iOS requires around a keyboard
└── Keyboard/                  # the keyboard extension
    ├── KeyboardViewController.swift  # UIInputViewController hosting the SwiftUI view
    ├── KeyboardView.swift            # buttons, preview, settings panel
    ├── KeyboardModel.swift           # source text, refine/translate, Replace/Undo
    └── SettingsStore.swift           # API key (keychain) and hidden words
```

## License

[MIT](LICENSE), same as refine-popclip.
