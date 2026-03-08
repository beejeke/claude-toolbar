# Claude Toolbar

> **Real-time Claude Code usage tracker for your macOS menu bar.**
> Zero configuration · No API keys · Auto-detects your subscription plan · Reads local files only.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?style=flat-square)
![License MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## What it looks like

```
╔══════════════════════════════════════════╗
║  🟠 Claude Code  [Pro]          ↻  ⚙️  ⏻ ║
╠══════════════════════════════════════════╣
║  🕐 Current Session             just now ║
║                                          ║
║  8.4K                            $0.18   ║
║  tokens generated                API ref ║
║  ● 12 calls · Sonnet         9.1K real   ║
╠══════════════════════════════════════════╣
║  ⏱ Window (5h)                  just now ║
║                                          ║
║  130.2K                         $12.19   ║
║  tokens generated                API ref ║
║  ████████████░░░░░░  55% of limit calibrated ║
║  133.9K / 243.6K tok                     ║
║  🔥 173.1K/h · window in ~1h 20m        ║
║  ☀️ Today total: 216.1K tokens generated ║
║  ● 346 calls · Sonnet      133.9K real   ║
╠══════════════════════════════════════════╣
║  📅 Last 7 Days                          ║
║                                          ║
║  580.4K                         $43.22   ║
║  tokens generated                API ref ║
║  █████████░░░░░░░░░  38%                 ║
║  580.4K / 1.54M tok · 892 calls          ║
╠══════════════════════════════════════════╣
║  📊 Daily history                        ║
║   ▂  ▅  █  ▃  ▁  ▄  ▇                   ║
║  Mon Tue Wed Thu Fri Sat Sun             ║
╠══════════════════════════════════════════╣
║  Ref. API: Anthropic public pricing      ║
║                          updated 1s ago  ║
╚══════════════════════════════════════════╝
```

---

## What it tracks

| Metric | What it means |
|--------|--------------|
| **Tokens generated** | `output_tokens` — what Claude actually wrote. The real measure of work done. |
| **API cost ref.** | Estimated cost at public Anthropic API pricing. Useful as a consumption reference even on a Pro/Max subscription. |
| **Window (5h) %** | Progress in the current 5-hour window vs your real rate limit (auto-calibrated). |
| **Burn rate** | Token velocity of the active session (K/h) and predicted time to window limit. |
| **Today total** | Cumulative output tokens since midnight, shown as context below the window card. |
| **Call count** | Number of Claude API interactions per period. |
| **Daily history** | Mini bar chart of output tokens per day for the last 7 days. |
| **Rate limit reset** | When a platform rate limit has been hit recently, shows when it resets — read from local session files, no network needed. |

> **Why `realTokens` for the progress bar?** Claude's rate limit counts total tokens processed (input + output), not output alone. Claude Toolbar uses `input_tokens + output_tokens` for the % bar so it matches what Claude.ai reports on its usage page. Output tokens are still the headline number (what Claude generated = the work done).

---

## Requirements

- **macOS 13.0+** (Ventura or later)
- **[Claude Code CLI](https://claude.ai/code)** — the app reads session files created by `claude` in the terminal.
- **Swift Command Line Tools** (for building from source only)

---

## Install

### One-liner (recommended)

```bash
git clone https://github.com/beejeke/claude-toolbar.git && cd claude-toolbar && make install
```

This compiles a release binary, creates `ClaudeToolbar.app`, installs it to `/Applications/`, and opens it.

### Download prebuilt app

1. Go to [**Releases**](https://github.com/beejeke/claude-toolbar/releases)
2. Download `ClaudeToolbar-x.x.x.app.zip`
3. Unzip → drag `ClaudeToolbar.app` to `/Applications/`
4. Open it. On first launch macOS may show a security prompt:
   **System Settings → Privacy & Security → Open Anyway**

### Build manually

```bash
git clone https://github.com/beejeke/claude-toolbar.git
cd claude-toolbar

make bundle    # → ClaudeToolbar.app in current directory
make install   # → copies to /Applications and opens
```

---

## First run

On first open, Claude Toolbar looks for `~/.claude/projects/` — the directory Claude Code creates automatically when you run any `claude` command. macOS will prompt for notification permission on first launch.

| State | What you'll see |
|-------|----------------|
| Claude Code used before | Data loads immediately |
| Claude Code installed, never run | Empty state with hint to run `claude` |
| Claude Code not installed | Empty state — [install it here](https://claude.ai/code) |

No login, no API key, no configuration needed.

---

## How it works

```
~/.claude/projects/**/*.jsonl     macOS Keychain
          │                             │
          │  (local file read)          │  (SecItemCopyMatching)
          ▼                             ▼
  CLIUsageService (Swift actor)   KeychainCredentialsService
    ├─ reads all .jsonl files        └─ reads subscriptionType
    ├─ parses assistant messages
    ├─ detects real window boundaries (5h)
    ├─ auto-calibrates window limit from rate limit history
    ├─ computes session burn rate
    └─ detects rate limit reset time
          │
          ▼
  UsageViewModel (@MainActor)
    ├─ applies calibrated or plan limits
    ├─ refreshes every 60 seconds
    └─ fires threshold notifications (70%, 90%)
          │
          ▼
  Menu Bar Popover (SwiftUI)
    ├─ tokens + cost + % progress bars
    ├─ burn rate prediction
    ├─ 7-day daily bar chart
    └─ ⚙️ settings panel (language, notifications, limits)
```

Claude Code writes every API interaction to `~/.claude/projects/<project>/<session>.jsonl`. Each assistant entry contains a `usage` object with exact token counts. Claude Toolbar reads these files directly — no network calls, no authentication.

**Token fields used:**

```json
{
  "input_tokens": 4389,
  "output_tokens": 311630,
  "cache_creation_input_tokens": 934189,
  "cache_read_input_tokens": 42469404
}
```

**Cost reference** uses [public Anthropic API pricing](https://www.anthropic.com/pricing):

| Model | Input | Output | Cache write | Cache read |
|-------|-------|--------|-------------|------------|
| Sonnet | $3/MTok | $15/MTok | $3.75/MTok | $0.30/MTok |
| Opus | $15/MTok | $75/MTok | $18.75/MTok | $1.50/MTok |
| Haiku | $0.80/MTok | $4/MTok | $1.00/MTok | $0.08/MTok |

---

## The 5-hour window — how Claude Code rate limits actually work

Claude Code does **not** have a simple daily limit. It uses a **5-hour rolling window**:

- A new window starts when you send your first message after the previous one expired
- The window lasts exactly 5 hours from that first message
- You can use multiple windows per day — each resets independently

This is why a "daily total" tracker can show >100% while you still have tokens available: you've used multiple windows throughout the day.

**Window limits by plan (approximate):**

| Plan | Per 5h window | Weekly ceiling |
|------|--------------|----------------|
| **Pro** | 44,000 tokens | 1,540,000 tokens |
| **Max 5×** | 88,000 tokens | 3,080,000 tokens |
| **Max 20×** | 220,000 tokens | 7,700,000 tokens |

Limits count `input_tokens + output_tokens` (total processed), matching Claude's own usage page.

---

## Auto-calibration of window limits

The published limit figures are approximations. Claude Toolbar **self-calibrates** from your own rate limit history:

When you hit a rate limit, the CLI logs the event in the local JSONL files. At that moment, the tokens you'd consumed in that window = your plan's actual window capacity. Claude Toolbar reads this and uses it as the real limit going forward.

- **`calibrated` badge** (green) → limit was derived from a real rate limit event in your history → most accurate
- **No badge** → using the default for the detected plan → less accurate until you hit a limit once

The calibrated limit updates automatically every refresh cycle as it re-reads the JSONL history.

---

## Auto plan detection

Claude Toolbar automatically detects your subscription plan by reading the `Claude Code-credentials` entry the CLI stores in your macOS Keychain. No manual setup needed. The detected plan name is shown as a badge in the popover header.

---

## Burn rate

When an active session is detected (last activity within 30 minutes, at least 5 minutes of data), a burn rate row appears below the window progress bar:

- **`🔥 12.3K/h · window in ~1h 20m`** — normal state (orange)
- Turns **red** when fewer than 1 hour remains in the current window
- Shows `"window exhausted"` if the window limit is exceeded

Rate is computed as `realTokens ÷ session_duration_hours`. Time to limit is `remaining_window_tokens ÷ rate`.

---

## Rate limit reset time

When the Claude Code CLI hits a platform rate limit, it logs the event in the local session files. Claude Toolbar surfaces this as a banner — but **only if the rate limit occurred in the current active window** (within the last 5 hours). Stale rate limit data from previous windows is hidden automatically.

- **If hit in current window** → `⛔ Limit reached 2h ago · Resets: 4pm (Atlantic/Canary)` in red
- **If hit in a previous window** → banner hidden (the window has already reset)

---

## 7-day bar chart

The daily history chart shows one bar per day for the last 7 calendar days, proportional to that day's output tokens.

- **Today's bar** is highlighted
- **Click any bar** to see the exact token count and API cost reference
- **Hover** for a native macOS tooltip

---

## Notifications

Claude Toolbar sends native macOS alerts when window or weekly usage crosses **70%** and **90%** of your limits. Each threshold fires at most once per day (window) or once per ISO week (weekly).

**Tapping a notification** opens the menu bar popover automatically.

Toggle notifications off in the **⚙️ Settings** panel inside the app.

---

## Settings

Click the **⚙️** button in the header to open the settings panel:

| Setting | Description |
|---------|-------------|
| **Language** | UI language: English, Español, 日本語, 中文, Italiano, Français, Deutsch |
| **Notification toggle** | Enable/disable threshold alerts (70% and 90% of window and weekly limits) |
| **Window limit display** | Shows calibrated limit (green badge) or plan default |
| **Weekly limit display** | Shows current weekly limit |
| **Reset to plan defaults** | Discards manual overrides and restores auto-detected plan limits |
| **About** | Data source path, network status (always zero connections) |

---

## Performance

| Resource | Usage |
|----------|-------|
| **CPU** | ~0% idle. No polling — reads files once per minute. |
| **Memory** | 15–25 MB RSS (standard for a menu bar SwiftUI app). |
| **Network** | **Zero** — no outbound connections, no telemetry, no analytics. |
| **Battery** | Negligible. 60s timer triggers a local disk read, nothing else. |
| **Disk** | Read-only access to `~/.claude/projects/`. Never writes anything. |

---

## Privacy & Security

- **No credentials stored** — reads only the subscription type from Keychain (the same entry the CLI manages), never the OAuth tokens
- **No network** — zero outbound connections, ever
- **No sandbox** — required to access `~/.claude/` (standard for menu bar utilities)
- **Open source** — every line of code is auditable here

---

## Project structure

```
claude-toolbar/
├── Package.swift
├── Makefile
└── Sources/ClaudeToolbar/
    ├── main.swift
    ├── AppDelegate.swift
    ├── MenuBarController.swift
    ├── Models/
    │   └── UsageModels.swift             # PeriodUsage · DailyUsage · BurnRate · RateLimitInfo · SubscriptionPlan · CLIUsageData
    ├── Services/
    │   ├── ClaudeAPIService.swift        # CLIUsageService — reads .jsonl, detects windows, calibrates limits
    │   ├── KeychainCredentialsService.swift  # reads plan from macOS Keychain
    │   ├── NotificationService.swift    # UNUserNotificationCenter threshold alerts
    │   └── L10n.swift                   # LocalizationManager — 7 languages
    ├── ViewModels/
    │   └── UsageViewModel.swift          # @MainActor · plan detection · calibrated limits · burn rate · notifications
    └── Views/
        ├── ContentView.swift             # Main popover + settings toggle
        ├── UsageBarView.swift            # UsageCardView with progress bar + burn rate + calibration badge
        ├── DailyHistoryChartView.swift   # 7-day bar chart
        ├── SettingsView.swift            # Language · Notifications · Limits · About
        └── ClaudeLogoView.swift          # Claude logo in SwiftUI
```

**Stack:** Swift 6 · SwiftUI · AppKit · Security.framework · UserNotifications.framework · SPM · macOS 13+

---

## Manual limit override

```bash
defaults write com.claudetoolbar.menubar windowOutputLimit -int 88000
defaults write com.claudetoolbar.menubar weeklyOutputLimit -int 3080000
```

Use "Reset to plan defaults" in Settings to restore auto-detected values. Note: manual overrides are ignored when a calibrated limit is available from rate limit history.

---

## Uninstall

```bash
pkill ClaudeToolbar
rm -rf /Applications/ClaudeToolbar.app
```

---

## Contributing

1. Fork the repo
2. Branch from `main`: `git checkout -b feature/your-feature`
3. Make your changes
4. Open a PR → `main`

Commit style: `feat:`, `fix:`, `chore:`, `docs:`

---

## License

MIT — see [LICENSE](LICENSE)
