param(
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $SourcePath = Join-Path $repoRoot 'SRC\ASM\asm-v1-core.asm'
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "ASM opcode source not found: $SourcePath"
}

function Fail-OpcodeAudit {
    param([string]$Message)

    throw "ASM opcode coverage audit: $Message"
}

function Format-HexByte {
    param([int]$Value)

    '$' + ('{0:X2}' -f ($Value -band 0xFF))
}

$sourceFullPath = (Resolve-Path -LiteralPath $SourcePath).Path
$text = [System.IO.File]::ReadAllText($sourceFullPath)
$text = $text -replace "`r`n", "`n"
$sectionMatch = [regex]::Match(
    $text,
    '(?ms)^ASM_FIND_OPCODE:\n.*?^; -+\n; ROUTINE: ASM_EMIT'
)
if (-not $sectionMatch.Success) {
    Fail-OpcodeAudit 'could not locate ASM_FIND_OPCODE section'
}

$script:sectionText = $sectionMatch.Value
$script:sectionLines = $script:sectionText -split "`n"
$script:expectedRows = New-Object System.Collections.Generic.List[object]

function Add-ExpectedRow {
    param([string]$Mnemonic, [string]$Mode, [int]$Opcode)

    [void]$script:expectedRows.Add([pscustomobject]@{
        Mnemonic = $Mnemonic
        Mode = $Mode
        Opcode = $Opcode -band 0xFF
    })
}

function Get-AsmLabelBlock {
    param([string]$Label)

    $start = -1
    $labelPattern = '^' + [regex]::Escape($Label) + ':'
    for ($i = 0; $i -lt $script:sectionLines.Count; $i++) {
        if ($script:sectionLines[$i] -match $labelPattern) {
            $start = $i
            break
        }
    }
    if ($start -lt 0) {
        Fail-OpcodeAudit "missing label $Label"
    }

    $block = New-Object System.Collections.Generic.List[string]
    for ($i = $start + 1; $i -lt $script:sectionLines.Count; $i++) {
        if ($script:sectionLines[$i] -match '^[A-Z0-9_]+:') {
            break
        }
        [void]$block.Add($script:sectionLines[$i])
    }

    $block -join "`n"
}

function Read-OpcodeForLabel {
    param([string]$Label)

    $block = Get-AsmLabelBlock $Label
    $opcodeMatch = [regex]::Match($block, '(?m)^\s*LDA\s+#\$([0-9A-Fa-f]{2})\s*$')
    if (-not $opcodeMatch.Success) {
        Fail-OpcodeAudit "missing literal opcode load in $Label"
    }

    [Convert]::ToInt32($opcodeMatch.Groups[1].Value, 16)
}

Add-ExpectedRow 'RTS' 'NONE' 0x60
Add-ExpectedRow 'INX' 'NONE' 0xE8
Add-ExpectedRow 'LDX' 'IMM8' 0xA2
Add-ExpectedRow 'LDY' 'IMM8' 0xA0
Add-ExpectedRow 'CPX' 'IMM8' 0xE0

Add-ExpectedRow 'STZ' 'ZP8' 0x64
Add-ExpectedRow 'STZ' 'ABS16' 0x9C
Add-ExpectedRow 'STZ' 'ZP_X' 0x74
Add-ExpectedRow 'STZ' 'ABS_X' 0x9E

Add-ExpectedRow 'EOR' 'IMM8' 0x49
Add-ExpectedRow 'EOR' 'ZP8' 0x45
Add-ExpectedRow 'EOR' 'ABS16' 0x4D
Add-ExpectedRow 'EOR' 'ZP_X' 0x55
Add-ExpectedRow 'EOR' 'ABS_X' 0x5D

Add-ExpectedRow 'STA' 'ZP8' 0x85
Add-ExpectedRow 'STA' 'ABS16' 0x8D
Add-ExpectedRow 'STA' 'ZP_X' 0x95
Add-ExpectedRow 'STA' 'ABS_X' 0x9D

Add-ExpectedRow 'LDA' 'IMM8' 0xA9
Add-ExpectedRow 'LDA' 'ZP8' 0xA5
Add-ExpectedRow 'LDA' 'ABS16' 0xAD
Add-ExpectedRow 'LDA' 'ZP_X' 0xB5
Add-ExpectedRow 'LDA' 'ABS_X' 0xBD

Add-ExpectedRow 'ASL' 'NONE' 0x0A
Add-ExpectedRow 'ASL' 'ACC' 0x0A
Add-ExpectedRow 'ASL' 'ZP8' 0x06
Add-ExpectedRow 'ASL' 'ABS16' 0x0E
Add-ExpectedRow 'ASL' 'ZP_X' 0x16
Add-ExpectedRow 'ASL' 'ABS_X' 0x1E

Add-ExpectedRow 'LSR' 'NONE' 0x4A
Add-ExpectedRow 'LSR' 'ACC' 0x4A
Add-ExpectedRow 'LSR' 'ZP8' 0x46
Add-ExpectedRow 'LSR' 'ABS16' 0x4E
Add-ExpectedRow 'LSR' 'ZP_X' 0x56
Add-ExpectedRow 'LSR' 'ABS_X' 0x5E

Add-ExpectedRow 'ROL' 'NONE' 0x2A
Add-ExpectedRow 'ROL' 'ACC' 0x2A
Add-ExpectedRow 'ROL' 'ZP8' 0x26
Add-ExpectedRow 'ROL' 'ABS16' 0x2E
Add-ExpectedRow 'ROL' 'ZP_X' 0x36
Add-ExpectedRow 'ROL' 'ABS_X' 0x3E

Add-ExpectedRow 'ROR' 'NONE' 0x6A
Add-ExpectedRow 'ROR' 'ACC' 0x6A
Add-ExpectedRow 'ROR' 'ZP8' 0x66
Add-ExpectedRow 'ROR' 'ABS16' 0x6E
Add-ExpectedRow 'ROR' 'ZP_X' 0x76
Add-ExpectedRow 'ROR' 'ABS_X' 0x7E

Add-ExpectedRow 'JSR' 'ABS16' 0x20

Add-ExpectedRow 'BCC' 'REL8' 0x90
Add-ExpectedRow 'BCS' 'REL8' 0xB0
Add-ExpectedRow 'BEQ' 'REL8' 0xF0
Add-ExpectedRow 'BMI' 'REL8' 0x30
Add-ExpectedRow 'BNE' 'REL8' 0xD0
Add-ExpectedRow 'BPL' 'REL8' 0x10
Add-ExpectedRow 'BRA' 'REL8' 0x80
Add-ExpectedRow 'BVC' 'REL8' 0x50
Add-ExpectedRow 'BVS' 'REL8' 0x70

$branchSet = @{}
foreach ($mnemonic in @('BCC','BCS','BEQ','BMI','BNE','BPL','BRA','BVC','BVS')) {
    $branchSet[$mnemonic] = $true
}

$expectedHandlers = @{}
$expectedByKey = @{}
foreach ($row in $script:expectedRows) {
    $expectedHandlers[$row.Mnemonic] = $true
    $key = "{0}|{1}" -f $row.Mnemonic, $row.Mode
    if ($expectedByKey.ContainsKey($key)) {
        Fail-OpcodeAudit "duplicate expected row $key"
    }
    $expectedByKey[$key] = $row
}

$actualHandlers = @{}
foreach ($m in [regex]::Matches($script:sectionText, '(?m)^ASM_FIND_OPCODE_([A-Z0-9]+):')) {
    $actualHandlers[$m.Groups[1].Value] = $true
}

foreach ($mnemonic in ($expectedHandlers.Keys | Sort-Object)) {
    if (-not $actualHandlers.ContainsKey($mnemonic)) {
        Fail-OpcodeAudit "missing handler $mnemonic"
    }
}

foreach ($mnemonic in ($actualHandlers.Keys | Sort-Object)) {
    if (-not $expectedHandlers.ContainsKey($mnemonic)) {
        Fail-OpcodeAudit "unexpected handler $mnemonic"
    }
}

$branchBlock = Get-AsmLabelBlock 'ASM_FIND_OPCODE_BRANCH_A'
if (-not [regex]::IsMatch(
        $branchBlock,
        'CMP\s+#ASM_OPM_REL8\s*\n\s*BEQ\s+ASM_FIND_OPCODE_BRANCH_OK'
    )) {
    Fail-OpcodeAudit 'branch common path no longer checks REL8'
}

$actualRows = @{}
function Add-ActualRow {
    param(
        [string]$Mnemonic,
        [string]$Mode,
        [int]$Opcode,
        [string]$SourceLabel
    )

    $key = "{0}|{1}" -f $Mnemonic, $Mode
    if ($actualRows.ContainsKey($key)) {
        Fail-OpcodeAudit "duplicate active row $key"
    }
    $actualRows[$key] = [pscustomobject]@{
        Mnemonic = $Mnemonic
        Mode = $Mode
        Opcode = $Opcode -band 0xFF
        SourceLabel = $SourceLabel
    }
}

foreach ($mnemonic in ($actualHandlers.Keys | Sort-Object)) {
    $handlerLabel = "ASM_FIND_OPCODE_$mnemonic"
    if ($branchSet.ContainsKey($mnemonic)) {
        Add-ActualRow $mnemonic 'REL8' (Read-OpcodeForLabel $handlerLabel) $handlerLabel
        continue
    }

    $handlerBlock = Get-AsmLabelBlock $handlerLabel
    $modeMatches = [regex]::Matches(
        $handlerBlock,
        'CMP\s+#ASM_OPM_([A-Z0-9_]+)\s*\n\s*BEQ\s+(ASM_FIND_OPCODE_[A-Z0-9_]+)'
    )
    if ($modeMatches.Count -eq 0) {
        Fail-OpcodeAudit "handler $mnemonic has no mode checks"
    }

    foreach ($modeMatch in $modeMatches) {
        $mode = $modeMatch.Groups[1].Value
        $targetLabel = $modeMatch.Groups[2].Value
        Add-ActualRow $mnemonic $mode (Read-OpcodeForLabel $targetLabel) $targetLabel
    }
}

foreach ($key in ($expectedByKey.Keys | Sort-Object)) {
    if (-not $actualRows.ContainsKey($key)) {
        Fail-OpcodeAudit "missing active opcode row $key"
    }
    $expected = $expectedByKey[$key]
    $actual = $actualRows[$key]
    if ($actual.Opcode -ne $expected.Opcode) {
        $got = Format-HexByte $actual.Opcode
        $want = Format-HexByte $expected.Opcode
        Fail-OpcodeAudit "$key opcode $got, expected $want"
    }
}

foreach ($key in ($actualRows.Keys | Sort-Object)) {
    if (-not $expectedByKey.ContainsKey($key)) {
        Fail-OpcodeAudit "unexpected active opcode row $key"
    }
}

Write-Host ("ASM opcode coverage OK rows={0} mnemonics={1} source={2}" -f `
    $actualRows.Count, $actualHandlers.Count, (Split-Path -Leaf $sourceFullPath))

foreach ($group in ($script:expectedRows | Group-Object Mnemonic | Sort-Object Name)) {
    $cells = New-Object System.Collections.Generic.List[string]
    foreach ($row in $group.Group) {
        [void]$cells.Add(("{0}:{1}" -f $row.Mode, (Format-HexByte $row.Opcode)))
    }
    Write-Host ("{0} {1}" -f $group.Name, ($cells -join ' '))
}
