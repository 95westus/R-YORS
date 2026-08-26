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
        if ($raw -match '^\s*;\s*BEGIN SHARED BANKAUDIT BODY\s*$') { $inside = $true; continue }
        if ($raw -match '^\s*;\s*END SHARED BANKAUDIT BODY\s*$') { $inside = $false; break }
        if (-not $inside) { continue }
        $line = ($raw -replace ';.*$', '').Trim()
        if ($line.Length -eq 0) { continue }
        if (-not $AsmNative -and $line -match '^ENTRY\s+') { continue }
        $line = $line.ToUpperInvariant()
        $line = $line -replace '^([A-Z_][A-Z0-9_]*):', '$1 '
        $line = $line -replace '\s*,\s*', ','
        $line = $line -replace '\s+', ' '
        $body.Add($line.Trim())
    }
    if ($inside) { throw "$Path is missing END SHARED BANKAUDIT BODY" }
    if ($body.Count -eq 0) { throw "$Path has an empty shared body" }
    return $body.ToArray()
}

function Read-S19 {
    param([string]$Path)
    $data = [Collections.Generic.SortedDictionary[int,byte]]::new()
    $entry = $null
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        $line = $raw.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line -notmatch '^S([0-9])([0-9A-Fa-f]{2})([0-9A-Fa-f]+)$') { throw "malformed S-record: $line" }
        $type = [int]$matches[1]
        $count = [Convert]::ToInt32($matches[2],16)
        $tail = $matches[3]
        if ($tail.Length -ne $count * 2) { throw "wrong S-record byte count: $line" }
        $bytes = for ($i=0; $i -lt $count; $i++) { [Convert]::ToByte($tail.Substring(2*$i,2),16) }
        $sum = $count
        foreach ($b in $bytes) { $sum += $b }
        if (($sum -band 0xFF) -ne 0xFF) { throw "bad S-record checksum: $line" }
        $addressBytes = if ($type -in 1,9) { 2 } elseif ($type -in 2,8) { 3 } elseif ($type -in 3,7) { 4 } else { 0 }
        if ($addressBytes -eq 0) { continue }
        $address = 0
        for ($i=0; $i -lt $addressBytes; $i++) { $address = 256*$address + $bytes[$i] }
        if ($type -in 7,8,9) { $entry = $address -band 0xFFFF; continue }
        for ($i=0; $i -lt ($count-$addressBytes-1); $i++) { $data.Add(($address+$i)-band 0xFFFF,$bytes[$addressBytes+$i]) }
    }
    [pscustomobject]@{Data=$data;Entry=$entry}
}

$aText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $APath))
foreach ($required in @('IMPORT BIO_FTDI_PUT_CSTR','ENTRY BANKAUDIT','BANK_SELECT EQU $F010','BANK_SELECT_RAM EQU $0203')) {
    if (-not $aText.Contains($required)) { throw ".a is missing required contract: $required" }
}
foreach ($forbidden in @('$F003','FLASH_WRITE','FLASH_ERASE','PROGRAM_BYTE')) {
    if ($aText.Contains($forbidden)) { throw ".a reaches or names forbidden mutation surface: $forbidden" }
}

$aBody = Get-SharedBody -Path $APath
$asmBody = Get-SharedBody -Path $AsmPath -AsmNative
if ($aBody.Count -ne $asmBody.Count) { throw "shared body line count differs: .a=$($aBody.Count), .asm=$($asmBody.Count)" }
for ($i=0; $i -lt $aBody.Count; $i++) {
    if ($aBody[$i] -cne $asmBody[$i]) { throw "shared body differs at line $($i+1): .a='$($aBody[$i])' .asm='$($asmBody[$i])'" }
}

$s19 = Read-S19 -Path $S19Path
if ($s19.Entry -ne 0x2000) { throw ('S19 entry is ${0:X4}, expected $2000' -f $s19.Entry) }
$keys = @($s19.Data.Keys)
if ($keys.Count -eq 0 -or $keys[0] -ne 0x2000) { throw 'S19 does not begin at $2000' }
$last = $keys[-1]
for ($address=0x2000; $address -le $last; $address++) {
    if (-not $s19.Data.ContainsKey($address)) { throw ('S19 gap at ${0:X4}' -f $address) }
}
[byte[]]$image = for ($address=0x2000; $address -le $last; $address++) { $s19.Data[$address] }
if ($image.Length -gt 0x0800) { throw ('BANKAUDIT body ${0:X4} leaves too little AP-v2 metadata headroom' -f $image.Length) }
$hex = [BitConverter]::ToString($image).Replace('-','')
foreach ($required in @('2010F0','200302','B1A691A8')) {
    if (-not $hex.Contains($required)) { throw "S19 is missing required read-only bank-stage sequence $required" }
}

$fnv = [uint64]2166136261
foreach ($b in $image) { $fnv = (($fnv -bxor [uint64]$b) * [uint64]16777619) -band [uint64]4294967295 }
Write-Host ('BANKAUDIT .a/.asm shared body: {0} logical lines, identical' -f $aBody.Count)
Write-Host ('BANKAUDIT S19: $2000-${0:X4}, {1} bytes, FNV32=${2:X8}' -f $last,$image.Length,[uint32]$fnv)
Write-Host 'BANKAUDIT policy: read-only bank select/stage/CRC; no mutation doorway'
