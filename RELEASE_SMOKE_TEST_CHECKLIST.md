# Release Smoke Test Checklist

Date: February 8, 2026

Use this checklist before submitting builds. Target is kids-first quality on both phone and tablet.

## Preconditions

- Build is from latest release candidate branch.
- App is configured for proxy-first AI:
  - `AI_PROXY_REQUIRED=true`
  - `AI_ALLOW_DIRECT_FALLBACK=false`
- Proxy endpoints are deployed and healthy:
  - See `/Users/haoyu/development/mm-learning-lab/AI_PROXY_DEPLOYMENT_GUIDE.md`

## Device Matrix

Run all core flows on:

- Phone portrait (small screen)
- Phone landscape
- Tablet portrait
- Tablet landscape

Recommended minimum:

- iPhone class: 1 older/smaller + 1 current
- iPad class: 1 standard-size device
- Android phone: 1 small/medium
- Android tablet: 1 large-screen

## Account/Data Matrix

- New install user (no prior data)
- Existing upgraded user with old DB
- Multi-profile household (at least 2 kids)
- Trial-active user
- Trial-expired + unsubscribed user
- Subscribed user

## Core Functional Smoke

Mark each as pass/fail on phone + tablet.

1. App launch + profile selection works without flicker.
2. Trial user can enter app without wrongful paywall.
3. Expired/unsubscribed user reaches paywall consistently.
4. Game selection cards/routes are all discoverable and open correctly.
5. Phonics plays at least 10 rounds without restart.
6. Letter tracing completion triggers feedback and next letter flow.
7. Story creation/save works and story appears in correct profile only.
8. Math challenge play + result + history work per selected profile only.
9. Quick resume navigates to expected last activity.
10. Adaptive difficulty updates behavior after a sequence of attempts.

## Upgrade/Migration Smoke (Existing Users)

1. Install old build (if available), create sample data for at least 2 profiles.
2. Upgrade to release candidate build.
3. Confirm no crash on first launch after upgrade.
4. Confirm each profile sees only its own stories/history/progress.
5. Confirm empty-state behavior for a new profile with no prior data.

## AI Proxy & Fallback Smoke

## A) Normal production mode

- Proxy enabled and healthy:
  - story generation works
  - AI chat text works
  - ElevenLabs voices/audio generation works
  - realtime session creation works (if enabled in app flow)

## B) Proxy outage behavior

- Keep production flags:
  - `AI_PROXY_REQUIRED=true`
  - `AI_ALLOW_DIRECT_FALLBACK=false`
- Simulate proxy outage.
- Expected:
  - app does not crash
  - AI actions fail gracefully with user-safe behavior/messages
  - non-AI gameplay flows remain usable

## C) Dev fallback behavior (debug only)

- Use:
  - `AI_PROXY_REQUIRED=false`
  - `AI_ALLOW_DIRECT_FALLBACK=true`
  - provider keys set
- Simulate proxy outage in debug.
- Expected:
  - AI still works via direct fallback
  - no runtime crashes

## Accessibility Smoke

1. Verify large text/readability in key screens.
2. Verify tappable targets are usable on phone and tablet.
3. Verify key controls have sensible semantics labels/read order.
4. Verify no critical UI clipping in landscape layouts.

## Performance/UX Smoke

1. Cold launch is stable (no navigation thrash).
2. Screen transitions remain responsive.
3. Repeated game/session loops do not degrade noticeably.
4. Audio playback/cleanup (story/chat/realtime) does not leak or hang.

## Final Release Gates

All must be true:

- `flutter analyze` passes cleanly.
- `flutter test` passes.
- All checklist sections above pass on at least one iOS and one Android phone + tablet.
- Proxy deployment validated via smoke calls.
- No parent-feature regressions introduced (feature remains out of scope).

## Sign-off Template

- QA owner:
- Build/version:
- iOS results:
- Android results:
- Proxy validation result:
- Migration validation result:
- Known issues (if any):
