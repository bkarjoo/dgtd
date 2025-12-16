# Phase 1 — TreeView/ItemRow Refactor Instructions (Dev Team)

Scope: Introduce a non‑breaking RowProps + callbacks contract around ItemRow/ItemRowView so we can centralize interaction later without changing behavior now.

## Goals
- Add presentational contracts without moving logic yet.
- Preserve current behavior 100% (no UX changes, no flow changes).
- Keep compilation green on macOS and iOS.

## Non‑Goals (Phase 1)
- No movement of selection/expand/completion/drag‑and‑drop logic.
- No changes to filtering or children computation.
- No visual/layout changes.

## Tasks
1) Add contracts (one per platform)
- macOS: add `DirectGTD/TreeViewContracts.swift` containing:
  - `struct RowProps { let item: Item; let isSelected: Bool; let isExpanded: Bool; let fontSize: CGFloat }`
  - `struct ItemRowCallbacks { var onTap: (String) -> Void; var onChevronTap: (String) -> Void; var onToggleComplete: (String) -> Void }`
  - Provide `static let noop = ItemRowCallbacks(onTap: { _ in }, onChevronTap: { _ in }, onToggleComplete: { _ in })`.
- iOS: add `DirectGTD-iOS/TreeViewContracts.swift` with the same definitions (no cross‑target sharing yet to avoid build entanglement).

2) Thread optional parameters (non‑breaking)
- macOS `ItemRow` (currently in `DirectGTD/TreeView.swift`):
  - Add optional parameters with defaults: `rowProps: RowProps? = nil, callbacks: ItemRowCallbacks = .noop`.
  - Do NOT change existing behavior; ignore these new parameters inside the body for now.
- iOS `ItemRowView` (in `DirectGTD-iOS/TreeView.swift`):
  - Same: add optional `rowProps: RowProps? = nil, callbacks: ItemRowCallbacks = .noop` and ignore internally.
- Rationale: callers don’t need updates; binary/source compatibility is maintained.

3) Add minimal factory stubs (not used yet)
- macOS `TreeView`: add private helpers (unused for now):
  - `makeRowProps(for item: Item) -> RowProps`
  - `makeRowCallbacks() -> ItemRowCallbacks` (return `.noop`)
- iOS `TreeView`: add identical helpers (unused).

4) No call‑site changes yet
- Keep all existing `ItemRow(...)`/`ItemRowView(...)` initializers unchanged in both apps.

## Acceptance Criteria
- Both targets build and run with zero behavioral or visual changes.
- New types exist and can be imported by their respective targets.
- Optional params do not alter runtime behavior when omitted.

## Rollback Plan
- Revert the two new `TreeViewContracts.swift` files and remove the optional params from row initializers.

## Notes
- These contracts pave the way for Phase 2 (adapter) and Phase 4–6 (centralizing interactions) while ensuring no risk in this step.

