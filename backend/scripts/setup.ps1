$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path ".env.dev")) {
    Copy-Item ".env.dev.example" ".env.dev"
    Write-Host "Created .env.dev from .env.dev.example"
}

if (-not (Test-Path ".env.prod")) {
    Copy-Item ".env.prod.example" ".env.prod"
    Write-Host "Created .env.prod from .env.prod.example"
}

Write-Host "Setup complete."
