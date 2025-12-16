# TreeView + ItemRow Incremental Refactor Plan

This plan breaks the interaction/presentation untangling into small, testable phases that preserve behavior at every step. Each phase should compile, run, and be reversible; changes are localized to reduce risk.

## Principles
- Keep `ItemRow` presentational: render only; no global state mutations.
- Centralize interaction in `TreeView`/ViewModel: selection, focus, expand/collapse, completion, keyboard, and drag-and-drop routing.
- Pass minimal props downward: item data, derived flags/counts, and callbacks.
- Preserve UX during migration: identical behavior before/after each phase.

## Phases

1) Introduce RowProps + callbacks
- Outcome: Add a lightweight `RowProps` struct and closures for `onTap`, `onChevronTap`, `onToggleComplete`.
- Safety: Wire defaults so existing row logic still runs; no behavior change.

2) Adapter layer
- Outcome: Add a thin adapter that maps current `ItemRow` parameters to `RowProps` without changing internals.
- Safety: Pure parameter plumbing; UI/behavior unchanged.

3) Centralize children computation
- Outcome: Compute `children` and `childCount` in `TreeView` (or ViewModel) and pass via props; remove per-row filtering/sorting.
- Safety: Expand/collapse and counts match pre-change.

4) Centralize tap selection
- Outcome: Replace row `.onTapGesture` with `onTap` callback; handle selection/focus in `TreeView`.
- Safety: Clicking rows selects/focuses exactly as before (macOS/iOS).

5) Centralize expand/collapse
- Outcome: Replace row chevron toggle with `onChevronTap`; expansion state lives in `TreeView`/settings.
- Safety: Chevron visuals and focus-mode rules unchanged.

6) Centralize completion toggle
- Outcome: Replace row icon toggle with `onToggleComplete`; `TreeView` calls store/view-model.
- Safety: Completion updates, filtering, and selection rules unchanged.

7) Drag-and-drop coordinator
- Outcome: Move DnD state/decisions (`draggedItemId`, drop target, `moveItem`) to a coordinator owned by `TreeView`; rows forward events only.
- Safety: Drag, hover indicators, and drop behavior unchanged.

8) Presentational row (macOS)
- Outcome: Split `ItemRow` into `ItemRowView` (pure UI) and keep logic in `TreeView`; keep file tidy.
- Safety: Layout, badges, edit flows, and keyboard interactions unchanged.

9) Mirror on iOS
- Outcome: Apply the same props/callback contract to `DirectGTD-iOS` `ItemRowView` and route to `TreeViewModel`.
- Safety: Tap, expand, complete, and context menus behave the same.

10) Regression checks + cleanup
- Outcome: Manual checklist run on both platforms; remove dead code and per-row filters.
- Safety: Zero UX regressions; compile clean; diffs remain localized.

## Regression Checklist (run each phase)
- Selection: click/tap selects; selected background reflects state.
- Focus mode: tap on selected behaves as before; parent/child visibility intact.
- Expand/collapse: chevrons, state persistence, and focus rules unchanged.
- Completion: toggling updates icons, filters, and selection rules.
- Editing: start/cancel, empty-title deletion, and scroll-into-view work.
- Keyboard: arrows, return, delete, tab/outdent behave as before (macOS).
- DnD: drag indicators, into/above/below drops, and undo behave identically.
- Performance: no new layout jank; large trees remain responsive.

## Notes
- Start with macOS to validate the contract, then mirror on iOS.
- Keep platform-specific differences in `TreeView`/ViewModel, not in rows.
- Prefer adding new code paths alongside old ones, then flipping usage once verified.

