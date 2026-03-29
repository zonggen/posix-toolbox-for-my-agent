# POSIX Toolbox

Fast CLI tools and agentic workflow optimizations for AI-assisted code exploration.

Three layers, install what you need:

## 1. Install Tools

```bash
# Install all agent-relevant CLI tools
./scripts/setup.sh

# Check what's installed/missing
./scripts/setup.sh --check
```

This runs `brew bundle` on the included [Brewfile](Brewfile) which installs: `rg`, `fd`, `bat`, `eza`, `sd`, `tokei`, `jaq`, `just`, `dust`, `git-delta`.

## 2. Global Rules (always-on tool preferences)

Copy the appropriate rule file so your agent always uses fast tools:

**Claude Code:**
```bash
# Copy to global rules directory (recommended)
cp rules/claude-code.md ~/.claude/rules/posix-rule.md

# Or append to global CLAUDE.md
cat rules/claude-code.md >> ~/.claude/CLAUDE.md
```

**Cursor:**
```bash
# Copy to Cursor rules directory
cp rules/cursor.mdc ~/.cursor/rules/posix-rule.mdc
```

This teaches agents to use `fd` instead of `find`, `rg` instead of `grep`, `bat` instead of `cat`, etc.

## 3. Skill (compound scripts)

For the on-demand compound scripts (`repo_manifest.sh`, `smart_search.sh`), install as a skill:

```bash
# Symlink into your skills directory
ln -s "$(pwd)/skill/posix-skill" ~/.agents/skills/posix-skill
```

### Scripts

**Repo Manifest** — one-shot repo orientation:
```bash
./scripts/repo_manifest.sh --path /path/to/repo --depth 3
```

Returns JSON with file tree, language stats, git state, key files. Cached for 5 minutes.

**Smart Search** — budgeted search with JSON output:
```bash
# Content search
./scripts/smart_search.sh content "def create_user" --type py --budget 200

# File discovery
./scripts/smart_search.sh files "test" --ext py --budget 50

# Multi-pattern batch
./scripts/smart_search.sh batch "class Foo" "def bar" "import.*Foo" --type py
```

## Tool Reference

| Slow default | Fast alternative | Speedup |
| --- | --- | --- |
| `find` | `fd` | 5-10x |
| `grep -r` | `rg` | 10-50x |
| `cat` | `bat` | syntax highlighting + line ranges |
| `ls -R` / `tree` | `eza --tree` | 2-3x |
| `sed` | `sd` | 2-6x, simpler syntax |
| `wc -l` | `tokei` | language-aware, JSON output |
| `jq` | `jaq` | 2-3x (Rust) |
| `du` | `dust` | 2-5x, better output |
