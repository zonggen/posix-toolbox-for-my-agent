#!/usr/bin/env bash
set -eo pipefail

# smart_search.sh — Budgeted search with structured JSON output
# Wraps rg/fd with output caps and JSON envelopes.
#
# Usage:
#   smart_search.sh content "pattern" [--type py] [--budget 200] [--context 3]
#   smart_search.sh files "pattern" [--budget 50] [--ext py]
#   smart_search.sh batch "pat1" "pat2" ... [--type py] [--budget 100]

MODE="${1:-}"
shift || true

if [[ -z "$MODE" || "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  cat >&2 <<'USAGE'
Usage:
  smart_search.sh content "pattern" [--type TYPE] [--budget N] [--context N]
  smart_search.sh files "pattern"   [--ext EXT] [--budget N]
  smart_search.sh batch "p1" "p2"   [--type TYPE] [--budget N]

Modes:
  content   Search file contents (rg wrapper). Default budget: 200 lines.
  files     Find files by name pattern (fd wrapper). Default budget: 50 results.
  batch     Multi-pattern content search. Budget divided across patterns.

Options:
  --type TYPE   File type filter for rg (e.g., py, ts, go)
  --ext EXT     Extension filter for fd (e.g., py, ts)
  --budget N    Max output lines/results (default: 200 for content, 50 for files)
  --context N   Lines of context around matches (content mode only, default: 0)
USAGE
  exit 1
fi

# --- Parse arguments ---
PATTERNS=()
TYPE=""
EXT=""
BUDGET=""
CONTEXT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)    TYPE="$2"; shift 2 ;;
    --ext)     EXT="$2"; shift 2 ;;
    --budget)  BUDGET="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    -*)        echo "Unknown option: $1" >&2; exit 1 ;;
    *)         PATTERNS+=("$1"); shift ;;
  esac
done

if [[ ${#PATTERNS[@]} -eq 0 ]]; then
  echo "Error: at least one pattern required" >&2
  exit 1
fi

# --- Helper: count non-empty lines safely ---
count_lines() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo 0
  else
    echo "$input" | wc -l | tr -d ' '
  fi
}

# --- Helper: escape string for JSON ---
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  echo "$s"
}

# --- Content search mode ---
content_search() {
  local pattern="$1"
  local budget="${BUDGET:-200}"
  local rg_args=(-n)

  [[ -n "$TYPE" ]] && rg_args+=(--type "$TYPE")
  [[ "$CONTEXT" -gt 0 ]] && rg_args+=(-C "$CONTEXT")

  local raw_output
  raw_output=$(rg "${rg_args[@]}" "$pattern" 2>/dev/null || true)

  local total_lines
  total_lines=$(count_lines "$raw_output")

  local budgeted_output
  budgeted_output=$(echo "$raw_output" | head -n "$budget")

  local truncated=false
  [[ "$total_lines" -gt "$budget" ]] && truncated=true

  local match_count
  match_count=$(count_lines "$raw_output")

  local escaped_pattern
  escaped_pattern=$(json_escape "$pattern")

  local results_json=""
  if [[ -n "$raw_output" ]]; then
    results_json=$(echo "$budgeted_output" | while IFS= read -r line; do
      json_escape "$line"
    done | sed 's/^/    "/;s/$/"/' | paste -sd',' -)
  fi

  cat <<EOF
{
  "mode": "content",
  "patterns": ["$escaped_pattern"],
  "total_matches": $match_count,
  "total_output_lines": $total_lines,
  "budget": $budget,
  "truncated": $truncated,
  "results": [
$results_json
  ]
}
EOF
}

# --- File search mode ---
file_search() {
  local pattern="$1"
  local budget="${BUDGET:-50}"
  local fd_args=()

  [[ -n "$EXT" ]] && fd_args+=(-e "$EXT")

  local raw_output
  raw_output=$(fd "${fd_args[@]}" "$pattern" 2>/dev/null || true)

  local total_results
  total_results=$(count_lines "$raw_output")

  local budgeted_output
  budgeted_output=$(echo "$raw_output" | head -n "$budget")

  local truncated=false
  [[ "$total_results" -gt "$budget" ]] && truncated=true

  local escaped_pattern
  escaped_pattern=$(json_escape "$pattern")

  local results_json=""
  if [[ -n "$raw_output" ]]; then
    results_json=$(echo "$budgeted_output" | while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "    \"$(json_escape "$line")\""
    done | paste -sd',' -)
  fi

  cat <<EOF
{
  "mode": "files",
  "patterns": ["$escaped_pattern"],
  "total_results": $total_results,
  "budget": $budget,
  "truncated": $truncated,
  "results": [
$results_json
  ]
}
EOF
}

# --- Batch search mode ---
batch_search() {
  local budget="${BUDGET:-200}"
  local per_pattern_budget=$(( budget / ${#PATTERNS[@]} ))
  [[ "$per_pattern_budget" -lt 10 ]] && per_pattern_budget=10

  local pattern_results=()

  for pattern in "${PATTERNS[@]}"; do
    local rg_args=(-n)
    [[ -n "$TYPE" ]] && rg_args+=(--type "$TYPE")

    local raw_output
    raw_output=$(rg "${rg_args[@]}" "$pattern" 2>/dev/null || true)

    local match_count
    match_count=$(count_lines "$raw_output")

    local budgeted_output
    budgeted_output=$(echo "$raw_output" | head -n "$per_pattern_budget")

    local total_lines
    total_lines=$(count_lines "$raw_output")

    local truncated=false
    [[ "$total_lines" -gt "$per_pattern_budget" ]] && truncated=true

    local escaped_pattern
    escaped_pattern=$(json_escape "$pattern")

    local lines_json=""
    if [[ -n "$raw_output" ]]; then
      lines_json=$(echo "$budgeted_output" | while IFS= read -r line; do
        json_escape "$line"
      done | sed 's/^/        "/;s/$/"/' | paste -sd',' -)
    fi

    pattern_results+=("$(cat <<ENTRY
    {
      "pattern": "$escaped_pattern",
      "matches": $match_count,
      "truncated": $truncated,
      "lines": [
$lines_json
      ]
    }
ENTRY
)")
  done

  local all_patterns
  all_patterns=$(printf '%s\n' "${PATTERNS[@]}" | while IFS= read -r p; do echo "\"$(json_escape "$p")\""; done | paste -sd',' -)

  local joined_results
  joined_results=$(IFS=','; echo "${pattern_results[*]}")

  cat <<EOF
{
  "mode": "batch",
  "patterns": [$all_patterns],
  "budget": $budget,
  "per_pattern_budget": $per_pattern_budget,
  "results": [
$joined_results
  ]
}
EOF
}

# --- Dispatch ---
case "$MODE" in
  content) content_search "${PATTERNS[0]}" ;;
  files)   file_search "${PATTERNS[0]}" ;;
  batch)   batch_search ;;
  *)       echo "Unknown mode: $MODE. Use content, files, or batch." >&2; exit 1 ;;
esac
