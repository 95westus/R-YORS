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
if ($endUdata -gt 0x7D00) {
    throw ('Flash ASM UDATA crosses HIMON workspace: _END_UDATA={0:X4}' -f $endUdata)
}

$pcLo = Get-Symbol 'ASM_PC_LO'
$pcHi = Get-Symbol 'ASM_PC_HI'
$cmdLo = Get-Symbol 'ASMF_CMD_PTR_LO'
$cmdHi = Get-Symbol 'ASMF_CMD_PTR_HI'
if ($pcLo -ne 0x80 -or $pcHi -ne 0x81 -or
    $cmdLo -ne 0x82 -or $cmdHi -ne 0x83) {
    throw ('ASM flash zero-page frame changed: PC={0:X2}-{1:X2} CMD={2:X2}-{3:X2}' -f
        $pcLo, $pcHi, $cmdLo, $cmdHi)
}

# Wrapper call sites and the status dispatcher store only low-byte message
# pointers.  The ordered messages occupy adjacent pages with disjoint
# low-byte ranges around MSG_TITLE's low byte so ASMF_MSG_XY can recover the
# page without alignment padding.
$messageFirst = Get-Symbol 'MSG_TITLE'
$messageSplit = Get-Symbol 'MSG_STATUS_BAD_LINE'
$messageEnd = (Get-Symbol 'ASMF_CMD_RELOCATE') - 1
if (($messageSplit -band 0x00FF) -ge ($messageFirst -band 0x00FF) -or
    ($messageSplit -band 0xFF00) -ne (($messageFirst -band 0xFF00) + 0x0100) -or
    ($messageEnd -band 0xFF00) -ne ($messageSplit -band 0xFF00) -or
    ($messageEnd -band 0x00FF) -ge ($messageFirst -band 0x00FF)) {
    throw ('ASM flash message-page split invalid: {0:X4}/{1:X4}-{2:X4}' -f
        $messageFirst, $messageSplit, $messageEnd)
}

Write-Host ('asm-v1-flash RAM map low=0200-19FF user=1A00-1FFF udata=5000-{0:X4} upper={0:X4}-7CFF' -f $endUdata)
