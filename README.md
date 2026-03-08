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
║  🟠 Claude Code  [Pro]             ↻  ⏻ ║
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
╠══════════════════════════════════════════╣
║  📅 Last 7 days                          ║
║                                          ║
║  404.2K                         $29.95   ║
║  tokens generated               API ref  ║
║  █████████████████░░  54%               ║
║  404.2K / 750K tok · 824 calls           ║
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
| **Call count** | Number of Claude API interactions per period. |
| **Daily history** | Mini bar chart of output tokens per day for the last 7 days. |

> **Why not total tokens?** `cache_read_input_tokens` inflate the count massively (they represent the same cached context re-read on every call — not new work). Claude Toolbar shows only `input + output` as the meaningful total, and excludes cache-read from the display. Cache tokens are still included in the cost reference since they have a real per-token cost.

---

## Requirements

- **macOS 13.0+** (Ventura or later)
- **[Claude Code CLI](https://claude.ai/code)** — the app reads session files created by `claude` in the terminal. If you've ever run `claude`, you're set. If not, install it first and run any command — the `~/.claude/` directory will be created automatically.
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

On first open, Claude Toolbar looks for `~/.claude/projects/` — the directory Claude Code creates automatically when you run any `claude` command.

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
    ├─ parses assistant messages          from Claude Code credentials
    └─ aggregates by period                    │
          │                                    │
          └──────────────┬─────────────────────┘
                         ▼
              UsageViewModel (@MainActor)
                ├─ applies plan limits (Pro / Max5 / Max20)
                └─ refreshes every 60 seconds
                         │
                         ▼
              Menu Bar Popover (SwiftUI)
                ├─ tokens + cost + % progress bars
                └─ 7-day daily bar chart
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

### Manual override

You can override the detected limits at any time:

```bash
defaults write com.claudetoolbar.menubar dailyOutputLimit  -int 200000
defaults write com.claudetoolbar.menubar weeklyOutputLimit -int 1000000
```

To restore auto-detected plan defaults, delete the override keys:

```bash
defaults delete com.claudetoolbar.menubar dailyOutputLimit
defaults delete com.claudetoolbar.menubar weeklyOutputLimit
```

---

## 7-day bar chart

The daily history chart at the bottom of the popover shows one bar per day for the last 7 calendar days. Bar heights are proportional to that day's output tokens — the tallest bar represents the peak day.

- **Today's bar** is highlighted
- **Click any bar** to see the exact token count and API cost reference for that day
- **Hover** for a native macOS tooltip

---

## Performance

Claude Toolbar is designed to have **zero impact** on your Mac:

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

`~/.claude/projects/` files contain your conversation history. They stay on your machine — Claude Toolbar never touches them beyond reading token counts.

---

## Project structure

```
claude-toolbar/
├── Package.swift
├── Makefile
└── Sources/ClaudeToolbar/
    ├── main.swift                        # AppKit entry point
    ├── AppDelegate.swift
    ├── MenuBarController.swift           # NSStatusItem + NSPopover + Claude logo
    ├── Models/
    │   └── UsageModels.swift             # PeriodUsage · DailyUsage · SubscriptionPlan · CLIUsageData
    ├── Services/
    │   ├── ClaudeAPIService.swift        # Reads ~/.claude/projects/**/*.jsonl
    │   └── KeychainCredentialsService.swift  # Reads plan from macOS Keychain
    ├── ViewModels/
    │   └── UsageViewModel.swift          # @MainActor · plan detection · auto-refresh
    └── Views/
        ├── ContentView.swift             # Main popover layout
        ├── UsageBarView.swift            # UsageCardView with progress bar
        ├── DailyHistoryChartView.swift   # 7-day bar chart
        └── ClaudeLogoView.swift          # Claude logo built in SwiftUI
```

**Stack:** Swift 6 · SwiftUI · AppKit · Security.framework · Swift Package Manager · macOS 13+

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
