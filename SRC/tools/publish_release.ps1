param(
    [string]$RepoRoot = "..",
    [string]$Str8nRoot = "../../STR8-N",
    [string]$OutDir = "../RELEASE"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$str8n = (Resolve-Path -LiteralPath $Str8nRoot).Path
$expectedOut = [IO.Path]::GetFullPath((Join-Path $repo "RELEASE"))
$out = [IO.Path]::GetFullPath($OutDir)
if (-not [StringComparer]::OrdinalIgnoreCase.Equals($out, $expectedOut)) {
    throw "Release output must be the repository RELEASE directory: $expectedOut"
}

New-Item -ItemType Directory -Force -Path $out | Out-Null
Get-ChildItem -LiteralPath $out -File | Remove-Item -Force
$artifactRoot = Join-Path $out "ARTIFACTS"
if (Test-Path -LiteralPath $artifactRoot) {
    $resolvedArtifactRoot = [IO.Path]::GetFullPath($artifactRoot)
    if (-not $resolvedArtifactRoot.StartsWith($expectedOut + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Artifact cleanup escaped RELEASE: $resolvedArtifactRoot"
    }
    Remove-Item -LiteralPath $resolvedArtifactRoot -Recurse -Force
}

$published = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
$forbiddenImagePattern = '(?i)wdcmonv2.*\.(bin|s19)$'

function Assert-PublishableImageName {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Role
    )

    $leaf = Split-Path -Leaf $Path
    if ($leaf -match $forbiddenImagePattern) {
        throw "WDCMONv2 BIN/S19 files are local-only and must not be published ($Role): $Path"
    }
}

function Publish-File {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [string]$Name = "",
        [string]$RelativeDir = ""
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Release input not found: $Source"
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Split-Path -Leaf $Source
    }
    Assert-PublishableImageName -Path $Source -Role "source"
    Assert-PublishableImageName -Path $Name -Role "release name"
    $relativePath = if ([string]::IsNullOrWhiteSpace($RelativeDir)) { $Name } else { Join-Path $RelativeDir $Name }
    if ($published.ContainsKey($relativePath)) {
        throw "Duplicate release path '$relativePath' from '$Source' and '$($published[$relativePath])'"
    }
    $destination = Join-Path $out $relativePath
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Copy-Item -LiteralPath $Source -Destination $destination -Force
    $published.Add($relativePath, $Source)
}

$apStoreArtifacts = @(
    "SRC/BUILD/bin/ap-store-v1-chain-install-tool-7000.ap.bin",
    "SRC/BUILD/bin/ap-store-v1-chain-reader-tool-7000.ap.bin",
    "SRC/BUILD/bin/ap-store-v1-object-tool-7000.ap.bin",
    "SRC/BUILD/bin/ap-store-v1-sector-tool-7000.ap.bin",
    "SRC/BUILD/bin/ap-store-v1-slice6-catalog-tool-7000.ap.bin",
    "SRC/BUILD/bin/ap-store-v1-slice6-delete-tool-7000.ap.bin",
    "SRC/BUILD/bin/ap-store-v1-slice6-plan-tool-7000.ap.bin",
    "SRC/BUILD/bin/himon-rom-c000.bin",
    "SRC/BUILD/bin/life-2000-load.bin",
    "SRC/BUILD/s19/asm-v1-flash-8000.s19",
    "SRC/BUILD/s19/ap-store-v1-chain-install-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-chain-install-tool-package-4000.s19",
    "SRC/BUILD/s19/ap-store-v1-chain-reader-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-chain-reader-tool-package-4000.s19",
    "SRC/BUILD/s19/ap-store-v1-object-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-object-tool-package-3000.s19",
    "SRC/BUILD/s19/ap-store-v1-sector-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-slice6-catalog-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-slice6-catalog-tool-package-4000.s19",
    "SRC/BUILD/s19/ap-store-v1-slice6-delete-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-slice6-delete-tool-package-4000.s19",
    "SRC/BUILD/s19/ap-store-v1-slice6-plan-tool-7000.s19",
    "SRC/BUILD/s19/ap-store-v1-slice6-plan-tool-package-4000.s19"
)
foreach ($relative in $apStoreArtifacts) {
    Publish-File -Source (Join-Path $repo $relative) -RelativeDir "ARTIFACTS/AP-STORE"
}
Publish-File -Source (Join-Path $repo "SRC/PROOFS/ap-store-v1-sector-tool.asm") -RelativeDir "ARTIFACTS/AP-STORE"
Publish-File -Source (Join-Path $repo "DOC/GUIDES/ASM/SAMPLES/ap-store-v1-sector-tool-7000.a") -RelativeDir "ARTIFACTS/AP-STORE"

$rComponentArtifacts = @(
    "SRC/BUILD/s19/fnv1a-hbstr-6000.s19",
    "SRC/BUILD/s19/himon-apv2-bank3-c-e.s19",
    "SRC/BUILD/s19/himon-c000.s19",
    "SRC/BUILD/s19/himon-rom-c000-install-8000.s19",
    "SRC/BUILD/s19/himon-rom-c000.s19",
    "SRC/BUILD/s19/life-2000.s19",
    "SRC/BUILD/s19/pia-led-show-2000.s19",
    "SRC/BUILD/s19/rom-append-calc-b804.s19",
    "SRC/BUILD/s19/ryors-v1.2-asm-bank3-8-b.s19",
    "SRC/BUILD/s19/ryors-v1.2-himon-bank3-c-e.s19"
)
foreach ($relative in $rComponentArtifacts) {
    Publish-File -Source (Join-Path $repo $relative) -RelativeDir "ARTIFACTS/COMPONENT-IMAGES"
}
Publish-File -Source (Join-Path $repo "SRC/BUILD/s19/ryors-v1.2-himon-asm-bank3-8-e.s19")

$str8ComponentArtifacts = @(
    "BUILD/str8n-manifest.json",
    "BUILD/v1.22/bin/str8n-v1.22-bank3-f000-ffff.bin",
    "BUILD/v1.22/s19/str8n-v1.22-bank-maint-2000.s19",
    "BUILD/v1.22/s19/str8n-v1.22-bank-maint-menu-2000.s19",
    "BUILD/v1.22/s19/str8n-v1.22-console-abi-test-2000.s19",
    "BUILD/v1.22/s19/str8n-v1.22-directory-refresh-2000.s19",
    "BUILD/v1.22/s19/str8n-v1.22-f000.s19",
    "BUILD/v1.22/s19/str8n-v1.22-worker-0200.s19"
)
foreach ($relative in $str8ComponentArtifacts) {
    Publish-File -Source (Join-Path $str8n $relative) -RelativeDir "ARTIFACTS/COMPONENT-IMAGES"
}
Publish-File -Source (Join-Path $str8n "BUILD/v1.22/s19/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19")
Publish-File -Source (Join-Path $str8n "BUILD/v1.22/s19/str8n-v1.22-top-update-2000.s19")

$sourceRoots = @(
    (Join-Path $repo "SRC/ASM"),
    (Join-Path $repo "SRC/HIMON"),
    (Join-Path $repo "SRC/APPS")
)
foreach ($sourceRoot in $sourceRoots) {
    Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter *.asm |
        Sort-Object FullName |
        ForEach-Object { Publish-File -Source $_.FullName -RelativeDir "ARTIFACTS/SOURCES" }
}

$str8Sources = @(
    "src/str8.asm",
    "src/str8-worker.asm",
    "src/util-delay.asm",
    "tools/bank-maint/str8n-v1.22-bank-maint-2000.asm",
    "tools/bank-maint/str8n-v1.22-bank-maint-menu-2000.asm",
    "tools/bank-maint/str8n-v1.22-bank-maint-menu-2000.a",
    "tools/top-update/str8n-v1.22-top-update-2000.asm"
)
foreach ($relative in $str8Sources) {
    Publish-File -Source (Join-Path $str8n $relative) -RelativeDir "ARTIFACTS/SOURCES"
}

Get-ChildItem -LiteralPath (Join-Path $repo "DOC/GUIDES/ASM/SAMPLES") -File -Filter *.a |
    Where-Object { $_.Name -ne "ap-store-v1-sector-tool-7000.a" } |
    Sort-Object Name |
    ForEach-Object { Publish-File -Source $_.FullName -RelativeDir "ARTIFACTS/SOURCES" }

function Convert-S19ToFullBankBin {
    param(
        [Parameter(Mandatory = $true)][string]$S19Path,
        [Parameter(Mandatory = $true)][string]$BinPath
    )

    [byte[]]$image = New-Object byte[] 0x8000
    [bool[]]$seen = New-Object bool[] 0x8000
    foreach ($raw in [IO.File]::ReadLines($S19Path)) {
        $line = $raw.Trim()
        if (-not $line.StartsWith("S1")) { continue }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        $address = [Convert]::ToInt32($line.Substring(4, 4), 16)
        $dataCount = $count - 3
        for ($i = 0; $i -lt $dataCount; $i++) {
            $absolute = $address + $i
            if ($absolute -lt 0x8000 -or $absolute -gt 0xFFFF) {
                throw ('Full-bank S19 address ${0:X4} is outside $8000-$FFFF' -f $absolute)
            }
            $offset = $absolute - 0x8000
            if ($seen[$offset]) { throw ('Duplicate full-bank byte at ${0:X4}' -f $absolute) }
            $image[$offset] = [Convert]::ToByte($line.Substring(8 + 2 * $i, 2), 16)
            $seen[$offset] = $true
        }
    }
    $missing = @($seen | Where-Object { -not $_ })
    if ($missing.Count -ne 0) {
        throw "Full-bank S19 does not cover every byte from `$8000 through `$FFFF"
    }
    [IO.File]::WriteAllBytes($BinPath, $image)
}

$fullS19 = Join-Path $out "ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19"
$fullBinName = "ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin"
$fullBin = Join-Path $out $fullBinName
Convert-S19ToFullBankBin -S19Path $fullS19 -BinPath $fullBin
$published.Add($fullBinName, $fullS19)

$readme = @'
# Current R-YORS Release Files

The root of this directory contains only board-facing update products.
Supporting images, transient tools, and source carriers are under
`ARTIFACTS/` so they cannot be mistaken for the normal board update.

Complete 32K Bank-0/1/2 product:

- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin

Bank-3 sectors 8-E update, without protected sector F:

- ryors-v1.2-himon-asm-bank3-8-e.s19

Guarded Bank-3 sector-F update, retaining a verified B1:F backup:

- str8n-v1.22-top-update-2000.s19

Moved-aside material:

- ARTIFACTS/AP-STORE - AP Store transit tools and exact `.a`/`.asm` carriers
- ARTIFACTS/COMPONENT-IMAGES - component, diagnostic, and recovery images
- ARTIFACTS/SOURCES - source snapshots and onboard sample sources

The canonical source remains under `SRC/` and the adjacent `STR8-N`
repository. `SHA256SUMS.txt` covers every file recursively.
'@
Set-Content -LiteralPath (Join-Path $out "README.md") -Value $readme -Encoding utf8

Get-ChildItem -LiteralPath $out -Recurse -File | ForEach-Object {
    Assert-PublishableImageName -Path $_.Name -Role "release output"
}

$hashLines = Get-ChildItem -LiteralPath $out -Recurse -File |
    Where-Object { $_.Name -ne "SHA256SUMS.txt" } |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($out.Length).TrimStart('\', '/').Replace('\', '/')
        "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $relative
    }
Set-Content -LiteralPath (Join-Path $out "SHA256SUMS.txt") -Value $hashLines -Encoding ascii

$rootFiles = Get-ChildItem -LiteralPath $out -File | Sort-Object Name
$artifactFiles = Get-ChildItem -LiteralPath $artifactRoot -Recurse -File
Write-Host "RELEASE = $out"
Write-Host ("  ROOT FILES = {0}" -f $rootFiles.Count)
Write-Host ("  MOVED ASIDE = {0}" -f $artifactFiles.Count)
Write-Host "Primary S19 SHA-256 = $((Get-FileHash -LiteralPath $fullS19 -Algorithm SHA256).Hash)"
Write-Host "Primary BIN SHA-256 = $((Get-FileHash -LiteralPath $fullBin -Algorithm SHA256).Hash)"
