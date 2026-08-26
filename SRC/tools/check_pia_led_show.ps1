param(
    [Parameter(Mandatory = $true)][string]$AsmPath,
    [Parameter(Mandatory = $true)][string]$APath,
    [Parameter(Mandatory = $true)][string]$S19Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SharedBody {
    param([string]$Path, [switch]$AsmNative)

    $inside = $false
    $body = [Collections.Generic.List[string]]::new()
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        if ($raw -match '^\s*;\s*BEGIN SHARED LED BODY\s*$') {
            $inside = $true
            continue
        }
        if ($raw -match '^\s*;\s*END SHARED LED BODY\s*$') {
            $inside = $false
            break
        }
        if (-not $inside) { continue }

        $line = ($raw -replace ';.*$', '').Trim()
        if ($line.Length -eq 0) { continue }
        if ($AsmNative -and $line -match '^ENTRY\s+') { continue }
        $line = $line.ToUpperInvariant()
        $line = $line -replace '^([A-Z_][A-Z0-9_]*):', '$1 '
        $line = $line -replace '\s*,\s*', ','
        $line = $line -replace '\s+', ' '
        $body.Add($line.Trim())
    }
    if ($inside) { throw "missing END SHARED LED BODY in $Path" }
    if ($body.Count -eq 0) { throw "empty shared LED body in $Path" }
    return $body.ToArray()
}

function Read-S19 {
    param([string]$Path)

    $data = [Collections.Generic.SortedDictionary[int,byte]]::new()
    $entry = $null
    $lineNo = 0
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        $lineNo++
        $line = $raw.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line -notmatch '^S([0-9])([0-9A-Fa-f]{2})([0-9A-Fa-f]+)$') {
            throw "${Path}:$lineNo malformed S-record"
        }
        $type = [int]$matches[1]
        $count = [Convert]::ToInt32($matches[2], 16)
        $tail = $matches[3]
        if ($tail.Length -ne $count * 2) { throw "${Path}:$lineNo wrong byte count" }
        $bytes = for ($i = 0; $i -lt $count; $i++) {
            [Convert]::ToByte($tail.Substring($i * 2, 2), 16)
        }
        $sum = $count
        foreach ($b in $bytes) { $sum += $b }
        if (($sum -band 0xFF) -ne 0xFF) { throw "${Path}:$lineNo bad checksum" }

        $addressBytes = if ($type -in 1,9) { 2 } elseif ($type -in 2,8) { 3 } elseif ($type -in 3,7) { 4 } else { 0 }
        if ($addressBytes -eq 0) { continue }
        $address = 0
        for ($i = 0; $i -lt $addressBytes; $i++) { $address = ($address * 256) + $bytes[$i] }
        if ($type -in 7,8,9) {
            $entry = $address -band 0xFFFF
            continue
        }
        $payloadLength = $count - $addressBytes - 1
        for ($i = 0; $i -lt $payloadLength; $i++) {
            $absolute = ($address + $i) -band 0xFFFF
            if ($data.ContainsKey($absolute)) { throw "${Path}: duplicate byte at `$$('{0:X4}' -f $absolute)" }
            $data.Add($absolute, $bytes[$addressBytes + $i])
        }
    }
    return [pscustomobject]@{ Data = $data; Entry = $entry }
}

$aBody = Get-SharedBody -Path $APath -AsmNative
$asmBody = Get-SharedBody -Path $AsmPath
if ($aBody.Count -ne $asmBody.Count) {
    throw "shared body line count differs: .a=$($aBody.Count), .asm=$($asmBody.Count)"
}
for ($i = 0; $i -lt $aBody.Count; $i++) {
    if ($aBody[$i] -cne $asmBody[$i]) {
        throw "shared body differs at logical line $($i + 1): .a='$($aBody[$i])' .asm='$($asmBody[$i])'"
    }
}

$s19 = Read-S19 -Path $S19Path
if ($s19.Entry -ne 0x2000) { throw ('S19 entry is ${0:X4}, expected $2000' -f $s19.Entry) }
$addresses = @($s19.Data.Keys)
if ($s19.Data.Count -eq 0 -or $addresses[0] -ne 0x2000) { throw 'S19 does not begin at $2000' }
$last = $addresses[$addresses.Count - 1]
for ($address = 0x2000; $address -le $last; $address++) {
    if (-not $s19.Data.ContainsKey($address)) { throw ('S19 gap at ${0:X4}' -f $address) }
}

[byte[]]$image = for ($address = 0x2000; $address -le $last; $address++) { $s19.Data[$address] }
[byte[]]$patterns = 0x01,0x02,0x04,0x08,0x0F,0x00,0x10,0x20,0x40,0x80,0xF0,0x00,0x55,0xAA,0xFF,0x00
if ($image.Length -lt $patterns.Length) { throw 'S19 image is shorter than LED pattern table' }
for ($i = 0; $i -lt $patterns.Length; $i++) {
    if ($image[$image.Length - $patterns.Length + $i] -ne $patterns[$i]) {
        throw "S19 LED pattern table mismatch at index $i"
    }
}

$relocations = @(
    @{ Site = 0x2B; Target = 0x74 },
    @{ Site = 0x2E; Target = 0x55 },
    @{ Site = 0x59; Target = 0x65 },
    @{ Site = 0x5C; Target = 0x65 },
    @{ Site = 0x5F; Target = 0x65 },
    @{ Site = 0x62; Target = 0x65 }
)
foreach ($reloc in $relocations) {
    $actual = [int]$image[$reloc.Site] -bor ([int]$image[$reloc.Site + 1] -shl 8)
    $expected = 0x2000 + $reloc.Target
    if ($actual -ne $expected) {
        throw ('internal relocation site ${0:X4} targets ${1:X4}, expected ${2:X4}' -f (0x2000 + $reloc.Site), $actual, $expected)
    }
}

# AP v2: 31 fixed bytes, 1+5*n relocation bytes, one 6-character PIALED
# export (1 count + 8 fixed row bytes + 4 PACK40 bytes), one empty-import
# count byte, then BODY.
$packageLength = 31 + (1 + 5 * $relocations.Count) + 13 + 1 + $image.Length
if ($packageLength -ne 0x00D0) { throw ('AP package length is ${0:X4}, expected $00D0' -f $packageLength) }

# W65C21 Port A and DDRA share $7FA0. CRA bit 2 at $7FA1 selects the
# peripheral interface when set and DDRA when clear. Reject the former
# W65C22-style $7FA1/$7FA3 data/direction mapping.
$hex = [BitConverter]::ToString($image).Replace('-', '')
foreach ($required in @(
        'ADA17F4809048DA17FADA07F48',
        'ADA17F29FB8DA17FADA07F48A9FF8DA07F',
        'ADA17F09048DA17F',
        'ADA17F29FB8DA17F688DA07F',
        'ADA17F09048DA17F688DA07F688DA17F',
        '8DA07F206520')) {
    if (-not $hex.Contains($required)) {
        throw "S19 is missing required W65C21 Port-A access sequence $required"
    }
}
if ($hex.Contains('8DA37F')) { throw 'S19 still writes $7FA3 as though it were W65C22 DDRA' }

$fnv = [uint64]2166136261
foreach ($b in $image) { $fnv = (($fnv -bxor [uint64]$b) * [uint64]16777619) -band [uint64]4294967295 }
Write-Host ('PIA LED .a/.asm shared body: {0} logical lines, identical' -f $aBody.Count)
Write-Host ('PIA LED S19: $2000-${0:X4}, {1} bytes, FNV32=${2:X8}' -f $last, $image.Length, [uint32]$fnv)
Write-Host ('PIA LED AP: {0} internal relocations, expected onboard package length=${1:X4}' -f $relocations.Count, $packageLength)
