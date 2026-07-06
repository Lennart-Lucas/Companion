param(
    [string]$ServerIp,
    [string]$SshUser = "root",
    [string]$RemotePath = "~/Companion/backend",
    [string]$Branch = "main",
    [string]$IdentityFile
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not $ServerIp) {
    $ServerIp = Read-Host "Remote server IP or hostname"
}
if ([string]::IsNullOrWhiteSpace($ServerIp)) {
    throw "Server IP or hostname is required."
}

$sshUserInput = Read-Host "SSH user [$SshUser]"
if (-not [string]::IsNullOrWhiteSpace($sshUserInput)) {
    $SshUser = $sshUserInput
}

$remotePathInput = Read-Host "Remote backend path [$RemotePath]"
if (-not [string]::IsNullOrWhiteSpace($remotePathInput)) {
    $RemotePath = $remotePathInput
}

$branchInput = Read-Host "Git branch to deploy [$Branch]"
if (-not [string]::IsNullOrWhiteSpace($branchInput)) {
    $Branch = $branchInput
}

if (-not $IdentityFile) {
    $identityInput = Read-Host "SSH private key path (optional, Enter to use default agent keys)"
    if (-not [string]::IsNullOrWhiteSpace($identityInput)) {
        $IdentityFile = $identityInput.Trim('"')
    }
}
if ($IdentityFile -and -not (Test-Path $IdentityFile)) {
    throw "SSH private key not found: $IdentityFile"
}

$target = "${SshUser}@${ServerIp}"
$remoteScript = Join-Path $PSScriptRoot "deploy-remote.sh"

if (-not (Test-Path $remoteScript)) {
    throw "Missing remote deploy script: $remoteScript"
}

$sshArgs = @()
if ($IdentityFile) {
    $sshArgs += @("-i", (Resolve-Path $IdentityFile).Path)
}
$sshArgs += $target, "bash -s -- '$RemotePath' '$Branch'"

Write-Host ""
Write-Host "Deploying Companion backend"
Write-Host "  Target : $target"
Write-Host "  Path   : $RemotePath"
Write-Host "  Branch : $Branch"
if ($IdentityFile) {
    Write-Host "  SSH key: $IdentityFile"
}
Write-Host ""

Get-Content -Raw $remoteScript | ssh @sshArgs

if ($LASTEXITCODE -ne 0) {
    if ($LASTEXITCODE -eq 255) {
        throw @"
SSH connection failed (exit code 255). Common fixes:
  - Use the correct SSH user (e.g. root, ubuntu, or your VPS login — not always root)
  - Add your public key to the server: ssh-copy-id user@$ServerIp
  - Or pass your key: .\deploy.ps1 -ServerIp $ServerIp -IdentityFile `$env:USERPROFILE\.ssh\id_ed25519
  - Test manually first: ssh $target
"@
    }
    throw "Remote deploy failed (exit code $LASTEXITCODE)."
}

Write-Host ""
Write-Host "Remote deploy finished successfully."
