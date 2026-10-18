# Privacy

Usage Orb reads usage figures for the AI tools you connect and shows them on your Mac.

- **Network:** Usage Orb contacts only the providers you turn on: `api.anthropic.com` (Claude Code), `api.deepseek.com` and `openrouter.ai`. Codex is read from local files and needs no network. There is no Usage Orb server.
- **Claude Code sign-in:** When you connect Claude Code, Usage Orb reads Claude Code's existing sign-in from your Keychain (macOS asks you first) or from `~/.claude/.credentials.json`, and sends it only to Anthropic to ask for your usage. It is never stored, logged or refreshed by Usage Orb.
- **API keys:** DeepSeek and OpenRouter keys are stored in your login Keychain, available only on this Mac, and sent only to their own provider.
- **Local files:** The last readings and up to 90 days of history are kept in `~/Library/Application Support/Usage Orb/`. Delete that folder to remove them. Preferences are stored in macOS user defaults.
- **Data collection:** No analytics, tracking, advertising, accounts or third-party SDKs.
