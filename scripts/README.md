# Scripts

## setup.sh

Installs agent-relevant CLI tools via Homebrew. Wraps `brew bundle` on the repo's Brewfile.

```bash
./scripts/setup.sh          # Install all tools
./scripts/setup.sh --check  # Report installed/missing as JSON (no changes)
```

**Side effects:** Installs Homebrew packages system-wide (`rg`, `fd`, `bat`, `eza`, `sd`, `tokei`, `jaq`, `just`, `dust`, `git-delta`).

## repo_manifest.sh

Generates a one-shot JSON overview of a repository: file tree, language stats, git state, key config files, and file/dir counts.

```bash
./scripts/repo_manifest.sh [--path /repo] [--depth 3] [--refresh]
```

**Side effects:**
- Creates a `.posix-skill/` cache directory inside the target repo.
- Writes `.posix-skill/manifest.json` (cached for 5 minutes, invalidated on HEAD change).
- Appends `.posix-skill/` to the target repo's `.gitignore` if not already present.

## smart_search.sh

Budgeted search wrapper around `rg` and `fd`. Returns structured JSON envelopes with match counts and truncation indicators.

```bash
./scripts/smart_search.sh content "pattern" [--type py] [--budget 200] [--context 3]
./scripts/smart_search.sh files "pattern" [--ext py] [--budget 50]
./scripts/smart_search.sh batch "pat1" "pat2" [--type py] [--budget 200]
```

**Side effects:** None. Read-only search, output to stdout.
