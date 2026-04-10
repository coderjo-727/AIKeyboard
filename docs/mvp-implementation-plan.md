# MVP Implementation Plan

## Goal

Translate the design spec into a buildable iOS keyboard MVP with a minimal,
safe, and testable architecture.

## Recommended Architecture

### Targets

- iOS container app for onboarding, permissions, and settings
- Custom keyboard extension for typing and review UI
- Shared framework or shared module for correction logic, diffing, and session
  state

### Core Modules

1. `KeyboardUI`
   - Key rows
   - Collapsed preview bar
   - Expanded review panel
2. `TextContext`
   - Read `documentContextBeforeInput`
   - Read `documentContextAfterInput`
   - Derive active sentence boundaries
3. `CorrectionEngine`
   - Normalize the active sentence for analysis
   - Apply conservative correction rules
   - Enforce confidence gating
4. `DiffRendering`
   - Compare original and corrected sentence
   - Mark insertions, replacements, and deletions
5. `SessionMemory`
   - Track accepted and rejected correction patterns in RAM only
   - Reset on dismissal or lifecycle change

## Delivery Phases

### Phase 1: Project Scaffold

- Create Xcode app and keyboard extension targets
- Add shared module for models and services
- Set up a simple development build configuration
- Add base unit test target for pure logic modules

### Phase 2: Text Context and Sentence Detection

- Build a sentence extractor around
  `documentContextBeforeInput` and `documentContextAfterInput`
- Handle punctuation boundaries and partial sentences
- Add unit tests for edge cases like abbreviations and emoji

### Phase 3: Conservative Correction Pipeline

- Start with a local correction interface that can be backed by a simple rules
  engine or AI provider later
- Restrict output to spelling, grammar, and punctuation corrections
- Reject outputs that rewrite style or meaning
- Add confidence gating and session rejection memory

### Phase 4: Preview UI

- Render a collapsed preview bar above the key rows
- Highlight changes accessibly with more than color alone
- Show the preview only when a correction is high confidence

### Phase 5: Expanded Review

- Expand the preview into a keyboard-contained panel
- Support scrolling for longer content
- Provide `Apply` and `Cancel`
- Restore the typing UI cleanly after either action

### Phase 6: Replace Text Safely

- Compute the delta between original and corrected sentence
- Replace only the active sentence in the host text input
- Avoid touching surrounding text unnecessarily
- Prefer overlap-safe replacement plans that only mutate the prefix before the
  cursor when the suffix after the cursor already matches the corrected output

### Phase 7: Session-Only Adaptation

- Track accepted and rejected suggestions in memory
- Support temporary dismissal separately from session-wide rejection
- Reset all session memory on keyboard dismissal and lifecycle transitions
- Confirm no disk writes occur in the correction path

## Key Technical Risks

## 1. Limited Text Visibility

Custom keyboards do not get full document access in the same way a full app
would. Sentence extraction must be robust even with partial surrounding text.

## 2. Safe Replacement

Applying edits through keyboard APIs can be fragile. The MVP should initially
focus on sentence-scoped replacement with careful cursor assumptions and strong
manual testing.

## 3. Latency

Typing must feel immediate. Correction work needs strict debouncing and
lightweight rendering.

## 4. Overcorrection

The biggest product risk is surfacing "smart" edits that feel invasive. The
first version should bias toward fewer suggestions, not broader ones.

## Initial Test Matrix

- Typing a sentence with simple spelling mistakes
- Typing slang that should remain unchanged
- Typing informal punctuation that should remain unchanged unless unambiguous
- Expanding and collapsing review while typing
- Applying corrections to short and long sentences
- Rejecting a suggestion and confirming it does not immediately reappear
- Dismissing the keyboard and confirming session memory resets

## Practical Next Step

Scaffold the Swift/Xcode project with:

- App target
- Keyboard extension target
- Shared models/services folder
- Unit tests for sentence extraction and diffing
