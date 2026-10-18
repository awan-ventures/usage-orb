# Usage Orb

Read `README.md` and `docs/PLAN.md` before changing this repository.

- Native macOS 14+ menu bar app in Swift, AppKit, SwiftUI and Swift Charts. Keep it dependency-free.
- The ring is the product; the popover must work without the dashboard. Only subscription quota windows drive the ring. Never turn a balance or spend into a percentage.
- Label every figure with its source (`DataSource`). Keep reported spend separate from estimates; don't add estimates without a label.
- Each provider is a `UsageProvider` with a static, tested `parse` function. Parse leniently: undocumented payloads change.
- No backend, analytics, browser-session scraping or secret logging. API keys live in the Keychain only. Never refresh another app's OAuth token.
- Keep polling cheap: one timer, backoff on failure, nothing faster than once a minute.
- `project.yml` is the XcodeGen source of truth. Regenerate and commit the Xcode project after adding or removing source files.
- Run `./scripts/test.sh` for behaviour checks and `./scripts/build.sh` for the Release build. Use `USAGE_ORB_SAMPLE=1` for screenshots; documentation images must use sample data.
