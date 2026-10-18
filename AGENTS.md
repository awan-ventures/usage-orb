# Usage Orb

Read `README.md` and `docs/PLAN.md` before changing this repository.

- Native macOS 14+ menu bar app in Swift, AppKit, SwiftUI and Swift Charts. Keep it dependency-free.
- The rings are the product: one per provider, and the menu must work without the dashboard. Only quota windows or a real ceiling (an OpenRouter key limit) drive a ring. Never turn a balance or spend into a percentage.
- The menu is a native `NSMenu` with SwiftUI cards in its items. Keep cards plain: name, bars, one footnote line. Put source details in tooltips.
- Record every figure's source (`DataSource`) and show it on hover. Keep reported spend separate from estimates; don't add estimates without a label.
- Each provider is a `UsageProvider` with a static, tested `parse` function. Parse leniently: undocumented payloads change.
- No backend, analytics, browser-session scraping or secret logging. API keys live in the Keychain only. Never refresh another app's OAuth token.
- Keep polling cheap: one timer, backoff on failure, nothing faster than once a minute.
- `project.yml` is the XcodeGen source of truth. Regenerate and commit the Xcode project after adding or removing source files.
- Run `./scripts/test.sh` for behaviour checks and `./scripts/build.sh` for the Release build. Use `USAGE_ORB_SAMPLE=1` for screenshots; documentation images must use sample data.
