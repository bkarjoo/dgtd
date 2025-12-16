# Phase 1 — Test Instructions (QA/Test Team)

Scope: Validate the introduction of RowProps + callbacks on both platforms is non‑breaking and ready for later centralization of logic.

## Test Strategy
- Emphasize no‑regression: behavior and visuals remain unchanged.
- Add lightweight unit/UI tests to assert new contracts exist and are inert by default.
- Run a manual smoke checklist across core interactions.

## What’s New to Verify
- New types: `RowProps` and `ItemRowCallbacks` (per platform) exist and are importable.
- Row initializers accept optional `rowProps` and `callbacks` with safe defaults.
- Default callbacks are no‑ops and do not alter behavior when not supplied.

## Automated Tests
Add tests in existing targets:

1) Unit tests (macOS: `DirectGTDTests`, iOS: `DirectGTD-iOSTests`)
- Type presence: Instantiate `RowProps` and `ItemRowCallbacks.noop`.
- Initializer compatibility: Instantiate `ItemRow`/`ItemRowView` without the new args (compile/runtime sanity by evaluating `.body` once where feasible).
- Optional arg instantiation: Instantiate rows with `rowProps: nil` and `callbacks: .noop` and ensure construction succeeds.

2) UI/Integration smoke (macOS: `DirectGTDUITests`, iOS: `DirectGTD-iOSUITests`)
- Launch app; basic navigation works (open main view, load items).
- Tap/select first item; selection highlight appears.
- Expand/collapse where applicable; chevron behavior unchanged.
- Toggle task completion; icon updates; no crash.

Note: Phase 1 doesn’t route interactions through callbacks yet, so tests only confirm parity with pre‑change behavior.

## Manual Regression Checklist (Both Platforms)
- Selection: clicking/tapping rows selects as before.
- Focus mode behavior: unchanged for selected vs. focused item actions.
- Expand/collapse: chevrons show and toggle as before; expansion state persists.
- Completion: toggling updates icons and visibility as configured.
- Editing: start/cancel flows unaffected; scroll‑into‑view works.
- Keyboard (macOS): arrows, return, delete, tab/outdent behave as before.
- Drag & Drop (macOS): hover indicators, into/above/below drops, undo intact.
- Performance: loading large trees still responsive; no jank.

## Pass/Fail Criteria
- All automated tests pass on CI for both targets.
- Manual checklist shows no deviations from baseline behavior.
- No new crashes, warnings, or notable logs introduced by Phase 1.

## Out of Scope
- Verifying callback‑driven routing (comes in later phases).
- Any visual redesigns or data model changes.

