---
name: posix-skill
description: >
  POSIX-oriented compound code exploration: repo_manifest.sh for one-shot repo
  orientation (JSON manifest of file tree, language stats, git state),
  smart_search.sh for budgeted batched search with structured JSON output.
license: Proprietary
---

# POSIX Skill

Compound scripts for efficient agentic code exploration. Basic tool substitution (rg, fd, bat, etc.) is handled by the global CLI rule — this skill covers multi-step operations.

## Orient — Repo Manifest

Generate a full repo overview in one call:

```bash
scripts/repo_manifest.sh [--path /repo] [--depth 3] [--refresh]
```

Returns JSON with: file tree, language stats (via tokei), git branch/status/commits, key config files, file/dir counts. Results are cached for 5 minutes (invalidated on HEAD change). Use `--refresh` to force regeneration.

## Search — Budgeted Search

Search with output caps and structured JSON envelopes:

```bash
# Content search (rg wrapper, default budget: 200 lines)
scripts/smart_search.sh content "pattern" --type py --budget 200 --context 3

# File discovery (fd wrapper, default budget: 50 results)
scripts/smart_search.sh files "pattern" --ext py --budget 50

# Multi-pattern batch (budget divided across patterns)
scripts/smart_search.sh batch "class Foo" "def bar" "import.*Foo" --type py
```

All modes return a JSON envelope with `total_matches`, `budget`, `truncated`, and `results`.

## When to Use

- **Entering a new repo**: Run `repo_manifest.sh` first to orient before any targeted search.
- **Broad exploratory search**: Use `smart_search.sh` to prevent context flooding.
- **Multi-pattern investigation**: Use `batch` mode instead of sequential rg calls.

For detailed tool flags and output budgeting guidance, see `references/`.
