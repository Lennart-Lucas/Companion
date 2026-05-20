$ErrorActionPreference = "Stop"

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    throw "Not inside a git repository."
}

Set-Location $repoRoot
git config core.hooksPath backend/.githooks
Write-Host "Git hooks installed (core.hooksPath=backend/.githooks)"
