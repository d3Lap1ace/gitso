param([Parameter(Mandatory = $true)][string]$Fixture)
$ErrorActionPreference = 'Stop'
$Root = Join-Path ([IO.Path]::GetTempPath()) ('gitso-test-' + [guid]::NewGuid())
$SavedUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$SavedPath = $env:Path
$SavedDir = $env:GITSO_INSTALL_DIR
$SavedVersion = $env:GITSO_VERSION
$script:BadChecksum = $false
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec)
    if ($Uri -like '*/checksums.txt') {
        $Hash = (Get-FileHash -Algorithm SHA256 $Fixture).Hash.ToLowerInvariant()
        if ($script:BadChecksum) { $Hash = '0' * 64 }
        @("$Hash  gitso_windows_amd64.exe", "$Hash  gitso_windows_arm64.exe") | Set-Content -Encoding ASCII -LiteralPath $OutFile
    } else { Copy-Item -LiteralPath $Fixture -Destination $OutFile }
}
try {
    $env:GITSO_INSTALL_DIR = Join-Path $Root 'path with spaces'
    $env:GITSO_VERSION = 'v1.2.3'
    $Installer = Join-Path $PSScriptRoot '..\install.ps1'
    & $Installer
    $Target = Join-Path $env:GITSO_INSTALL_DIR 'gitso.exe'
    if ((Get-FileHash $Target).Hash -ne (Get-FileHash $Fixture).Hash) { throw 'installed bytes differ' }
    & $Installer
    $Entries = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
    if (@($Entries | Where-Object { $_ -eq $env:GITSO_INSTALL_DIR }).Count -ne 1) { throw 'duplicate PATH entries' }
    $script:BadChecksum = $true
    $Rejected = $false
    try { & $Installer } catch { $Rejected = $true }
    if (-not $Rejected) { throw 'bad checksum accepted' }
    if ((Get-FileHash $Target).Hash -ne (Get-FileHash $Fixture).Hash) { throw 'failure modified existing install' }
    Write-Host 'Windows install, repeat install, PATH and checksum failure tests passed.'
} finally {
    [Environment]::SetEnvironmentVariable('Path', $SavedUserPath, 'User')
    $env:Path = $SavedPath
    $env:GITSO_INSTALL_DIR = $SavedDir
    $env:GITSO_VERSION = $SavedVersion
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
}
