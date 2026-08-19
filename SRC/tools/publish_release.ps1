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

$published = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)

function Publish-File {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [string]$Name = ""
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Release input not found: $Source"
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Split-Path -Leaf $Source
    }
    if ($published.ContainsKey($Name)) {
        throw "Duplicate flat release filename '$Name' from '$Source' and '$($published[$Name])'"
    }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $out $Name) -Force
    $published.Add($Name, $Source)
}

$rArtifacts = @(
    "SRC/BUILD/bin/himon-rom-c000.bin",
    "SRC/BUILD/bin/life-2000-load.bin",
    "SRC/BUILD/s19/asm-v1-flash-8000.s19",
    "SRC/BUILD/s19/fnv1a-hbstr-6000.s19",
    "SRC/BUILD/s19/himon-apv2-bank3-c-e.s19",
    "SRC/BUILD/s19/himon-c000.s19",
    "SRC/BUILD/s19/himon-rom-c000-install-8000.s19",
    "SRC/BUILD/s19/himon-rom-c000.s19",
    "SRC/BUILD/s19/life-2000.s19",
    "SRC/BUILD/s19/rom-append-calc-b804.s19",
    "SRC/BUILD/s19/ryors-v1.2-asm-bank3-8-b.s19",
    "SRC/BUILD/s19/ryors-v1.2-himon-asm-bank3-8-e.s19",
    "SRC/BUILD/s19/ryors-v1.2-himon-bank3-c-e.s19"
)
foreach ($relative in $rArtifacts) {
    Publish-File -Source (Join-Path $repo $relative)
}

$str8Artifacts = @(
    "BUILD/str8n-manifest.json",
    "BUILD/v1.21/bin/str8n-v1.21-bank3-f000-ffff.bin",
    "BUILD/v1.21/s19/str8n-v1.21-f000.s19",
    "BUILD/v1.21/s19/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19"
)
foreach ($relative in $str8Artifacts) {
    Publish-File -Source (Join-Path $str8n $relative)
}

$sourceRoots = @(
    (Join-Path $repo "SRC/ASM"),
    (Join-Path $repo "SRC/HIMON"),
    (Join-Path $repo "SRC/APPS")
)
foreach ($sourceRoot in $sourceRoots) {
    Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter *.asm |
        Sort-Object FullName |
        ForEach-Object { Publish-File -Source $_.FullName }
}

$str8Sources = @(
    "src/str8.asm",
    "src/str8-worker.asm",
    "src/util-delay.asm",
    "tools/bank-maint/str8n-v1.21-bank-maint-2000.asm",
    "tools/bank-maint/str8n-v1.21-bank-maint-menu-2000.asm",
    "tools/bank-maint/str8n-v1.21-bank-maint-menu-2000.a",
    "tools/top-update/str8n-v1.21-top-update-2000.asm"
)
foreach ($relative in $str8Sources) {
    Publish-File -Source (Join-Path $str8n $relative)
}

Get-ChildItem -LiteralPath (Join-Path $repo "DOC/GUIDES/ASM/SAMPLES") -File -Filter *.a |
    Sort-Object Name |
    ForEach-Object { Publish-File -Source $_.FullName }

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

This flat directory is the operator-facing release location. Product names
follow top-down memory order: STR8-N (`$F000), HIMON (`$C000), then ASM-F2
(`$8000).

Primary complete product:

- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
- ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin

Bank-3 payload without the protected STR8-N top sector:

- ryors-v1.2-himon-asm-bank3-8-e.s19

The `.asm` and `.a` files are source snapshots for inspection and onboard use.
The canonical build source remains under `SRC/` and the adjacent `STR8-N`
repository. `SHA256SUMS.txt` identifies every published file.
'@
Set-Content -LiteralPath (Join-Path $out "README.md") -Value $readme -Encoding utf8

$hashLines = Get-ChildItem -LiteralPath $out -File |
    Where-Object { $_.Name -ne "SHA256SUMS.txt" } |
    Sort-Object Name |
    ForEach-Object { "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name }
Set-Content -LiteralPath (Join-Path $out "SHA256SUMS.txt") -Value $hashLines -Encoding ascii

$counts = Get-ChildItem -LiteralPath $out -File | Group-Object Extension | Sort-Object Name
Write-Host "RELEASE = $out"
foreach ($count in $counts) {
    Write-Host ("  {0,-8} {1,3}" -f $(if ($count.Name) { $count.Name } else { "[none]" }), $count.Count)
}
Write-Host "Primary S19 SHA-256 = $((Get-FileHash -LiteralPath $fullS19 -Algorithm SHA256).Hash)"
Write-Host "Primary BIN SHA-256 = $((Get-FileHash -LiteralPath $fullBin -Algorithm SHA256).Hash)"
