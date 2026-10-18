# Testing

`./scripts/test.sh` runs the unit tests: provider parsing (Claude Code current and older formats, Codex rollout logs, DeepSeek, OpenRouter), ring selection (staleness, resets, pinning, thresholds) and history recording.

## Manual checks

Run these after changes to the menu bar, windows or providers.

1. **Sample UI.** `USAGE_ORB_SAMPLE=1 USAGE_ORB_OPEN=popover …/UsageOrb`. The ring is orange with a dot (74%), the popover lists four providers, and Dashboard and Settings open as windows.
2. **Light and dark menu bars.** Normal rings are template images and should follow the menu bar colour.
3. **Codex.** With Codex CLI signed in with ChatGPT, run one turn, then Refresh. Without `~/.codex/sessions`, Codex shows a setup hint and the ring shows a dashed circle.
4. **Claude Code.** Press Connect. macOS asks to allow access to "Claude Code-credentials"; allow it. Session and weekly windows appear. Deny it and the row explains that no sign-in was found.
5. **API keys.** Paste a key in Settings (⌘V must work), Save, and check the figures. A wrong key shows "rejected the credentials". Remove deletes it from the Keychain.
6. **VoiceOver.** The menu bar item reads the provider, window, percentage, reset time and freshness.
7. **Open at login.** Toggle it in Settings and check System Settings → General → Login Items. This needs a signed build in `/Applications` to be reliable.
8. **Battery.** Leave it running for an hour at the default 5-minute interval and check Activity Monitor's Energy tab.
