param(
    [Parameter(Position = 0)]
    [ValidateSet("up", "down", "logs", "migrate")]
    [string]$Command = "up"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$composeArgs = @("compose", "-p", "companion-prod", "-f", "docker-compose.prod.yml")

switch ($Command) {
    "up" {
        docker @composeArgs up --build -d
    }
    "down" {
        docker @composeArgs down
    }
    "logs" {
        docker @composeArgs logs -f api
    }
    "migrate" {
        docker @composeArgs exec api alembic upgrade head
    }
}
