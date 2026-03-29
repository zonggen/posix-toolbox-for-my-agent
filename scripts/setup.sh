#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$SCRIPT_DIR/../Brewfile"

# Binary names to check
TOOLS=(rg fd eza bat sd tokei jaq just dust delta)

check_tools() {
  local installed=()
  local missing=()

  for bin in "${TOOLS[@]}"; do
    if command -v "$bin" &>/dev/null; then
      installed+=("\"$bin\"")
    else
      missing+=("\"$bin\"")
    fi
  done

  local installed_str=""
  local missing_str=""
  [[ ${#installed[@]} -gt 0 ]] && installed_str=$(IFS=,; echo "${installed[*]}")
  [[ ${#missing[@]} -gt 0 ]] && missing_str=$(IFS=,; echo "${missing[*]}")

  cat <<EOF
{
  "installed": [$installed_str],
  "missing": [$missing_str],
  "total": ${#TOOLS[@]},
  "installed_count": ${#installed[@]},
  "missing_count": ${#missing[@]}
}
EOF
}

case "${1:-install}" in
  --check)
    check_tools
    ;;
  install|"")
    if ! command -v brew &>/dev/null; then
      echo "Error: Homebrew not found. Install from https://brew.sh" >&2
      exit 1
    fi

    echo "Installing agent-relevant CLI tools..."
    brew bundle --file="$BREWFILE"

    echo ""
    echo "Verification:"
    check_tools
    ;;
  *)
    echo "Usage: setup.sh [--check | install]" >&2
    exit 1
    ;;
esac
