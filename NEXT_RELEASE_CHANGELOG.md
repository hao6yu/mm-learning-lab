# Next Release Changelog

Date: February 8, 2026

This release focuses on kids learning quality, reliability, and responsive UX for phone/tablet. Parent features remain out of scope.

## Highlights

- Trial/paywall flow stabilized with cleaner guard behavior.
- Phonics loop and tracing progression improved for repeatable learning flow.
- Data isolation enforced per child profile with DB migration support for existing users.
- Adaptive difficulty added for learning progression.
- Accessibility-first pass across high-traffic flows.
- AI integrations moved to proxy-first architecture with safe fallback rules.
- Analyzer and deprecation cleanup completed (clean analyzer run).
- Regression test suite added and passing.

## Learning Experience Improvements

- Phonics activity supports playable rounds with clearer feedback loops.
- Letter tracing progression has completion logic, success flow, and next-step continuity.
- Math and literacy flows improved for continuity and game-to-game progression.
- Quick resume and progress-related UX additions for easier return-to-learning.

## Kids UI/UE Improvements

- Better responsive behavior on phone and tablet layouts.
- Cleaner game selection and activity discoverability.
- More consistent interaction and feedback patterns across game/result screens.
- Accessibility improvements for readability and interaction targets.

## Data & Upgrade Safety

- Existing database upgraded to include stronger profile-based isolation.
- Migration path supports legacy users without requiring data reset.
- Fallback profile/migration handling covered by tests.

## AI & Security

- OpenAI and ElevenLabs clients now run proxy-first.
- Direct provider fallback is policy-controlled and blocked in release when proxy is required.
- Realtime voice session flow updated to follow the same fallback policy.
- Added deployment runbook:
  - `/Users/haoyu/development/mm-learning-lab/AI_PROXY_DEPLOYMENT_GUIDE.md`

## Quality & Validation

- Analyzer status: clean (`flutter analyze` passes).
- Test suite: all tests passing (`flutter test`), including:
  - responsive/profile/progress checks
  - DB migration and profile isolation checks
  - widget flow regressions
  - adaptive difficulty service checks
  - tracing completion evaluator checks

## Out Of Scope (Explicit)

- Parent area / parent PIN / parent-facing features.
