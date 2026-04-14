# AI Keyboard

Privacy-first, UI-first, sentence-scoped AI correction for iOS.

## Product Summary

AI Keyboard is an iOS custom keyboard that previews spelling, grammar, and
punctuation corrections before the user applies them. It is designed around
control, transparency, and privacy:

- No automatic replacements
- Sentence-scoped suggestions by default
- Visual diffs for every proposed change
- Session-only adaptation in memory
- No persistent storage of raw text or user profiles

## Product Goals

The current alpha focuses on a conservative correction experience inside a
custom keyboard extension:

- Detect the active sentence from keyboard text context
- Show a collapsed smart preview above the keys
- Highlight spelling, punctuation, replacement, and deletion changes
- Expand into a review panel with apply, dismiss, and session-hide actions
- Preserve slang, tone, and user intent
- Keep all adaptation ephemeral and memory-only

## Platform Constraints

- iOS custom keyboard extension
- Text access is limited to `documentContextBeforeInput` and
  `documentContextAfterInput`
- No access to send events or full host app lifecycle
- Must follow Apple Human Interface Guidelines for custom keyboards

## Correction Rules

The correction engine may:

- Fix spelling
- Fix grammar
- Fix punctuation

The correction engine must not:

- Rewrite phrasing
- Change tone
- Normalize slang
- Perform style improvement

Silence is better than low-confidence suggestions.

## Local Architecture

The repo now includes a local-first scaffold:

```text
AIKeyboard/
  Package.swift
  App/
  KeyboardExtension/
  Sources/
    AIKeyboardCore/
  Tests/
    AIKeyboardCoreTests/
```

`AIKeyboardCore` is a Swift package that holds reusable correction logic shared
by the iOS app and keyboard extension targets.

## Current Status

This repository contains a buildable Xcode app target, a buildable custom
keyboard extension target, and a testable shared Swift package for sentence
extraction, conservative correction gating, diff rendering, safe replacement
planning, session-only adaptation behavior, and relay-aware provider selection.
The current state is an early working alpha, not a placeholder scaffold.

## Test Locally

### Swift Package Tests

From the shared package directory:

```bash
cd AIKeyboard
swift test
```

This runs the pure logic coverage for:

- sentence extraction
- diff rendering
- conservative correction gating
- overlap-safe replacement planning

### Xcode Build

To confirm the app target and keyboard extension both compile:

```bash
xcodebuild \
  -project 'AIKeyboard/AIKeyboard.xcodeproj' \
  -scheme AIKeyboard \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Or open the project in Xcode:

```bash
open AIKeyboard/AIKeyboard.xcodeproj
```

Then choose the `AIKeyboard` scheme and build with `Product > Build`.

## Deploy To A Device

### 1. Open The Project

Open [`AIKeyboard.xcodeproj`](AIKeyboard/AIKeyboard.xcodeproj) through Xcode
and select the `AIKeyboard` app target.

### 2. Configure Signing

In Xcode:

- select the `AIKeyboard` target
- open `Signing & Capabilities`
- choose your Apple Developer team
- repeat the same step for `AIKeyboardExtension`

If the bundle identifiers conflict with another local app, change them to a
unique reverse-DNS value for both targets.

### 3. Run On An iPhone Or iPad

- connect a physical device
- trust the computer on the device if prompted
- choose the device as the run destination in Xcode
- run the `AIKeyboard` scheme

The container app is the installation, runtime status, and privacy shell. The
custom keyboard experience lives in the extension target embedded inside it.

## Enable The Keyboard On iOS

After the app is installed on the device:

1. Open `Settings > General > Keyboard > Keyboards`.
2. Tap `Add New Keyboard...`.
3. Select `AIKeyboard`.
4. Open the `AIKeyboard` entry in the keyboard list.
5. Enable `Allow Full Access` if you want relay-backed correction inside the
   keyboard extension.

The product now supports an optional relay-backed correction path, but it still
falls back to the built-in local provider when no relay is configured or when
the relay is unavailable.

## Manual Testing Flow

Once the keyboard is enabled:

1. Open Notes, Messages, or another editable text field.
2. Switch to `AIKeyboard`.
3. Type a sentence such as `i has a apple`.
4. Confirm the collapsed preview appears only when the suggestion is
   conservative.
5. Open `Review` and verify the diff cards and suggestion chips.
6. Use `Not Now` and confirm the suggestion hides temporarily.
7. Use `Hide This Session` and confirm the same suggestion does not resurface
   during the current keyboard session.
8. Use `Apply` and confirm the corrected text replaces only the safe prefix
   before the cursor.
9. Dismiss the keyboard, reopen it, and confirm session-only memory resets.

## Known Alpha Limits

- Without a configured relay, the correction engine is still rule-based and
  intentionally conservative.
- The keyboard only applies replacements when the text after the cursor already
  matches the corrected ending.
- Relay configuration is currently build-time / scheme-time rather than a
  polished user-facing account setup flow.

## Development Relay

The shared core now includes:

- [`OpenAICorrectionProvider.swift`](AIKeyboard/Sources/AIKeyboardCore/OpenAICorrectionProvider.swift)
  for direct development-only OpenAI calls
- [`RelayCorrectionProvider.swift`](AIKeyboard/Sources/AIKeyboardCore/RelayCorrectionProvider.swift)
  for calling your own backend relay
- [`openai_relay.py`](server/openai_relay.py)
  as a tiny local relay example that keeps the OpenAI API key off the app
- [`server/README.md`](server/README.md)
  for relay runtime, Docker, and deployment notes

To run the sample relay locally:

```bash
export OPENAI_API_KEY="your_openai_api_key"
export AIKEYBOARD_RELAY_TOKEN="choose_a_shared_secret"
python3 server/openai_relay.py
```

It listens on:

```text
http://127.0.0.1:8787/v1/corrections
```

Optional relay environment variables:

- `AIKEYBOARD_RELAY_HOST`, default `127.0.0.1`
- `AIKEYBOARD_RELAY_PORT`, default `8787`
- `AIKEYBOARD_OPENAI_MODEL`, default `gpt-5.4-mini`
- `AIKEYBOARD_OPENAI_TIMEOUT`, default `20`
- `AIKEYBOARD_RATE_LIMIT_PER_MINUTE`, default `60`

Important: this relay is a development bridge. For a real gamma or production
deployment, host the relay on your own backend and keep the OpenAI API key on
the server only.

To let the app or keyboard discover a relay without hardcoding it in source,
provide either:

- `AIKEYBOARD_RELAY_ENDPOINT` and optional `AIKEYBOARD_RELAY_TOKEN` in the run
  scheme environment
- `AIKeyboardRelayEndpoint` and optional `AIKeyboardRelayToken` in the target
  `Info.plist`

For keyboard-side relay use on iOS, the keyboard extension must also have Full
Access enabled by the user.

Relay endpoints should use HTTPS. Plain HTTP is only accepted for local
development hosts such as `localhost` and `127.0.0.1`.
