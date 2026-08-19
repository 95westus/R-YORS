param(
    [string]$S19Dir = "BUILD/s19",
    [string]$Str8FullBankPath = "../../STR8-N/BUILD/v1.21/s19/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Fail([string]$Message) { throw "board S19 identity: $Message" }

function Read-S19([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "missing $Path" }
    $memory = [Collections.Generic.Dictionary[int, byte]]::new()
    $start = -1
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        $line = $raw.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line.Length -lt 4 -or $line[0] -ne 'S') { Fail "malformed line in $Path" }
        $type = $line[1]
        $addressBytes = switch ($type) {
            '1' { 2 } '2' { 3 } '3' { 4 }
            '7' { 4 } '8' { 3 } '9' { 2 }
            default { 0 }
        }
        if ($addressBytes -eq 0) { continue }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        if ($line.Length -ne (4 + 2 * $count)) { Fail "length failure in ${Path}: $line" }
        $sum = $count
        for ($i = 0; $i -lt $count; $i++) {
            $sum += [Convert]::ToInt32($line.Substring(4 + 2 * $i, 2), 16)
        }
        if (($sum -band 0xFF) -ne 0xFF) { Fail "checksum failure in ${Path}: $line" }
        $address = [Convert]::ToInt32($line.Substring(4, 2 * $addressBytes), 16)
        if ($type -in @('7', '8', '9')) {
            if ($start -ge 0) { Fail "duplicate termination record in $Path" }
            $start = $address
            continue
        }
        $dataBytes = $count - $addressBytes - 1
        for ($i = 0; $i -lt $dataBytes; $i++) {
            $target = $address + $i
            if ($memory.ContainsKey($target)) { Fail ('duplicate ${0:X4} in {1}' -f $target, $Path) }
            $memory.Add($target, [Convert]::ToByte($line.Substring(4 + 2 * $addressBytes + 2 * $i, 2), 16))
        }
    }
    if ($memory.Count -eq 0 -or $start -lt 0) { Fail "incomplete $Path" }
    [pscustomobject]@{ Path = $Path; Memory = $memory; Start = $start }
}

function Assert-Canonical([object]$Canonical, [object]$Target, [string]$Role) {
    foreach ($row in $Canonical.Memory.GetEnumerator()) {
        if (-not $Target.Memory.ContainsKey($row.Key)) {
            Fail ('{0} missing ${1:X4}' -f $Role, $row.Key)
        }
        if ($Target.Memory[$row.Key] -ne $row.Value) {
            Fail ('{0} differs at ${1:X4}' -f $Role, $row.Key)
        }
    }
}

$asm = Read-S19 (Join-Path $S19Dir 'asm-v1-flash-8000.s19')
$himon = Read-S19 (Join-Path $S19Dir 'himon-rom-c000.s19')
if ($asm.Memory.Count -ne 0x3AFE) { Fail ('canonical ASM byte count is ${0:X4}, expected $3AFE' -f $asm.Memory.Count) }
if ($himon.Memory.Count -ne 0x2DB4) { Fail ('canonical HIMON byte count is ${0:X4}, expected $2DB4' -f $himon.Memory.Count) }

$himonTargets = @(
    'himon-c000.s19',
    'himon-rom-c000-install-8000.s19',
    'himon-apv2-bank3-c-e.s19',
    'ryors-v1.2-himon-bank3-c-e.s19',
    'ryors-v1.2-himon-asm-bank3-8-e.s19'
) | ForEach-Object { Read-S19 (Join-Path $S19Dir $_) }
$full = Read-S19 $Str8FullBankPath
$himonTargets += $full
foreach ($target in $himonTargets) { Assert-Canonical $himon $target ('HIMON ' + $target.Path) }

$asmTargets = @(
    'ryors-v1.2-asm-bank3-8-b.s19',
    'ryors-v1.2-himon-asm-bank3-8-e.s19'
) | ForEach-Object { Read-S19 (Join-Path $S19Dir $_) }
$asmTargets += $full
foreach ($target in $asmTargets) { Assert-Canonical $asm $target ('ASM ' + $target.Path) }

$dense = Read-S19 (Join-Path $S19Dir 'ryors-v1.2-himon-asm-bank3-8-e.s19')
if ($dense.Memory.Count -ne 0x7000 -or $dense.Start -ne 0xC000) {
    Fail 'dense Bank-3 stream is not $8000-$EFFF with S9 $C000'
}
if ($full.Memory.Count -ne 0x8000 -or $full.Start -ne 0xF000) {
    Fail 'combined bank stream is not $8000-$FFFF with S9 $F000'
}

Write-Host ('BOARD S19 IDENTITY = PASS; ASM=${0:X4} HIMON=${1:X4} targets={2}' -f $asm.Memory.Count, $himon.Memory.Count, ($asmTargets.Count + $himonTargets.Count))
