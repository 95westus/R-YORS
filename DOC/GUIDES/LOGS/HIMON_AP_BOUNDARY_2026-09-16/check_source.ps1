$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$src = Join-Path $root 'SRC'
. (Join-Path $src 'tools/read_himon_source.ps1')
$beforeSrc = Join-Path $PSScriptRoot 'source/SRC'
$before = Read-HimonSource -Path (Join-Path $beforeSrc 'HIMON/himon.asm') -SourceRoot $beforeSrc
$after = Read-HimonSource -Path (Join-Path $src 'HIMON/himon.asm') -SourceRoot $src
function Code-Lines([string]$text) {
    return (($text -split '\r?\n' | ForEach-Object { ($_ -split ';',2)[0].Trim() } | Where-Object { $_ }) -join "`n")
}
if ((Code-Lines $before) -cne (Code-Lines $after)) { throw 'Expanded instruction/declaration sequence differs' }
if ([regex]::Matches($after, '(?m)^HIM_AP_LINK_RESOLVE_SLOT_X:').Count -ne 1) { throw 'Resolver missing/duplicated in expanded source' }

# Confirm the added nested HIMON include participates in cycle detection.
$fixture = Join-Path $PSScriptRoot 'cycle-fixture'
[IO.Directory]::CreateDirectory((Join-Path $fixture 'HIMON')) | Out-Null
$file = Join-Path $fixture 'HIMON/himon-ap-resolver.inc'
[IO.File]::WriteAllText($file, ' INCLUDE "HIMON/himon-ap-resolver.inc"')
$rejected = $false
try { $null = Read-HimonSource -Path $file -SourceRoot $fixture }
catch { if ($_.Exception.Message -notmatch 'Cyclic HIMON/AP include') { throw }; $rejected = $true }
if (-not $rejected) { throw 'Cyclic resolver include accepted' }
[ordered]@{ result='PASS'; expanded_sequence_identical=$true; resolver_definitions=1; nested_resolver_cycle_rejected=$true } |
    ConvertTo-Json | Set-Content -Encoding ASCII (Join-Path $PSScriptRoot 'source-check.json')
Write-Output 'PASS expanded instruction/declaration identity; one resolver owner; cyclic resolver rejected'
