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
║  🕐 Current session           just now  ║
║                                          ║
║  311.6K                         $20.93   ║
║  tokens generated               API ref  ║
║  ● 550 calls · Sonnet                    ║
╠══════════════════════════════════════════╣
║  ☀️  Today                      2m ago   ║
║                                          ║
║  46.9K                           $3.21   ║
║  tokens generated               API ref  ║
║  ████████████░░░░░░  31%                 ║
║  46.9K / 150K tok · 105 calls            ║
║  🔥 12.3K/h · límite en ~8h 20m         ║
╠══════════════════════════════════════════╣
║  📅 Last 7 days                          ║
║                                          ║
║  404.2K                         $29.95   ║
║  tokens generated               API ref  ║
║  █████████████████░░  54%               ║
║  404.2K / 750K tok · 824 calls           ║
╠══════════════════════════════════════════╣
║  ⛔ Límite alcanzado hace 2h             ║
║     Se restablece: 4pm (Atlantic/Canary) ║
╠══════════════════════════════════════════╣
║  📊 Daily history                        ║
║   ▂  ▅  █  ▃  ▁  ▄  ▇                   ║
║  Mon Tue Wed Thu Fri Sat Sun             ║
╠══════════════════════════════════════════╣
║  API ref: public Anthropic pricing       ║
║                          updated 1s ago  ║
╚══════════════════════════════════════════╝
```

---

## What it tracks

| Metric | What it means |
|--------|--------------|
| **Tokens generated** | `output_tokens` — what Claude actually wrote. The real measure of work done. |
| **API cost ref.** | Estimated cost at public Anthropic pricing. Useful even on a Pro subscription as a consumption reference. |
| **Usage %** | Today and weekly progress bars vs your plan's default limits (auto-detected). |
| **Burn rate** | Token velocity of the active session (K/h) and predicted time to daily limit. |
| **Call count** | Number of Claude API interactions per period. |
| **Daily history** | Mini bar chart of output tokens per day for the last 7 days. |
| **Rate limit reset** | When the platform limit has been hit, shows when it resets — read from local session files, no network needed. |

> **Why not total tokens?** `cache_read_input_tokens` inflate the count massively (they represent the same cached context re-read on every call — not new work). Claude Toolbar shows only `input + output` as the meaningful total, and excludes cache-read from the display. Cache tokens are still included in the cost reference since they have a real per-token cost.

---

## Requirements

- **macOS 13.0+** (Ventura or later)
- **[Claude Code CLI](https://claude.ai/code)** — the app reads session files created by `claude` in the terminal. If you've ever run `claude`, you're set.
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
    ├─ aggregates by period
    ├─ computes session burn rate
    └─ detects rate limit reset time
          │
          ▼
  UsageViewModel (@MainActor)
    ├─ applies plan limits (Pro / Max5 / Max20)
    ├─ refreshes every 60 seconds
    └─ fires threshold notifications (70%, 90%)
          │
          ▼
  Menu Bar Popover (SwiftUI)
    ├─ tokens + cost + % progress bars
    ├─ burn rate prediction
    ├─ 7-day daily bar chart
    └─ ⚙️ settings panel
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

## Auto plan detection

Claude Toolbar automatically detects your subscription plan by reading the `Claude Code-credentials` entry the CLI stores in your macOS Keychain. No manual setup needed.

| Plan | Daily limit | Weekly limit |
|------|------------|--------------|
| **Pro** | 150,000 output tokens | 750,000 output tokens |
| **Max 5×** | 375,000 output tokens | 1,875,000 output tokens |
| **Max 20×** | 750,000 output tokens | 3,750,000 output tokens |

The detected plan name is shown as a badge in the popover header. If you upgrade or change plans, the limits update automatically on the next app launch.

---

## Burn rate

When an active session is detected (last activity within 30 minutes, at least 5 minutes of data), a burn rate row appears below the daily progress bar:

- **`🔥 12.3K/h · límite en ~8h 20m`** — normal state (orange)
- Turns **red** when fewer than 2 hours remain to the daily limit
- Shows `"límite superado"` if the limit is already exceeded

The rate is computed as `output_tokens ÷ session_duration_hours`. Time to limit is `remaining_tokens ÷ rate`.

---

## Rate limit reset time

When the Claude Code CLI hits a platform rate limit, it logs the event in the local session files. Claude Toolbar surfaces this data as a banner between the usage cards and the daily chart:

- **If hit today** → `⛔ Límite alcanzado hace 2h · Se restablece: 4pm (Atlantic/Canary)` in red
- **If hit previously** → muted `🕐 Último límite hace 1d · Se restablece: 1pm (...)` in grey

If you've never hit the limit, the banner doesn't appear. No API calls needed — the reset time is extracted directly from `~/.claude/projects/**/*.jsonl`.

---

## 7-day bar chart

The daily history chart shows one bar per day for the last 7 calendar days, proportional to that day's output tokens.

- **Today's bar** is highlighted
- **Click any bar** to see the exact token count and API cost reference
- **Hover** for a native macOS tooltip

---

## Notifications

Claude Toolbar sends native macOS alerts when daily or weekly usage crosses **70%** and **90%** of your limits. Each threshold fires at most once per day (daily) or once per ISO week (weekly).

**Tapping a notification** opens the menu bar popover automatically.

Toggle notifications off in the **⚙️ Settings** panel inside the app.

---

## Settings

Click the **⚙️** button in the header to open the settings panel:

| Setting | Description |
|---------|-------------|
| **Notification toggle** | Enable/disable threshold alerts |
| **Limits display** | Shows current daily/weekly limits |
| **Reset to plan defaults** | Discards manual overrides and restores auto-detected plan limits |
| **About** | Data source path, network status |

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
    │   ├── ClaudeAPIService.swift        # CLIUsageService — reads ~/.claude/projects/**/*.jsonl
    │   ├── KeychainCredentialsService.swift  # reads plan from macOS Keychain
    │   └── NotificationService.swift    # UNUserNotificationCenter threshold alerts
    ├── ViewModels/
    │   └── UsageViewModel.swift          # @MainActor · plan detection · burn rate · notifications
    └── Views/
        ├── ContentView.swift             # Main popover + settings toggle
        ├── UsageBarView.swift            # UsageCardView with progress bar + burn rate row
        ├── DailyHistoryChartView.swift   # 7-day bar chart
        ├── SettingsView.swift            # Notifications toggle + limits + about
        └── ClaudeLogoView.swift          # Claude logo in SwiftUI
```

**Stack:** Swift 6 · SwiftUI · AppKit · Security.framework · UserNotifications.framework · SPM · macOS 13+

---

## Manual limit override

```bash
defaults write com.claudetoolbar.menubar dailyOutputLimit  -int 200000
defaults write com.claudetoolbar.menubar weeklyOutputLimit -int 1000000
```

Use "Reset to plan defaults" in Settings to restore auto-detected values.

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
