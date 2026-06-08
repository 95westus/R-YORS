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

function Assert-ModeRowShardFits {
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
        Fail-OpcodeAudit "missing row shard $Label"
    }

    $bytes = 0
    $sawSentinel = $false
    for ($i = $start + 1; $i -lt $script:sectionLines.Count; $i++) {
        $line = $script:sectionLines[$i]
        if ($line -match '^\s*DB\s+\$FF\s*,') {
            $sawSentinel = $true
            break
        }
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -match '^\s*;') {
            continue
        }
        if ($line -match '^[A-Z0-9_]+:') {
            continue
        }
        if ($line -match (
                '^\s*DB\s+ASM_VID_[A-Z0-9_]+\s*,\s*' +
                'ASM_OPM_[A-Z0-9_]+\s*,\s*\$[0-9A-Fa-f]{2}\s*$'
            )) {
            $bytes += 3
            continue
        }
    }

    if (-not $sawSentinel) {
        Fail-OpcodeAudit "row shard $Label has no `$FF sentinel"
    }
    if ($bytes -gt 255) {
        Fail-OpcodeAudit (
            "row shard $Label is $bytes bytes; 8-bit scanner limit is 255"
        )
    }
}

Add-ExpectedRow 'RTS' 'NONE' 0x60
Add-ExpectedRow 'INX' 'NONE' 0xE8
Add-ExpectedRow 'CLC' 'NONE' 0x18
Add-ExpectedRow 'CLD' 'NONE' 0xD8
Add-ExpectedRow 'CLI' 'NONE' 0x58
Add-ExpectedRow 'CLV' 'NONE' 0xB8
Add-ExpectedRow 'SEC' 'NONE' 0x38
Add-ExpectedRow 'SED' 'NONE' 0xF8
Add-ExpectedRow 'SEI' 'NONE' 0x78
Add-ExpectedRow 'NOP' 'NONE' 0xEA
Add-ExpectedRow 'DEX' 'NONE' 0xCA
Add-ExpectedRow 'DEY' 'NONE' 0x88
Add-ExpectedRow 'INY' 'NONE' 0xC8
Add-ExpectedRow 'TAX' 'NONE' 0xAA
Add-ExpectedRow 'TAY' 'NONE' 0xA8
Add-ExpectedRow 'TSX' 'NONE' 0xBA
Add-ExpectedRow 'TXA' 'NONE' 0x8A
Add-ExpectedRow 'TXS' 'NONE' 0x9A
Add-ExpectedRow 'TYA' 'NONE' 0x98
Add-ExpectedRow 'PHA' 'NONE' 0x48
Add-ExpectedRow 'PHP' 'NONE' 0x08
Add-ExpectedRow 'PHX' 'NONE' 0xDA
Add-ExpectedRow 'PHY' 'NONE' 0x5A
Add-ExpectedRow 'PLA' 'NONE' 0x68
Add-ExpectedRow 'PLP' 'NONE' 0x28
Add-ExpectedRow 'PLX' 'NONE' 0xFA
Add-ExpectedRow 'PLY' 'NONE' 0x7A
Add-ExpectedRow 'RTI' 'NONE' 0x40
Add-ExpectedRow 'WAI' 'NONE' 0xCB
Add-ExpectedRow 'STP' 'NONE' 0xDB
Add-ExpectedRow 'LDX' 'IMM8' 0xA2
Add-ExpectedRow 'LDX' 'ZP8' 0xA6
Add-ExpectedRow 'LDX' 'ABS16' 0xAE
Add-ExpectedRow 'LDX' 'ZP_Y' 0xB6
Add-ExpectedRow 'LDX' 'ABS_Y' 0xBE
Add-ExpectedRow 'LDY' 'IMM8' 0xA0
Add-ExpectedRow 'LDY' 'ZP8' 0xA4
Add-ExpectedRow 'LDY' 'ABS16' 0xAC
Add-ExpectedRow 'LDY' 'ZP_X' 0xB4
Add-ExpectedRow 'LDY' 'ABS_X' 0xBC
Add-ExpectedRow 'CPX' 'IMM8' 0xE0
Add-ExpectedRow 'CPX' 'ZP8' 0xE4
Add-ExpectedRow 'CPX' 'ABS16' 0xEC
Add-ExpectedRow 'CPY' 'IMM8' 0xC0
Add-ExpectedRow 'CPY' 'ZP8' 0xC4
Add-ExpectedRow 'CPY' 'ABS16' 0xCC

Add-ExpectedRow 'ADC' 'IMM8' 0x69
Add-ExpectedRow 'ADC' 'ZP_X_IND' 0x61
Add-ExpectedRow 'ADC' 'ZP8' 0x65
Add-ExpectedRow 'ADC' 'ABS16' 0x6D
Add-ExpectedRow 'ADC' 'ZP_IND' 0x72
Add-ExpectedRow 'ADC' 'ZP_X' 0x75
Add-ExpectedRow 'ADC' 'ZP_IND_Y' 0x71
Add-ExpectedRow 'ADC' 'ABS_Y' 0x79
Add-ExpectedRow 'ADC' 'ABS_X' 0x7D

Add-ExpectedRow 'SBC' 'IMM8' 0xE9
Add-ExpectedRow 'SBC' 'ZP_X_IND' 0xE1
Add-ExpectedRow 'SBC' 'ZP8' 0xE5
Add-ExpectedRow 'SBC' 'ABS16' 0xED
Add-ExpectedRow 'SBC' 'ZP_IND' 0xF2
Add-ExpectedRow 'SBC' 'ZP_X' 0xF5
Add-ExpectedRow 'SBC' 'ZP_IND_Y' 0xF1
Add-ExpectedRow 'SBC' 'ABS_Y' 0xF9
Add-ExpectedRow 'SBC' 'ABS_X' 0xFD

Add-ExpectedRow 'AND' 'IMM8' 0x29
Add-ExpectedRow 'AND' 'ZP_X_IND' 0x21
Add-ExpectedRow 'AND' 'ZP8' 0x25
Add-ExpectedRow 'AND' 'ABS16' 0x2D
Add-ExpectedRow 'AND' 'ZP_IND' 0x32
Add-ExpectedRow 'AND' 'ZP_X' 0x35
Add-ExpectedRow 'AND' 'ZP_IND_Y' 0x31
Add-ExpectedRow 'AND' 'ABS_Y' 0x39
Add-ExpectedRow 'AND' 'ABS_X' 0x3D

Add-ExpectedRow 'ORA' 'IMM8' 0x09
Add-ExpectedRow 'ORA' 'ZP_X_IND' 0x01
Add-ExpectedRow 'ORA' 'ZP8' 0x05
Add-ExpectedRow 'ORA' 'ABS16' 0x0D
Add-ExpectedRow 'ORA' 'ZP_IND' 0x12
Add-ExpectedRow 'ORA' 'ZP_X' 0x15
Add-ExpectedRow 'ORA' 'ZP_IND_Y' 0x11
Add-ExpectedRow 'ORA' 'ABS_Y' 0x19
Add-ExpectedRow 'ORA' 'ABS_X' 0x1D

Add-ExpectedRow 'CMP' 'IMM8' 0xC9
Add-ExpectedRow 'CMP' 'ZP_X_IND' 0xC1
Add-ExpectedRow 'CMP' 'ZP8' 0xC5
Add-ExpectedRow 'CMP' 'ABS16' 0xCD
Add-ExpectedRow 'CMP' 'ZP_IND' 0xD2
Add-ExpectedRow 'CMP' 'ZP_X' 0xD5
Add-ExpectedRow 'CMP' 'ZP_IND_Y' 0xD1
Add-ExpectedRow 'CMP' 'ABS_Y' 0xD9
Add-ExpectedRow 'CMP' 'ABS_X' 0xDD

Add-ExpectedRow 'INC' 'ACC' 0x1A
Add-ExpectedRow 'INC' 'ZP8' 0xE6
Add-ExpectedRow 'INC' 'ABS16' 0xEE
Add-ExpectedRow 'INC' 'ZP_X' 0xF6
Add-ExpectedRow 'INC' 'ABS_X' 0xFE

Add-ExpectedRow 'DEC' 'ACC' 0x3A
Add-ExpectedRow 'DEC' 'ZP8' 0xC6
Add-ExpectedRow 'DEC' 'ABS16' 0xCE
Add-ExpectedRow 'DEC' 'ZP_X' 0xD6
Add-ExpectedRow 'DEC' 'ABS_X' 0xDE

Add-ExpectedRow 'STZ' 'ZP8' 0x64
Add-ExpectedRow 'STZ' 'ABS16' 0x9C
Add-ExpectedRow 'STZ' 'ZP_X' 0x74
Add-ExpectedRow 'STZ' 'ABS_X' 0x9E

Add-ExpectedRow 'STX' 'ZP8' 0x86
Add-ExpectedRow 'STX' 'ABS16' 0x8E
Add-ExpectedRow 'STX' 'ZP_Y' 0x96

Add-ExpectedRow 'STY' 'ZP8' 0x84
Add-ExpectedRow 'STY' 'ABS16' 0x8C
Add-ExpectedRow 'STY' 'ZP_X' 0x94

Add-ExpectedRow 'TRB' 'ZP8' 0x14
Add-ExpectedRow 'TRB' 'ABS16' 0x1C

Add-ExpectedRow 'TSB' 'ZP8' 0x04
Add-ExpectedRow 'TSB' 'ABS16' 0x0C

Add-ExpectedRow 'EOR' 'IMM8' 0x49
Add-ExpectedRow 'EOR' 'ZP_X_IND' 0x41
Add-ExpectedRow 'EOR' 'ZP8' 0x45
Add-ExpectedRow 'EOR' 'ABS16' 0x4D
Add-ExpectedRow 'EOR' 'ZP_IND' 0x52
Add-ExpectedRow 'EOR' 'ZP_X' 0x55
Add-ExpectedRow 'EOR' 'ZP_IND_Y' 0x51
Add-ExpectedRow 'EOR' 'ABS_Y' 0x59
Add-ExpectedRow 'EOR' 'ABS_X' 0x5D

Add-ExpectedRow 'STA' 'ZP_X_IND' 0x81
Add-ExpectedRow 'STA' 'ZP8' 0x85
Add-ExpectedRow 'STA' 'ABS16' 0x8D
Add-ExpectedRow 'STA' 'ZP_IND' 0x92
Add-ExpectedRow 'STA' 'ZP_X' 0x95
Add-ExpectedRow 'STA' 'ZP_IND_Y' 0x91
Add-ExpectedRow 'STA' 'ABS_Y' 0x99
Add-ExpectedRow 'STA' 'ABS_X' 0x9D

Add-ExpectedRow 'LDA' 'IMM8' 0xA9
Add-ExpectedRow 'LDA' 'ZP_X_IND' 0xA1
Add-ExpectedRow 'LDA' 'ZP8' 0xA5
Add-ExpectedRow 'LDA' 'ABS16' 0xAD
Add-ExpectedRow 'LDA' 'ZP_IND' 0xB2
Add-ExpectedRow 'LDA' 'ZP_X' 0xB5
Add-ExpectedRow 'LDA' 'ZP_IND_Y' 0xB1
Add-ExpectedRow 'LDA' 'ABS_Y' 0xB9
Add-ExpectedRow 'LDA' 'ABS_X' 0xBD

Add-ExpectedRow 'BIT' 'IMM8' 0x89
Add-ExpectedRow 'BIT' 'ZP8' 0x24
Add-ExpectedRow 'BIT' 'ABS16' 0x2C
Add-ExpectedRow 'BIT' 'ZP_X' 0x34
Add-ExpectedRow 'BIT' 'ABS_X' 0x3C

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
Add-ExpectedRow 'JMP' 'ABS16' 0x4C
Add-ExpectedRow 'JMP' 'ABS_IND' 0x6C
Add-ExpectedRow 'JMP' 'ABS_X_IND' 0x7C
Add-ExpectedRow 'BRK' 'IMM8' 0x00
Add-ExpectedRow 'BRK' 'ZP8' 0x00

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

Assert-ModeRowShardFits 'ASM_FIND_OPCODE_MODE_ROWS_A'
Assert-ModeRowShardFits 'ASM_FIND_OPCODE_MODE_ROWS_B'

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
    $noneTableRow = [regex]::Match(
        $handlerBlock,
        '(?m)^\s*DB\s+ASM_VID_' + [regex]::Escape($mnemonic) + '\s*,\s*\$([0-9A-Fa-f]{2})\s*$'
    )
    if ($noneTableRow.Success) {
        Add-ActualRow $mnemonic 'NONE' ([Convert]::ToInt32($noneTableRow.Groups[1].Value, 16)) $handlerLabel
        continue
    }

    $modeTableRows = [regex]::Matches(
        $handlerBlock,
        '(?m)^\s*DB\s+ASM_VID_' + [regex]::Escape($mnemonic) + '\s*,\s*ASM_OPM_([A-Z0-9_]+)\s*,\s*\$([0-9A-Fa-f]{2})\s*$'
    )
    if ($modeTableRows.Count -gt 0) {
        foreach ($rowMatch in $modeTableRows) {
            Add-ActualRow $mnemonic $rowMatch.Groups[1].Value ([Convert]::ToInt32($rowMatch.Groups[2].Value, 16)) $handlerLabel
        }
        continue
    }

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
