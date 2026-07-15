param(
    [Parameter(Mandatory=$true)][string]$MapPath
)

if (-not (Test-Path -LiteralPath $MapPath)) {
    throw "Map not found: $MapPath"
}

$symbols = @{}
foreach ($line in Get-Content -LiteralPath $MapPath) {
    if ($line -match '^\s*([0-9A-Fa-f]{8})\s+([A-Za-z_][A-Za-z0-9_]*)\s*$') {
        $symbols[$matches[2]] = [Convert]::ToInt32($matches[1], 16)
    }
}

function Get-Symbol([string]$Name) {
    if (-not $symbols.ContainsKey($Name)) {
        throw "Required symbol missing from map: $Name"
    }
    return $symbols[$Name]
}

$expected = [ordered]@{
    'ASM_LOW_SYM_NAMES' = 0x0200
    'ASM_SYM_NAMES' = 0x0200
    'ASM_LOW_FIX_NAMES' = 0x0A00
    'ASM_FIX_NAME_TEXT' = 0x0A00
    'ASM_LOW_TABLE_END' = 0x1A00
    '_BEG_UDATA' = 0x5000
}

foreach ($item in $expected.GetEnumerator()) {
    $actual = Get-Symbol $item.Key
    if ($actual -ne $item.Value) {
        throw ('{0}={1:X4}, expected {2:X4}' -f $item.Key, $actual, $item.Value)
    }
}

$endUdata = Get-Symbol '_END_UDATA'
$workspaceEnd = Get-Symbol 'ASM_WORKSPACE_END'
if ($workspaceEnd -ne $endUdata) {
    throw ('ASM_WORKSPACE_END={0:X4}, _END_UDATA={1:X4}' -f $workspaceEnd, $endUdata)
}
if ($endUdata -gt 0x7E00) {
    throw ('Flash ASM UDATA crosses HIMON workspace: _END_UDATA={0:X4}' -f $endUdata)
}

Write-Host ('asm-v1-flash RAM map low=0200-19FF udata=5000-{0:X4} upper={0:X4}-7DFF' -f $endUdata)
