$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$python = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "python3" }
& $python scripts/squash_migrations.py
exit $LASTEXITCODE
