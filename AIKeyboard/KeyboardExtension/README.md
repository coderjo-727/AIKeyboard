# Keyboard Extension

This folder contains the custom keyboard extension target. The extension owns
the actual typing surface, preview/review controls, session-only suggestion
memory, and host text mutation through `UITextDocumentProxy`.

Current responsibilities:

- Key input UI
- Collapsed smart preview
- Expanded review panel
- Text context bridging through `UITextDocumentProxy`
- Apply, dismiss, and session-hide correction behavior
- Local-first preview refresh with debounced relay-backed upgrades when Full
  Access and relay configuration are available
