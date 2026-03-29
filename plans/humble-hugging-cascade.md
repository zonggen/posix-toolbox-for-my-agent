# Plan: Fast CLI Tools for Agentic Code Exploration

## Context

AI agents spend ~70% of tool calls on search/read operations using slow defaults (`grep`, `find`, `cat`). Rust-based CLI tools are 5-50x faster. We need agents to **always** use fast tools — this is a global default behavior, not a sometimes-relevant skill.

Three-layer approach:
1. **Global rule** — always-on "use fast tools" instructions. Never skipped.
2. **Brewfile + thin setup script** — one-time install. Not agent-facing.
3. **Lightweight skill** — only for compound scripts (`repo_manifest.sh`, `smart_search.sh`).

## Current State

- `~/.claude/CLAUDE.md` — exists, empty
- `~/.cursor/rules/` — has 2 memory-manager `.mdc` rules
- Installed: `rg`, `fd`, `bat`, `biome`, `uv`
- User maintains a `~/.Brewfile` with their preferred tools

## Agent-Relevant vs Human-Only Tools

From the user's Brewfile, only a subset matters for agentic flows:

| Tool | Agent-relevant? | Why |
|---|---|---|
| `ripgrep` (rg) | **Yes** | Core search, 10-50x faster than grep |
| `fd` | **Yes** | Core file finding, 5-10x faster than find |
| `bat` | **Yes** | Syntax-highlighted file reading with line ranges |
| `eza` | **Yes** | Fast `ls`/`tree` replacement |
| `sd` | **Yes** | Fast `sed` replacement for find-and-replace |
| `tokei` | **Yes** | Language-aware code stats in JSON |
| `jaq` | **Yes** | Rust `jaq` replacement, 2-3x faster, compatible syntax |
| `just` | **Yes** | Task runner — agents can invoke project justfiles |
| `dust` | **Yes** | Fast disk usage for large repo diagnostics |
| `git-delta` | Partial | Better diff output, but agents parse raw diff fine |
| `watchexec` | Partial | Useful for validation loops (`watchexec -e py -- pytest`) |
| `bun` | Partial | Fast npm/node replacement, relevant for JS projects |
| `hyperfine` | No | Benchmarking is human-initiated |
| `fzf` | No | Interactive fuzzy finder — agents don't do interactive selection |
| `zoxide` | No | Interactive cd — agents use absolute paths |
| `gitui` | No | Interactive TUI |
| `starship` | No | Shell prompt cosmetics |
| `tealdeer` | No | Interactive man pages |
| `bottom` | No | Interactive system monitor TUI |
| `procs` | No | Interactive process viewer |
| `bandwhich` | No | Interactive network monitor |

## Deliverables

```
posix-toolbox-for-my-agent/
├── Brewfile                            # Agent-relevant tools only (~15 lines)
├── scripts/
│   ├── setup.sh                        # Thin wrapper: brew bundle + verify (~40 lines)
│   ├── repo_manifest.sh                # One-shot repo orientation JSON (~120 lines)
│   └── smart_search.sh                 # Budgeted batched search (~100 lines)
├── rules/
│   ├── claude-code.md                  # Global rule for ~/.claude/CLAUDE.md (~25 lines)
│   └── cursor.mdc                      # Same rules for .cursor/rules/ (~25 lines)
├── skill/
│   └── posix-skill/
│       ├── SKILL.md                    # Compound scripts only (~60 lines)
│       └── references/
│           ├── tool-cheatsheet.md      # Flag-by-flag examples (~200 lines)
│           └── output-budgeting.md     # Budget defaults & tuning (~60 lines)
└── README.md                           # How to install each layer
```

## Implementation Steps

### Step 1: `Brewfile` — Agent-Relevant Tools Only

A focused Brewfile containing only tools that agents actually invoke:

```ruby
# Search & navigation
brew "ripgrep"      # grep → rg
brew "fd"           # find → fd
brew "eza"          # ls/tree → eza

# File viewing & editing
brew "bat"          # cat → bat
brew "sd"           # sed → sd

# Code intelligence
brew "tokei"        # wc -l → tokei (language-aware)
brew "jaq"          # jq → jaq (Rust, 2-3x faster, compatible syntax)

# Dev workflow
brew "just"         # make → just
brew "dust"         # du → dust
brew "git-delta"    # better git diff output
```

### Step 2: `scripts/setup.sh` — Thin Wrapper (~40 lines)

No hand-rolled per-tool logic. Just wraps `brew bundle`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$SCRIPT_DIR/../Brewfile"

if [[ "${1:-}" == "--check" ]]; then
    # Report installed/missing as JSON
    ...
    exit 0
fi

brew bundle --file="$BREWFILE"
# Verify all tools available, output JSON summary
```

### Step 3: `rules/claude-code.md` — Global Rule (~25 lines)

Content for `~/.claude/CLAUDE.md`. Always loaded, zero activation logic.

```markdown
# CLI Tool Preferences

Use these fast alternatives instead of slow defaults:

| Instead of | Use | Key flags |
|---|---|---|
| `find` | `fd` | `-e ext`, `-t f/d`, `-d depth`, `--max-results N` |
| `grep -r` | `rg` | `--type py`, `--json`, `-m N` (max per file), `-C N` (context) |
| `cat` | `bat --plain` | `-r START:END` (line range), `-n` (line numbers) |
| `ls -R` / `tree` | `eza --tree` | `-L depth`, `--git-ignore` |
| `wc -l` (code stats) | `tokei` | `--output json` |
| `sed 's/old/new/'` | `sd 'old' 'new'` | Simpler regex, no escaping delimiters |
| `du` | `dust` | `-d depth` |

Rules:
- Always type-filter: `rg --type py`, `fd -e ts` — skip irrelevant files
- Prefer JSON output: `rg --json`, `tokei --output json` — structured > free text
- Budget output: `fd --max-results 50`, `rg -m 5` — prevent context flooding
- Targeted reads: use `bat -r START:END` when you have line numbers, never read entire large files
- Chain search → read: search gives line numbers, read uses them
```

### Step 4: `rules/cursor.mdc` — Same for Cursor

Same content wrapped in Cursor's `.mdc` frontmatter:

```markdown
---
description: Use fast Rust-based CLI tools for all file operations
globs:
alwaysApply: true
---

(same content as claude-code.md)
```

### Step 5: `scripts/repo_manifest.sh` — One-Shot Orientation (~120 lines)

```bash
scripts/repo_manifest.sh [--path /repo] [--refresh] [--depth 3]
```

Output:
```json
{
  "generated_at": "...",
  "repo_root": "/path/to/repo",
  "git": { "branch": "main", "status": "clean", "recent_commits": [...] },
  "file_tree": ["src/main.py", ...],
  "language_stats": { "Python": { "files": 45, "lines": 12000 }, ... },
  "key_files": ["README.md", "pyproject.toml", "Makefile"],
  "counts": { "files": 234, "dirs": 56 }
}
```

- File tree: `fd -t f -d $DEPTH --strip-cwd-prefix`
- Language stats: `tokei --output json` (fallback: `fd` + extension counting via `jaq`)
- Git state: `git branch/status/log`
- Key files: `fd -t f -d 1` filtered against known config file names
- JSON assembly: `jaq` (fallback: `python3`)
- Cache: `.posix-skill/manifest.json`, invalidate on HEAD change or >5 min

### Step 6: `scripts/smart_search.sh` — Budgeted Search (~100 lines)

```bash
smart_search.sh content "def create_user" --type py --budget 200
smart_search.sh files "*.test.ts" --budget 50
smart_search.sh batch "pattern1" "pattern2" --type py
```

JSON envelope:
```json
{
  "mode": "content",
  "patterns": ["def create_user"],
  "total_matches": 47,
  "budget": 200,
  "truncated": false,
  "results": [...]
}
```

### Step 7: `skill/posix-skill/SKILL.md` — Lightweight Skill

Only documents the compound scripts. Basic tool substitution lives in the global rule.

```yaml
---
name: posix-skill
description: >
  POSIX-oriented compound code exploration: repo_manifest.sh for one-shot repo
  orientation (JSON manifest of file tree, language stats, git state),
  smart_search.sh for budgeted batched search with structured JSON output.
license: Proprietary
---
```

Body: usage for `repo_manifest.sh`, `smart_search.sh`, pointer to `references/`.

### Step 8: Reference Files

- `references/tool-cheatsheet.md` — Flag examples for rg, fd, bat, tokei, eza, sd, jaq, just. Pure reference.
- `references/output-budgeting.md` — Why budget, defaults (200 lines / 50 files), how to tune.

## Implementation Order

1. `Brewfile` + `scripts/setup.sh` — install tools first
2. `rules/claude-code.md` — highest impact, always-on global rule
3. `rules/cursor.mdc` — same for Cursor
4. `scripts/repo_manifest.sh` — highest-value compound script
5. `scripts/smart_search.sh` — second compound script
6. `skill/` + `references/` — on-demand skill and docs
7. `README.md` — installation instructions for each layer

## Verification

1. `scripts/setup.sh --check` → JSON of installed/missing tools
2. `scripts/setup.sh` → installs missing, re-run `--check` confirms all present
3. Copy `rules/claude-code.md` into `~/.claude/CLAUDE.md`, new session → agent uses `rg`/`fd` by default
4. `scripts/repo_manifest.sh --path /path/to/real/repo` → valid JSON, all fields populated
5. `scripts/smart_search.sh content "import" --type py --budget 10` → truncated JSON envelope
6. Uninstall `tokei`, run manifest → graceful fallback to extension counting
