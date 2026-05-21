# Whisp

Whisp is a free, MIT-licensed macOS menubar app for fast voice-to-text.
Press Control Option Space, talk, and Whisp transcribes with the built-in macOS
Speech framework, copies the finished text, and can paste it back into the app
you were using.

## Features

- Native macOS menubar app with no Dock icon
- Control Option Space global dictation hotkey
- macOS Speech Recognition and microphone permission flow
- Live transcript preview
- Auto-copy and optional auto-paste
- Recent transcript history
- Launch at login
- Sparkle-ready update plumbing with cache-busted appcast checks
- Gravy-style promo site with download gate, MIT badge, Cash App tip, and Sponsor links

## Build

```bash
./scripts/build.sh
```

The app is written in Swift and SwiftUI, and the project is generated from
`project.yml` using xcodegen.

## Release

```bash
./scripts/release.sh 1.0.0 '<ul><li><strong>Initial release.</strong> Native macOS dictation from the menu bar.</li></ul>'
```

Before a public release, generate or paste the real Sparkle public key into
`project.yml` at `SUPublicEDKey`, create the GitHub repository, then deploy
`website/` to Cloudflare Pages as `whisp`.

Current Pages URL: https://whisp-buz.pages.dev/

Current direct DMG URL: https://whisp-buz.pages.dev/Whisp.dmg
