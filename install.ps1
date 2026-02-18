# Ralph — Installer / Updater (PowerShell)
# Usage:
#   # Public repo (or with gh CLI authenticated):
#   irm https://raw.githubusercontent.com/williamg97/ralph-copilot/main/install.ps1 | iex
#   .\install.ps1 -Branch dev
#   .\install.ps1 -Force
#
#   # Private repo — set a token or use gh CLI:
#   $env:GITHUB_TOKEN = "ghp_xxx"; .\install.ps1
#   gh auth login  # then the script auto-detects the token
#
# Installs Ralph agent files into .github/ in the current directory.
# Safe to re-run — updates .github/ files but preserves your AGENTS.md unless -Force is passed.

[CmdletBinding()]
param(
    [string]$Branch = "main",
    [switch]$Force,
    [switch]$Help
)

# ── Strict mode ──────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"

# ── Constants ────────────────────────────────────────────────────────────────
$Repo = "williamg97/ralph-copilot"

# ── Helper functions ─────────────────────────────────────────────────────────
function Write-Info  { param([string]$Msg) Write-Host "▸ $Msg" -ForegroundColor Blue }
function Write-Ok    { param([string]$Msg) Write-Host "✔ $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "⚠ $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "✖ $Msg" -ForegroundColor Red; exit 1 }

# ── Help ─────────────────────────────────────────────────────────────────────
if ($Help) {
    Write-Host "Usage: install.ps1 [-Branch <ref>] [-Force]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Branch <ref>  Git branch/tag/SHA to install from (default: main)"
    Write-Host "  -Force         Overwrite AGENTS.md even if it already exists"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Authentication (for private repos):"
    Write-Host "  Set `$env:GITHUB_TOKEN or `$env:GH_TOKEN, or install the gh CLI and run 'gh auth login'."
    exit 0
}

# ── Resolve auth token ──────────────────────────────────────────────────────
$AuthToken = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN }
             elseif ($env:GH_TOKEN) { $env:GH_TOKEN }
             elseif (Get-Command gh -ErrorAction SilentlyContinue) {
                 try { gh auth token 2>$null } catch { $null }
             }
             else { $null }

# Try git's credential helper as a fallback
if (-not $AuthToken -and (Get-Command git -ErrorAction SilentlyContinue)) {
    try {
        $credOutput = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
        $passwordLine = $credOutput | Where-Object { $_ -match "^password=" }
        if ($passwordLine) {
            $AuthToken = ($passwordLine -replace "^password=", "")
        }
    }
    catch { }
}

# ── Create temp directory ────────────────────────────────────────────────────
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ralph-install-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

try {
    # ── Download zip archive ─────────────────────────────────────────────────
    # Use the API endpoint for authenticated requests (works with private repos),
    # fall back to the public archive URL for unauthenticated requests.
    if ($AuthToken) {
        $ArchiveUrl = "https://api.github.com/repos/$Repo/zipball/$Branch"
    }
    else {
        $ArchiveUrl = "https://github.com/$Repo/archive/$Branch.zip"
    }
    $ZipPath = Join-Path $TmpDir "ralph.zip"

    Write-Info "Downloading Ralph from ${Repo}@${Branch}..."

    try {
        # PowerShell 7+ and 5.1 compatible
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Headers = @{}
        if ($AuthToken) {
            $Headers["Authorization"] = "token $AuthToken"
        }
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ZipPath -UseBasicParsing -Headers $Headers
    }
    catch {
        if (-not $AuthToken) {
            Write-Err "Failed to download. If this is a private repo, set `$env:GITHUB_TOKEN or run 'gh auth login'."
        }
        else {
            Write-Err "Failed to download from $ArchiveUrl. Check the branch name and try again. Error: $_"
        }
    }

    # ── Extract ──────────────────────────────────────────────────────────────
    $ExtractDir = Join-Path $TmpDir "extracted"
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force

    # GitHub zips extract into a directory named {repo}-{branch}
    $Extracted = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
    if (-not $Extracted -or -not (Test-Path (Join-Path $Extracted.FullName ".github"))) {
        Write-Err "Unexpected archive structure. Could not find .github/ in extracted files."
    }
    $SourceRoot = $Extracted.FullName

    # ── Install .github/ directory ───────────────────────────────────────────
    Write-Info "Installing agent files into .github/..."

    # Create target directories
    $Dirs = @(
        ".github/agents",
        ".github/prompts"
    )
    foreach ($Dir in $Dirs) {
        if (-not (Test-Path $Dir)) {
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        }
    }

    # Copy .github/ contents, overwriting existing files
    $SourceGithub = Join-Path $SourceRoot ".github"

    # Agents
    Copy-Item -Path (Join-Path $SourceGithub "agents/*") -Destination ".github/agents/" -Recurse -Force
    Write-Ok "Installed .github/agents/ (3 agent files)"

    # Prompts
    Copy-Item -Path (Join-Path $SourceGithub "prompts/*") -Destination ".github/prompts/" -Recurse -Force
    Write-Ok "Installed .github/prompts/ (2 slash commands)"

    # ── Install AGENTS.md (conditionally) ────────────────────────────────────
    $AgentsStatus = "created"
    if ((Test-Path "AGENTS.md") -and -not $Force) {
        Write-Warn "AGENTS.md already exists — skipping to preserve your config"
        Write-Host "    Run with -Force to overwrite it with the latest template."
        $AgentsStatus = "skipped"
    }
    else {
        if ((Test-Path "AGENTS.md") -and $Force) {
            $AgentsStatus = "overwritten"
        }
        Copy-Item -Path (Join-Path $SourceRoot "AGENTS.md") -Destination "AGENTS.md" -Force
        Write-Ok "Installed AGENTS.md ($AgentsStatus)"
    }

    # ── Summary ──────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Ok "Ralph installed successfully!"
    Write-Host ""
    Write-Host "  Installed from: ${Repo}@${Branch}"
    Write-Host "  AGENTS.md:      $AgentsStatus"
    Write-Host ""

    if ($AgentsStatus -eq "created" -or $AgentsStatus -eq "overwritten") {
        Write-Info "Next step: Open AGENTS.md and replace the TODO markers with your project's values."
        Write-Host "    Or let the ralph-plan agent auto-detect them when you first run /plan."
    }

    Write-Host ""
    Write-Host "  Usage in VS Code Chat:"
    Write-Host "    • Select the 'prd' agent → describe a feature"
    Write-Host "    • Select 'ralph-plan' → decompose a PRD into tasks"
    Write-Host "    • Select 'ralph-loop' → execute the implementation loop"
    Write-Host "    • Or use /prd and /plan slash commands"
    Write-Host ""
}
finally {
    # ── Cleanup ──────────────────────────────────────────────────────────────
    if (Test-Path $TmpDir) {
        Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
