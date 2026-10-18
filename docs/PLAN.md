# Plan

Updated 2026-10-18.

## Decisions so far

- **Name:** Usage Orb is a working title.
- **Build, don't fork.** No project called AgentMeter could be found. [CodexBar](https://github.com/steipete/CodexBar) (MIT) is the closest existing app, but it is far larger than this plan needs. Usage Orb uses its own small provider adapters and credits CodexBar as prior art.
- **Claude Code:** uses `GET https://api.anthropic.com/api/oauth/usage` with Claude Code's OAuth token and `anthropic-beta: oauth-2025-04-20`. Checked against a live Pro account on 2026-10-18: the response has a `limits` list (`kind`, `percent`, `resets_at`, `scope`) as well as the older flat `five_hour` / `seven_day` keys. Both are parsed. The token is never refreshed by Usage Orb.
- **Codex:** reads `rate_limits` (`primary` / `secondary` with `used_percent`, `window_minutes`, `resets_at`, plus `credits` and `plan_type`) from `token_count` events in `~/.codex/sessions/**/*.jsonl`, following the `RateLimitSnapshot` struct in the Codex source. Not yet tested against a real Codex log on a Mac.
- **DeepSeek:** documented `GET /user/balance`. **OpenRouter:** documented `GET /api/v1/key` (usage daily/weekly/monthly, limit remaining).
- **Persistence:** JSON files in Application Support rather than SwiftData or SQLite. History is throttled (unchanged values at most every 30 minutes) and pruned to 90 days.

## Done (local MVP)

- [x] Menu bar ring with normal, warning, critical, stale and unknown states that differ in shape as well as colour; VoiceOver value and tooltip.
- [x] Popover: per-provider windows with bars, reset countdowns, source labels, freshness, errors, and the last good reading after a failure. Pin a window by right-clicking.
- [x] Providers: Claude Code, Codex, DeepSeek, OpenRouter. Keychain for API keys.
- [x] Polling every 5 minutes by default, backoff on failure, cached last readings.
- [x] Dashboard: quota use, daily OpenRouter spend and balances over 24 h–90 d.
- [x] Settings: providers, keys, ring mode, thresholds, refresh interval, percentage label, Open at login.
- [x] Unit tests for parsing, ring selection and history. Sample mode for UI work.

## Next

- [ ] Run against a real Codex CLI log and a real DeepSeek and OpenRouter key.
- [ ] Notifications when a window crosses the critical threshold (opt-in).
- [ ] More providers behind the same protocol (Gemini CLI, Cursor), only where a permitted, stable source exists.
- [ ] Battery measurement over a day.
- [ ] Signed and notarized release, then a Homebrew cask.

## Original plan

The plan as written in Made by Awan before the repository existed:


Status: proposed, 2026-10-18. Intended to become an independent repository like Jotello, not a web app inside Made by Awan.

### North star
**The tiny status circle is the main product; the dashboard is a supporting experience.** A glanceable macOS menu bar ring shows quota pressure without requiring interaction. Clicking opens a compact native popover with Claude Code, Codex, DeepSeek, OpenRouter, and configurable providers. A full dashboard remains available for historical breakdowns.

### Experience
1. Status ring always present in macOS menu bar. Default meaning: **maximum percent quota consumed among enabled, reliably measured subscription quota windows** (the most urgent constraint). Show neutral/unknown state when no fresh comparable quota exists; never turn API dollar balance into an unlabelled percent. User can choose a pinned provider/quota window. Tooltips/accessibility label identify source and data freshness. Color plus pattern/accessible text conveys warning; configurable thresholds.
2. Click shows compact list: provider, window (e.g. five-hour, weekly), percentage used or remaining, reset countdown, API spend/credit where applicable, freshness/errors. Clearly separate subscription quota from token usage and actual billed API spend.
3. Open dashboard from popover: charts over time, actual/estimated spend, model/provider breakdown, local token counts, period selection. Historical data is a second surface, not a prerequisite to basic menubar utility.
4. Settings: enable providers, read-only API keys through Keychain, privacy, refresh interval, startup login toggle, pin provider/ring semantics.
5. Menu bar app defaults to no permanent Dock icon; full dashboard may use a normal window.

### Integration strategy
Evaluate forking AgentMeter (confirm ownership, license, maintenance, documented provider interfaces and working integrations **before** choosing fork) against implementing lightweight provider adapters. Investigate ToastMonitor for local token/cost history ideas. Never rely on browser session scraping by default. Each adapter declares available metric types, method, authentication, refresh cadence, and reliability. Support Claude Code and Codex local account/auth data where stable; DeepSeek and OpenRouter API keys; distinguish official provider API reports from local estimates and undocumented quota approaches. Never claim a provider reports quota when it only reports spend.

### Technical
Native SwiftUI, MenuBarExtra + NSStatusItem as required for ring rendering, Swift Charts dashboard, Keychain secrets, local persistence (SwiftData or SQLite after validation), modular provider protocol, cached last known response, controlled polling/backoff. No backend, no analytics by default, no secret logging. Avoid material battery overhead.

### MVP acceptance
- Ring accessible/glanceable and honest when stale, missing, or not comparable.
- Claude Code and Codex measured usage windows, where supported, with countdown and documented fallback.
- DeepSeek and OpenRouter balances/spend via permitted APIs where available.
- Compact popover works independently of full dashboard; simple dashboard with at least daily spend history from trustworthy local/API data, clearly labelled estimates.
- Provider-specific setup errors and secure key storage.
- Launch at login option, manual refresh, sensible polling and battery test.
- Signed/notarized packaging can be follow-up, not block initial local build.

### Build sequence
1. Validate upstream AgentMeter and license/integration approach.
2. Native status item + ring renderer + compact popover with fixtures.
3. Provider abstraction, supported integrations, caching and error states.
4. Dashboard with time-series history; avoid equating computed cost with billed spend.
5. Smoke tests, macOS accessibility, packaging.

Ownership: separate native macOS repo once created. This document is a tracking pointer in Made by Awan, not the eventual source of truth.
