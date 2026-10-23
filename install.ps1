# Download a release binary without Go, a source checkout, or administrator rights.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'gitso: use install.sh on macOS/Linux' }
if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'gitso: install Git and add it to PATH first'
}
& git --version
if ($LASTEXITCODE -ne 0) { throw 'gitso: git is not working' }

# Also works in Windows PowerShell 5.1, including under x64 emulation on ARM64.
$NativeArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($NativeArch) {
    'AMD64' { $Arch = 'amd64' }
    'ARM64' { $Arch = 'arm64' }
    default { throw "gitso: unsupported architecture: $NativeArch" }
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$Repo = 'https://github.com/d3Lap1ace/gitso'
$Version = if ($env:GITSO_VERSION) { $env:GITSO_VERSION } else { 'latest' }
if ($Version -eq 'latest') {
    $Release = Invoke-RestMethod -Uri 'https://api.github.com/repos/d3Lap1ace/gitso/releases/latest' -TimeoutSec 120
    $Version = $Release.tag_name
}
if ($Version -cnotmatch '^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$') {
    throw 'gitso: cannot resolve a valid release; set GITSO_VERSION=vX.Y.Z'
}
$InstallDir = if ($env:GITSO_INSTALL_DIR) { $env:GITSO_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\gitso' }
if (-not [IO.Path]::IsPathRooted($InstallDir)) { throw 'gitso: GITSO_INSTALL_DIR must be absolute' }
$Asset = "gitso_windows_$Arch.exe"
$BaseUrl = "$Repo/releases/download/$Version"
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ("gitso-" + [guid]::NewGuid())
$Stage = $null
try {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    $Binary = Join-Path $TempDir $Asset
    $Checksums = Join-Path $TempDir 'checksums.txt'
    Write-Host "Downloading gitso $Version for windows/$Arch..."
    Invoke-WebRequest -UseBasicParsing "$BaseUrl/checksums.txt" -OutFile $Checksums -TimeoutSec 120
    Invoke-WebRequest -UseBasicParsing "$BaseUrl/$Asset" -OutFile $Binary -TimeoutSec 120
    $Lines = @(Get-Content $Checksums | Where-Object { $_ -match "^[a-fA-F0-9]{64}\s+$([regex]::Escape($Asset))$" })
    if ($Lines.Count -ne 1) { throw 'gitso: missing or ambiguous checksum' }
    $Expected = ($Lines[0] -split '\s+')[0]
    if ((Get-FileHash -Algorithm SHA256 $Binary).Hash -ne $Expected) { throw 'gitso: checksum verification failed' }
    & $Binary --version
    if ($LASTEXITCODE -ne 0) { throw 'gitso: downloaded binary could not run with the system git' }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $Target = Join-Path $InstallDir 'gitso.exe'
    if (Test-Path $Target -PathType Container) { throw "gitso: $Target is a directory" }
    $Stage = Join-Path $InstallDir ('.gitso-' + [guid]::NewGuid() + '.exe')
    Copy-Item -LiteralPath $Binary -Destination $Stage
    if (Test-Path -LiteralPath $Target) {
        [IO.File]::Replace($Stage, $Target, [NullString]::Value)
    } else {
        [IO.File]::Move($Stage, $Target)
    }
    $Stage = $null
    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $Entries = @($UserPath -split ';' | Where-Object { $_ })
    if ($Entries -notcontains $InstallDir) {
        [Environment]::SetEnvironmentVariable('Path', ((@($Entries) + $InstallDir) -join ';'), 'User')
    }
    if (($env:Path -split ';') -notcontains $InstallDir) { $env:Path = "$InstallDir;$env:Path" }
    Write-Host "Installed gitso ${Version}: $Target"
    Write-Host 'User PATH is configured. Open a new terminal for other sessions.'
} finally {
    if ($Stage -and (Test-Path -LiteralPath $Stage)) { Remove-Item -LiteralPath $Stage -Force }
    if (Test-Path -LiteralPath $TempDir) { Remove-Item -LiteralPath $TempDir -Recurse -Force }
}
