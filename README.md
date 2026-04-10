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

## MVP Goals

The MVP focuses on a conservative correction experience inside a custom keyboard
extension:

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

## Local Scaffold

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
docs/
```

`AIKeyboardCore` is a Swift package that holds the reusable logic we can test
before wiring up the iOS app and keyboard extension targets.

## Documents

- [`docs/mvp-implementation-plan.md`](/Users/inci/Documents/New%20project/docs/mvp-implementation-plan.md)
- [`docs/product-spec.md`](/Users/inci/Documents/New%20project/docs/product-spec.md)

## Current Status

This repository now contains a buildable Xcode app target, a buildable custom
keyboard extension target, and a testable shared Swift package for sentence
extraction, conservative correction gating, diff rendering, safe replacement
planning, and session-only adaptation behavior. The current local baseline is a
coherent MVP scaffold and close to a good first GitHub push.
