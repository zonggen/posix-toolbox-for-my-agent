#!/usr/bin/env bash
set -euo pipefail

# repo_manifest.sh — One-shot repo orientation as JSON
# Replaces 5-10 individual tool calls with a single structured output.
#
# Usage:
#   repo_manifest.sh [--path /repo] [--depth 3] [--refresh]

REPO_PATH="."
DEPTH=3
REFRESH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)   REPO_PATH="$2"; shift 2 ;;
    --depth)  DEPTH="$2"; shift 2 ;;
    --refresh) REFRESH=true; shift ;;
    -h|--help)
      echo "Usage: repo_manifest.sh [--path DIR] [--depth N] [--refresh]" >&2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

cd "$REPO_PATH"
REPO_ROOT="$(pwd)"

# --- Cache logic ---
CACHE_DIR=".posix-skill"
CACHE_FILE="$CACHE_DIR/manifest.json"
CACHE_MAX_AGE=300  # 5 minutes

if [[ "$REFRESH" == false && -f "$CACHE_FILE" ]]; then
  # Check age
  if [[ "$(uname)" == "Darwin" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  else
    cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  fi

  # Check if git HEAD matches cached
  cached_head=""
  if command -v jaq &>/dev/null; then
    cached_head=$(jaq -r '.git.head // ""' "$CACHE_FILE" 2>/dev/null || echo "")
  elif command -v python3 &>/dev/null; then
    cached_head=$(python3 -c "import json,sys; print(json.load(open('$CACHE_FILE')).get('git',{}).get('head',''))" 2>/dev/null || echo "")
  fi

  current_head=$(git rev-parse --short HEAD 2>/dev/null || echo "")

  if [[ $cache_age -lt $CACHE_MAX_AGE && "$cached_head" == "$current_head" ]]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# --- Collect data ---

# Git state
git_branch=$(git branch --show-current 2>/dev/null || echo "detached")
git_head=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
git_status_raw=$(git status --porcelain 2>/dev/null || echo "")
if [[ -z "$git_status_raw" ]]; then
  git_status="clean"
else
  git_status="dirty"
fi
if [[ -z "$git_status_raw" ]]; then
  git_dirty_count=0
else
  git_dirty_count=$(echo "$git_status_raw" | wc -l | tr -d ' ')
fi

# Recent commits as JSON array
git_commits="[]"
if command -v git &>/dev/null; then
  git_commits=$(git log --oneline -5 --format='%h %s' 2>/dev/null | while IFS= read -r line; do
    hash="${line%% *}"
    msg="${line#* }"
    # Escape quotes in message
    msg="${msg//\\/\\\\}"
    msg="${msg//\"/\\\"}"
    echo "{\"hash\":\"$hash\",\"msg\":\"$msg\"}"
  done | paste -sd',' - | sed 's/^/[/;s/$/]/' || echo "[]")
  [[ -z "$git_commits" || "$git_commits" == "[]" ]] && git_commits="[]"
fi

# File tree (depth-limited, respects .gitignore)
file_tree="[]"
if command -v fd &>/dev/null; then
  file_tree=$(fd -t f -d "$DEPTH" --strip-cwd-prefix 2>/dev/null | head -500 | while IFS= read -r f; do
    echo "\"$f\""
  done | paste -sd',' - | sed 's/^/[/;s/$/]/' || echo "[]")
  [[ -z "$file_tree" || "$file_tree" == "[]" ]] && file_tree="[]"
fi

# File and directory counts
file_count=$(fd -t f --strip-cwd-prefix 2>/dev/null | wc -l | tr -d ' ' || echo "0")
dir_count=$(fd -t d --strip-cwd-prefix 2>/dev/null | wc -l | tr -d ' ' || echo "0")

# Language stats
lang_stats="{}"
if command -v tokei &>/dev/null; then
  lang_stats=$(tokei --output json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
result = {}
for lang, info in data.items():
    if lang in ('Total',): continue
    if isinstance(info, dict) and 'code' in info:
        result[lang] = {'files': len(info.get('reports', [])), 'lines': info['code']}
print(json.dumps(result))
" 2>/dev/null || echo "{}")
elif command -v fd &>/dev/null; then
  # Fallback: count files by extension
  lang_stats=$(fd -t f --strip-cwd-prefix 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15 | while read -r count ext; do
    echo "\".$ext\":{\"files\":$count}"
  done | paste -sd',' - | sed 's/^/{/;s/$/}/' || echo "{}")
fi
[[ -z "$lang_stats" ]] && lang_stats="{}"

# Key files detection
known_files="README.md README.rst README.txt LICENSE LICENSE.md CHANGELOG.md
Makefile justfile Dockerfile docker-compose.yml docker-compose.yaml
package.json tsconfig.json pyproject.toml setup.py setup.cfg
Cargo.toml go.mod go.sum Gemfile build.gradle pom.xml
.gitignore .env.example CLAUDE.md .cursorrules"

key_files="[]"
found_files=()
for f in $known_files; do
  if [[ -f "$f" ]]; then
    found_files+=("\"$f\"")
  fi
done
if [[ ${#found_files[@]} -gt 0 ]]; then
  key_files="[$(IFS=,; echo "${found_files[*]}")]"
fi

# --- Assemble JSON ---
manifest=$(cat <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repo_root": "$REPO_ROOT",
  "git": {
    "branch": "$git_branch",
    "head": "$git_head",
    "status": "$git_status",
    "dirty_files": $git_dirty_count,
    "recent_commits": $git_commits
  },
  "file_tree": $file_tree,
  "language_stats": $lang_stats,
  "key_files": $key_files,
  "counts": {
    "files": $file_count,
    "dirs": $dir_count
  }
}
EOF
)

# Pretty-print if jaq/python3 available, otherwise raw
if command -v jaq &>/dev/null; then
  output=$(echo "$manifest" | jaq '.' 2>/dev/null || echo "$manifest")
elif command -v python3 &>/dev/null; then
  output=$(echo "$manifest" | python3 -m json.tool 2>/dev/null || echo "$manifest")
else
  output="$manifest"
fi

# Cache the result
mkdir -p "$CACHE_DIR"
echo "$output" > "$CACHE_FILE"

# Add cache dir to .gitignore if not already there
if [[ -f .gitignore ]]; then
  if ! grep -qF "$CACHE_DIR" .gitignore 2>/dev/null; then
    echo "$CACHE_DIR/" >> .gitignore
  fi
fi

echo "$output"
