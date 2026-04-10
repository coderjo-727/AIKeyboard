# Product Spec

## One-Line Identity

"A privacy-first iOS keyboard that visually previews AI corrections so users
stay in control of how they sound."

## Product Overview

The product is an iOS custom keyboard that previews AI-assisted corrections in
real time. The user sees what changed before anything is applied.

## Core Principles

1. User control over automation
2. UI-first transparency
3. Sentence-scoped accuracy
4. Privacy by architecture
5. Respect for informal language and cultural fluency

## UX States

### Idle Typing

The user types normally with no interruption.

### Collapsed Smart Preview

Shown only when confident corrections exist.

- Height: roughly autocomplete-bar sized
- Placement: above key rows
- Content: corrected active sentence with inline highlights
- Controls: chevron expand, optional apply action

### Expanded Review

Opened from the chevron for fuller inspection.

- Expands upward within keyboard space
- May partially or fully replace visible keys
- Shows scrollable corrected content with highlighted diffs
- Offers `Apply` and `Cancel`

### Apply or Cancel

- `Apply` commits accepted corrections into the host text field
- `Cancel` dismisses the review UI and returns to typing

## Correction Scope

Allowed:

- Spelling fixes
- Grammar fixes
- Punctuation fixes

Not allowed:

- Rewriting
- Tone shifting
- Style polishing
- Slang normalization

## Confidence Gating

A suggestion should only appear when:

- The correction is unambiguous
- Confidence is above a threshold
- Similar corrections have not already been rejected in the same session

## Privacy Model

Allowed during the active session only:

- Token frequency counts
- Repeated abbreviations
- Casing patterns
- Emoji usage
- Accept and reject signals

Not stored:

- Raw text
- Sentence history
- Profiles
- Cross-session preferences
- Cloud logs tied to user content

All session data should be cleared when:

- The keyboard is dismissed
- The app backgrounds
- The device locks

## Performance Targets

- Debounce correction work by about 300 to 500 ms
- Limit analysis to the active sentence or very recent local context
- Handle obvious local typos immediately when possible
- Avoid visible typing lag

## MVP In Scope

- Custom keyboard extension
- Collapsed sentence preview
- Highlighted diffs
- Expanded review mode
- Apply and cancel actions
- Session-only adaptation
- Conservative correction policy

## Explicitly Out of Scope

- Rewrite modes
- Tone controls
- Persistent learning
- Cloud history
- Content analytics

## MVP Success Criteria

- Users understand changes at a glance
- Most surfaced corrections are accepted without confusion
- No surprise edits occur
- Privacy disclosures stay minimal
- The product is suitable for App Store review
