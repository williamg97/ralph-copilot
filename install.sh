#!/usr/bin/env bash
# Ralph — Installer / Updater
# Usage:
#   # Public repo (or with gh CLI authenticated):
#   curl -fsSL https://raw.githubusercontent.com/williamg97/ralph-copilot/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/williamg97/ralph-copilot/main/install.sh | sh -s -- --branch dev
#   curl -fsSL https://raw.githubusercontent.com/williamg97/ralph-copilot/main/install.sh | sh -s -- --force
#
#   # Private repo — set a token or use gh CLI:
#   GITHUB_TOKEN=ghp_xxx ./install.sh
#   gh auth login  # then the script auto-detects the token
#
# Installs Ralph agent files into .github/ in the current directory.
# Safe to re-run — updates .github/ files but preserves your AGENTS.md unless --force is passed.

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
REPO="williamg97/ralph-copilot"
BRANCH="main"
FORCE=false

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch|-b)
      BRANCH="$2"
      shift 2
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      echo "Usage: install.sh [--branch <ref>] [--force]"
      echo ""
      echo "Options:"
      echo "  --branch, -b <ref>  Git branch/tag/SHA to install from (default: main)"
      echo "  --force, -f         Overwrite AGENTS.md even if it already exists"
      echo "  --help, -h          Show this help message"
      echo ""
      echo "Authentication (for private repos):"
      echo "  Set GITHUB_TOKEN or GH_TOKEN, or install the gh CLI and run 'gh auth login'."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage information."
      exit 1
      ;;
  esac
done

# ── Helper functions ─────────────────────────────────────────────────────────
info()  { printf "\033[1;34m▸\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m✔\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m✖\033[0m %s\n" "$1" >&2; exit 1; }

# ── Resolve auth token ──────────────────────────────────────────────────────
AUTH_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$AUTH_TOKEN" ]] && command -v gh >/dev/null 2>&1; then
  AUTH_TOKEN=$(gh auth token 2>/dev/null || true)
fi
if [[ -z "$AUTH_TOKEN" ]]; then
  # Try git's credential helper (e.g., macOS keychain, credential-manager)
  AUTH_TOKEN=$(printf "protocol=https\nhost=github.com\n" | git credential fill 2>/dev/null | grep "^password=" | cut -d= -f2 || true)
fi

# ── Verify prerequisites ────────────────────────────────────────────────────
if ! command -v tar >/dev/null 2>&1; then
  error "tar is required but not found. Please install it and try again."
fi

# Build the download command with optional auth header
download() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    if [[ -n "$AUTH_TOKEN" ]]; then
      curl -fsSL -H "Authorization: token ${AUTH_TOKEN}" "$url"
    else
      curl -fsSL "$url"
    fi
  elif command -v wget >/dev/null 2>&1; then
    if [[ -n "$AUTH_TOKEN" ]]; then
      wget -qO- --header="Authorization: token ${AUTH_TOKEN}" "$url"
    else
      wget -qO- "$url"
    fi
  else
    error "Neither curl nor wget found. Please install one and try again."
  fi
}

# ── Create temp directory with cleanup trap ──────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ── Download and extract ─────────────────────────────────────────────────────
# Use the API endpoint for authenticated requests (works with private repos),
# fall back to the public archive URL for unauthenticated requests.
if [[ -n "$AUTH_TOKEN" ]]; then
  ARCHIVE_URL="https://api.github.com/repos/${REPO}/tarball/${BRANCH}"
else
  ARCHIVE_URL="https://github.com/${REPO}/archive/${BRANCH}.tar.gz"
fi
info "Downloading Ralph from ${REPO}@${BRANCH}..."

if ! download "$ARCHIVE_URL" | tar -xz -C "$TMPDIR" 2>/dev/null; then
  if [[ -z "$AUTH_TOKEN" ]]; then
    error "Failed to download. If this is a private repo, set GITHUB_TOKEN or run 'gh auth login'."
  else
    error "Failed to download from ${REPO}@${BRANCH}. Check the branch name and try again."
  fi
fi

# GitHub tarballs extract into a directory named {repo}-{branch}
# The branch name may have slashes replaced with hyphens
EXTRACTED=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -1)
if [[ -z "$EXTRACTED" || ! -d "$EXTRACTED/.github" ]]; then
  error "Unexpected archive structure. Could not find .github/ in extracted files."
fi

# ── Install .github/ directory ───────────────────────────────────────────────
info "Installing agent files into .github/..."

# Create target directories
mkdir -p .github/agents
mkdir -p .github/prompts

# Copy all .github/ contents, overwriting existing files
cp -R "$EXTRACTED/.github/agents/"* .github/agents/
cp -R "$EXTRACTED/.github/prompts/"* .github/prompts/

ok "Installed .github/agents/ (3 agent files)"
ok "Installed .github/prompts/ (2 slash commands)"

# ── Install AGENTS.md (conditionally) ───────────────────────────────────────
if [[ -f "AGENTS.md" ]] && [[ "$FORCE" = false ]]; then
  warn "AGENTS.md already exists — skipping to preserve your config"
  echo "    Run with --force to overwrite it with the latest template."
  AGENTS_STATUS="skipped"
else
  cp "$EXTRACTED/AGENTS.md" ./AGENTS.md
  if [[ "$FORCE" = true ]] && [[ -f "AGENTS.md" ]]; then
    AGENTS_STATUS="overwritten"
  else
    AGENTS_STATUS="created"
  fi
  ok "Installed AGENTS.md (${AGENTS_STATUS})"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Ralph installed successfully!"
echo ""
echo "  Installed from: ${REPO}@${BRANCH}"
echo "  AGENTS.md:      ${AGENTS_STATUS}"
echo ""

if [[ "$AGENTS_STATUS" = "created" || "$AGENTS_STATUS" = "overwritten" ]]; then
  info "Next step: Open AGENTS.md and replace the TODO markers with your project's values."
  echo "    Or let the ralph-plan agent auto-detect them when you first run /plan."
fi

echo ""
echo "  Usage in VS Code Chat:"
echo "    • Select the 'prd' agent → describe a feature"
echo "    • Select 'ralph-plan' → decompose a PRD into tasks"
echo "    • Select 'ralph-loop' → execute the implementation loop"
echo "    • Or use /prd and /plan slash commands"
echo ""
