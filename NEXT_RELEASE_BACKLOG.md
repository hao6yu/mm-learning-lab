# M&M Learning Lab: Next Release Backlog

## Scope
- Keep all previously agreed improvements except parent area / parent PIN.
- Primary target: improve kids learning quality and app reliability on both phone and tablet.

## Assumptions
- Team size: 1 Flutter engineer.
- Estimates below are engineering days (not calendar days).
- AI backend/proxy can be delivered as minimal service first, then hardened later.

## P0 (Must Ship)

### P0-1. Fix trial/paywall flow consistency
- Goal: no unexpected blocking for users still in free trial.
- Estimate: 1.5 days.
- Files to touch:
  - `lib/screens/profile_selection_screen.dart`
  - `lib/widgets/subscription_guard.dart`
  - `lib/services/subscription_service.dart`
- Implementation notes:
  - Centralize trial/subscription decision in one place (guard/service), remove duplicated logic.
  - Ensure profile screen never force-pushes paywall if trial is active.
  - Add deterministic state transitions for app cold start.
- Acceptance criteria:
  - New user can access app during trial.
  - Expired trial + unsubscribed reliably lands on paywall.
  - No flicker/jump between profile and paywall on launch.

### P0-2. Complete phonics game loop
- Goal: move phonics from placeholder to playable learning loop.
- Estimate: 2.0 days.
- Files to touch:
  - `lib/screens/phonics_screen.dart`
  - `lib/widgets/letter_bubble.dart`
  - `lib/services/database_service.dart` (optional if storing results)
- Implementation notes:
  - Generate rounds dynamically (target letter, distractors, progression).
  - Add correct/incorrect feedback, score/streak, next round.
  - Add responsive layout rules for phone landscape and tablet.
- Acceptance criteria:
  - At least 10 rounds playable without restart.
  - Clear feedback after each answer.
  - Usable and readable on small phones and tablets.

### P0-3. Complete letter tracing progression
- Goal: tracing should have real completion, progress, and reward.
- Estimate: 3.0 days.
- Files to touch:
  - `lib/widgets/tracing_canvas.dart`
  - `lib/screens/letter_tracing_screen.dart`
  - `lib/services/database_service.dart` (optional for persistence)
- Implementation notes:
  - Add completion heuristic (stroke coverage/path similarity threshold).
  - Enable `onCompleted` flow: success UI, next letter prompt, streak.
  - Expand demo paths beyond A/B/C (at minimum grouped fallback behavior).
  - Make tracing canvas size adaptive instead of fixed 300x400.
- Acceptance criteria:
  - Completion can trigger reliably for multiple letters.
  - Child gets immediate positive feedback and next action.
  - No clipping/overflow on phone landscape.

### P0-4. Per-profile data isolation + DB migration
- Goal: sibling/child data must not mix.
- Estimate: 3.0 days.
- Files to touch:
  - `lib/services/database_service.dart`
  - `lib/screens/math_challenge_result_screen.dart`
  - `lib/screens/math_quiz_history_screen.dart`
  - `lib/screens/story_adventure_screen.dart`
  - `lib/screens/create_story_screen.dart`
  - `lib/providers/profile_provider.dart`
- Implementation notes:
  - Add `profile_id` to `math_quiz_attempts` and `stories` tables.
  - Add migration logic in DB upgrade path.
  - Update queries/inserts to always include selected profile.
- Acceptance criteria:
  - Different profiles only see their own stories/history.
  - Existing users migrate without crash/data loss.
  - Empty states shown when switching to a new child profile.

### P0-5. Feature discoverability cleanup
- Goal: menu and route inventory must match.
- Estimate: 1.0 day.
- Files to touch:
  - `lib/screens/game_selection_screen.dart`
  - `lib/screens/puzzle_game_selection_screen.dart`
  - `lib/main.dart`
- Implementation notes:
  - Decide: expose Phonics/Chess Maze in menus or remove route/dead import.
  - Keep card taxonomy consistent by learning type.
- Acceptance criteria:
  - No hidden major features.
  - All feature cards navigate correctly.

### P0-6. Basic test safety net
- Goal: prevent regressions in the highest-risk flows.
- Estimate: 2.5 days.
- Files to add/touch:
  - `test/` (new)
  - Widget tests for profile selection, trial/paywall behavior, story save, math history.
- Acceptance criteria:
  - CI/local test suite passes.
  - P0 user flows have test coverage for happy path and one failure path.

## P1 (High Value, Next)

### P1-1. Shared responsive design system
- Estimate: 2.5 days.
- Files to touch:
  - `lib/utils/responsive_config.dart`
  - `lib/utils/screen_utils.dart`
  - `lib/screens/*selection*`, `lib/screens/*game*` (incremental adoption)
- Notes:
  - Define canonical breakpoints and spacing/type scale tokens.
  - Replace repeated one-off sizing logic screen-by-screen.

### P1-2. Accessibility pass
- Estimate: 2.0 days.
- Files to touch:
  - `lib/main.dart`
  - high-traffic screens and widgets
- Notes:
  - Remove forced text-scale lock.
  - Improve semantics labels on controls.
  - Ensure minimum touch target size and contrast checks.

### P1-3. UI/UE polish pass (kids-first)
- Estimate: 3.0 days.
- Files to touch:
  - `lib/screens/profile_selection_screen.dart`
  - `lib/screens/game_selection_screen.dart`
  - `lib/screens/math_game_selection_screen.dart`
  - `lib/screens/puzzle_game_selection_screen.dart`
  - representative game result screens
- Notes:
  - One clear primary CTA per screen.
  - Unified reward and feedback motion/language.
  - Better tablet split layouts and phone thumb-friendly control placement.

### P1-4. AI key security hardening
- Estimate: 3.0 days.
- Files to touch:
  - `lib/services/openai_service.dart`
  - `lib/services/elevenlabs_service.dart`
  - app config/env docs
- Notes:
  - Move direct API calls behind backend proxy.
  - Keep client API surface the same where possible to reduce UI churn.

### P1-5. Analyzer/deprecation cleanup
- Estimate: 2.0 days.
- Files to touch:
  - cross-codebase
- Notes:
  - Start with warnings first (49), then highest-impact infos/deprecations.
  - Prioritize runtime-risk items before style-only items.

## UI/UE Improvements (Concrete Items to Implement)
- Add a consistent global pattern for: `Back`, `Home`, `Play Again`, `Next`.
- Standardize card and button tokens:
  - card radius, elevation, icon size, title size, CTA color mapping.
- Standardize animation timing:
  - entrance: 250ms, success: 350ms, error shake: 180ms.
- Add “quick resume” from selected profile:
  - continue last played activity directly from welcome state.
- Improve end-of-level flow:
  - “Try again”, “Next level/round”, “Switch game” suggestions.
- Add first-time micro-onboarding per game (dismissible and cached).
- Reduce clutter on phone landscape:
  - collapse secondary controls into bottom sheet / compact row.
- Improve tablet use of space:
  - dedicated side panel for score/progress where applicable.

## Delivery Sequence (Recommended)

### Sprint 1 (P0 Core, ~7-8 days)
- P0-1 Trial/paywall consistency.
- P0-2 Phonics completion.
- P0-5 Discoverability cleanup.
- Start P0-6 tests (paywall/profile/menu navigation).

### Sprint 2 (P0 Data + Tracing, ~8-9 days)
- P0-3 Tracing completion/progression.
- P0-4 Per-profile DB migration + query updates.
- Finish P0-6 tests (story/math/profile isolation).

### Sprint 3 (P1 UX/Tech, ~9-10 days)
- P1-1 Responsive system.
- P1-2 Accessibility pass.
- P1-3 UI/UE polish pass.
- Begin P1-5 analyzer cleanup.

### Sprint 4 (P1 Security + Stabilization, ~5-6 days)
- P1-4 AI proxy migration.
- Finish P1-5 analyzer cleanup.
- Regression testing and release candidate hardening.

## Out of Scope (Explicit)
- Parent area and parent PIN controls.

