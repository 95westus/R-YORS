param(
    [string]$S19Path = "BUILD/s19/ap-store-v1-sector-tool-7000.s19",
    [string]$SourcePath = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-sector-tool-7000.a"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "AP Store .a identity: $Message" }

$expected = @{}
$entry = $null
foreach ($raw in Get-Content -LiteralPath $S19Path) {
    $line = $raw.Trim()
    if (-not $line) { continue }
    if ($line -notmatch '^S([19])([0-9A-Fa-f]+)$') { Fail "unsupported S-record $line" }
    $kind = $Matches[1]; $hex = $Matches[2]
    $bytes = for ($i = 0; $i -lt $hex.Length; $i += 2) { [Convert]::ToInt32($hex.Substring($i, 2), 16) }
    $address = ($bytes[1] -shl 8) -bor $bytes[2]
    if ($kind -eq '9') { $entry = $address; continue }
    for ($i = 0; $i -lt ($bytes[0] - 3); $i++) { $expected[$address + $i] = $bytes[3 + $i] }
}
if ($entry -ne 0x7000) { Fail ('S9 entry ${0:X4}, expected $7000' -f $entry) }

$actual = @{}
$pc = $null
foreach ($raw in Get-Content -LiteralPath $SourcePath) {
    $line = ($raw -split ';', 2)[0].Trim()
    if (-not $line) { continue }
    if ($line -match '^ORG\s+\$([0-9A-Fa-f]{4})$') { $pc = [Convert]::ToInt32($Matches[1], 16); continue }
    if ($line -match '^DB\s+(.+)$') {
        if ($null -eq $pc) { Fail 'DB before ORG' }
        foreach ($atom in $Matches[1].Split(',')) {
            $token = $atom.Trim()
            if ($token -notmatch '^\$([0-9A-Fa-f]{2})$') { Fail "bad DB atom $token" }
            if ($actual.ContainsKey($pc)) { Fail ('duplicate byte ${0:X4}' -f $pc) }
            $actual[$pc] = [Convert]::ToInt32($Matches[1], 16)
            $pc++
        }
        continue
    }
    if ($line -eq 'END') { continue }
    Fail "unsupported source line: $line"
}

if ($actual.Count -ne $expected.Count) { Fail "byte count $($actual.Count), expected $($expected.Count)" }
foreach ($address in $expected.Keys) {
    if (-not $actual.ContainsKey($address)) { Fail ('missing ${0:X4}' -f $address) }
    if ($actual[$address] -ne $expected[$address]) { Fail ('byte differs at ${0:X4}' -f $address) }
}
Write-Host ('AP STORE .A IDENTITY = PASS; entry=$7000 bytes={0}' -f $actual.Count)
