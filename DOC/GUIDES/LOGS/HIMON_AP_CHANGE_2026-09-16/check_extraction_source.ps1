$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'SRC/tools/read_himon_source.ps1')
$expanded = Read-HimonSource -Path (Join-Path $root 'SRC/HIMON/himon.asm')
$before = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'functional-source/SRC/HIMON/himon.asm'))
function Nonblank([string]$Text) { return (($Text -split '\r?\n' | Where-Object { $_.Trim() }) -join "`n") }
if ((Nonblank $expanded) -cne (Nonblank $before)) { throw 'Expanded source changed beyond blank include separators' }
'PASS expanded HIMON/AP source equals frozen functional source'
$fixture = Join-Path $PSScriptRoot 'checker-negative'
New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'HIMON'), (Join-Path $fixture 'AP') | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'SRC/HIMON/himon.asm') -Destination (Join-Path $fixture 'HIMON/himon.asm')
Copy-Item -LiteralPath (Join-Path $root 'SRC/HIMON/himon-ap-adapter.inc') -Destination (Join-Path $fixture 'HIMON/himon-ap-adapter.inc')
Get-ChildItem -LiteralPath (Join-Path $root 'SRC/AP') -Filter '*.inc' | Copy-Item -Destination (Join-Path $fixture 'AP')
$contract = Join-Path $fixture 'AP/ap-contract.inc'
$original = [IO.File]::ReadAllText($contract)
[IO.File]::WriteAllText($contract, $original.Replace('HIM_AP_TOOL_LIMIT_HI', 'MUTATED_TOOL_LIMIT_HI'))
Push-Location (Join-Path $root 'SRC')
try {
    $caught = $false
    try { & ./tools/check_himon_banked_ap.ps1 -HimonSourcePath (Join-Path $fixture 'HIMON/himon.asm') }
    catch { if ($_ -notmatch 'source is missing HIM_AP_TOOL_LIMIT_HI') { throw }; $caught = $true }
    if (-not $caught) { throw 'Moved-source mutation escaped checker' }
    'PASS moved AP declaration mutation is rejected by existing checker'
} finally { Pop-Location }
[IO.File]::WriteAllText($contract, '                        INCLUDE         "AP/ap-contract.inc"')
$caught = $false
try { Read-HimonSource -Path (Join-Path $fixture 'HIMON/himon.asm') | Out-Null }
catch { if ($_ -notmatch 'Cyclic HIMON/AP include') { throw }; $caught = $true }
if (-not $caught) { throw 'Cyclic include accepted' }
'PASS cyclic AP include is rejected'
