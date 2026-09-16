param(
    [string]$RepoRoot = "..",
    [string]$Str8nRoot = "../../STR8-N",
    [string]$OutDir = "../RELEASE",
    [string]$Stamp = (Get-Date -Format 'MMdd(HHmm)'),
    [string]$QualifiedBankPath = "",
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$str8n = (Resolve-Path -LiteralPath $Str8nRoot).Path
$out = [IO.Path]::GetFullPath($OutDir)
if ($out -ne (Join-Path $repo 'RELEASE')) { throw 'Output must be the repository RELEASE directory' }
$work = Join-Path $repo 'SRC/BUILD/tmp/asmf2-size-board'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$hostLog = Join-Path $work 'release-asm-test.log'
$imageLog = Join-Path $work 'release-images.log'
if ([string]::IsNullOrEmpty($QualifiedBankPath)) { $QualifiedBankPath = Join-Path $work 'final-b3.bin' }
if (-not $SkipBuild) {
    & python -B (Join-Path $repo 'SRC/tools/run_release_build.py') --phase host --stamp $Stamp --log $hostLog
    if ($LASTEXITCODE -ne 0) { throw "ASM regression failed; see $hostLog" }
    & python -B (Join-Path $repo 'SRC/tools/run_release_build.py') --phase images --stamp $Stamp --log $imageLog
    if ($LASTEXITCODE -ne 0) { throw "Image/application build failed; see $imageLog" }
}
& python -B (Join-Path $repo 'SRC/tools/package_component_releases.py') --stamp $Stamp --out $out --qualified-bank $QualifiedBankPath --host-log $hostLog --image-log $imageLog
if ($LASTEXITCODE -ne 0) { throw 'Component release verification failed' }
& python -B (Join-Path $repo 'SRC/tools/check_component_releases.py') $out
if ($LASTEXITCODE -ne 0) { throw 'Component archive negative checks failed' }
$str8zip = Join-Path $str8n 'BUILD/v1.34/str8n-v1.34-release.zip'
if (-not (Test-Path -LiteralPath $str8zip)) { throw 'Build and verify the standalone STR8-N v1.34 package first' }
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $str8n 'tools/verify_release_package.ps1') -Root (Join-Path $str8n 'BUILD/v1.34/str8n-v1.34-release') -ZipPath $str8zip
if ($LASTEXITCODE -ne 0) { throw 'Standalone STR8 package verification failed' }
Copy-Item -LiteralPath $str8zip -Destination (Join-Path $out 'str8n-v1.34-release.zip') -Force
& python -B (Join-Path $repo 'SRC/tools/write_release_index.py')
if ($LASTEXITCODE -ne 0) { throw 'Release index verification failed' }
Write-Host "Release ZIPs and qualified 8-E S19 written to $out"
