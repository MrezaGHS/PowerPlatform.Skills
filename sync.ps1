# =============================================================================
# Power Platform Playbook Sync Script
# =============================================================================
# One-command sync for this docs repo. Pulls remote changes, stages what you
# choose, shows exactly what will go in, asks for confirmation, then commits
# and pushes.
#
# Usage:
#   .\sync.ps1 "Your message"                    # stage everything, confirm first
#   .\sync.ps1 "Your message" 06_POWERFX_RULES.md  # stage only these paths
#   .\sync.ps1 "Your message" -Yes               # skip the confirmation prompt
# =============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Commit message describing what changed")]
    [string]$CommitMessage,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true, HelpMessage = "Optional paths to stage. Omit to stage all changes.")]
    [string[]]$Paths,

    [switch]$Yes
)

$ErrorActionPreference = "Stop"

# Run from the folder this script lives in
Set-Location $PSScriptRoot

# Step 1: Pull any remote changes first (handles edits made directly on GitHub)
Write-Host ""
Write-Host "==> Pulling latest changes from GitHub..." -ForegroundColor Cyan
git pull --rebase --autostash
if ($LASTEXITCODE -ne 0) {
    throw "git pull --rebase failed. Resolve the conflict manually, then re-run."
}

# Step 2: Stage the changes you chose (all, or just the named paths)
Write-Host ""
if ($Paths -and $Paths.Count -gt 0) {
    Write-Host "==> Staging only: $($Paths -join ', ')" -ForegroundColor Cyan
    git add -- $Paths
} else {
    Write-Host "==> Staging all changes (gitignore still applies)..." -ForegroundColor Cyan
    git add -A
}

# Step 3: Show exactly what is staged and bail if nothing is
$staged = git diff --cached --name-status
if ([string]::IsNullOrWhiteSpace(($staged | Out-String))) {
    Write-Host ""
    Write-Host "==> Nothing staged to commit. Done." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "These changes will be committed:" -ForegroundColor Yellow
git diff --cached --stat

# Step 4: Confirm before committing (unless -Yes was passed)
if (-not $Yes) {
    Write-Host ""
    $answer = Read-Host "Commit and push these? (y/n)"
    if ($answer -notmatch '^(y|yes)$') {
        git reset --quiet
        Write-Host "==> Cancelled. Nothing committed. Your files are untouched (just unstaged)." -ForegroundColor Yellow
        exit 0
    }
}

# Step 5: Commit
Write-Host ""
Write-Host "==> Committing..." -ForegroundColor Cyan
git commit -m $CommitMessage
if ($LASTEXITCODE -ne 0) { throw "git commit failed." }

# Step 6: Push
Write-Host ""
Write-Host "==> Pushing to GitHub..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) { throw "git push failed. Run 'git pull --rebase' and try again." }

Write-Host ""
Write-Host "==> Done. Synced and pushed to GitHub." -ForegroundColor Green
