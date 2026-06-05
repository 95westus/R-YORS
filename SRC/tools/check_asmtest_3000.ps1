param(
    [string]$SourcePath,
    [string]$S19Path
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $SourcePath = Join-Path $repoRoot 'DOC\GUIDES\ASM\SAMPLES\ASMTEST_3000.asm'
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "ASMTEST source not found: $SourcePath"
}

if (-not [string]::IsNullOrWhiteSpace($S19Path) -and
    -not (Test-Path -LiteralPath $S19Path)) {
    throw "ASMTEST S19 not found: $S19Path"
}

$lineMax = 63
$expectedOrg = '$6800'
$expectedEqu = @{
    OUT = '$6900'
    SUM = '$6910'
    COUNT = '16'
}
$expectedImageStart = 0x6800
$expectedEndPc = 0x6827
$expectedImageBytes = @(
    0xA2,0x00,0x9C,0x10,0x69,0xBD,0x17,0x68,
    0x9D,0x00,0x69,0x4D,0x10,0x69,0x8D,0x10,
    0x69,0xE8,0xE0,0x10,0xD0,0xEF,0x60,0x52,
    0x2D,0x59,0x4F,0x52,0x53,0x20,0x41,0x53,
    0x4D,0x20,0x54,0x45,0x53,0x54,0x2E
)
$expectedOutputStart = 0x6900
$expectedOutputBytes = @(
    0x52,0x2D,0x59,0x4F,0x52,0x53,0x20,0x41,
    0x53,0x4D,0x20,0x54,0x45,0x53,0x54,0x2E,
    0x0F
)
$expectedChecksum = 0x0F
$expectedSeedBytes = 16

$mnemonics = @(
    'ADC','AND','ASL','BBR','BBS','BCC','BCS','BEQ','BIT','BMI','BNE','BPL',
    'BRA','BRK','BVC','BVS','CLC','CLD','CLI','CLV','CMP','CPX','CPY','DEC',
    'DEX','DEY','EOR','INC','INX','INY','JMP','JSR','LDA','LDX','LDY','LSR',
    'NOP','ORA','PHA','PHP','PHX','PHY','PLA','PLP','PLX','PLY','RMB','ROL',
    'ROR','RTI','RTS','SBC','SEC','SED','SEI','SMB','STA','STP','STX','STY',
    'STZ','TAX','TAY','TRB','TSB','TSX','TXA','TXS','TYA','WAI'
)
$directives = @('DB','DS','END','EQU','ORG')
$parkedDirectives = @('DC','ENTRY','EXTRN','START')
$registers = @('A','X','Y')

$mnemonicSet = @{}
$directiveSet = @{}
$parkedSet = @{}
$reservedSet = @{}
foreach ($m in $mnemonics) { $mnemonicSet[$m] = $true; $reservedSet[$m] = $true }
foreach ($d in $directives) { $directiveSet[$d] = $true; $reservedSet[$d] = $true }
foreach ($d in $parkedDirectives) { $parkedSet[$d] = $true; $reservedSet[$d] = $true }
foreach ($r in $registers) { $reservedSet[$r] = $true }

$defs = @{}
$refs = @{}
$symbolValues = @{}
$orgSeen = $false
$seedBytes = New-Object System.Collections.Generic.List[int]
$script:imageStart = $null
$script:pc = $null
$script:imageBytes = New-Object System.Collections.Generic.List[int]
$script:fixups = New-Object System.Collections.Generic.List[object]
$maxSeen = 0

function Fail-AsmTest {
    param([int]$LineNo, [string]$Message)
    throw ("ASMTEST_3000:{0}: {1}" -f $LineNo, $Message)
}

function Remove-AsmComment {
    param([string]$Line)

    for ($i = 0; $i -lt $Line.Length; $i++) {
        $ch = $Line[$i]
        if ($ch -eq "'") {
            if (($i + 2) -lt $Line.Length -and
                $Line[$i + 1] -eq "'" -and
                $Line[$i + 2] -eq "'") {
                $i += 2
                continue
            }

            $j = $i + 1
            while ($j -lt $Line.Length) {
                if ($Line[$j] -eq "'") {
                    $i = $j
                    break
                }
                $j++
            }
            continue
        }

        if ($ch -eq ';') {
            return $Line.Substring(0, $i)
        }
    }

    return $Line
}

function Read-HeadToken {
    param([string]$Text)

    $trim = $Text.Trim()
    if ($trim.Length -eq 0) {
        return $null
    }

    $parts = $trim -split '\s+', 2
    $token = $parts[0]
    $rest = ''
    if ($parts.Count -gt 1) {
        $rest = $parts[1].Trim()
    }

    [pscustomobject]@{
        Token = $token
        Rest = $rest
    }
}

function Test-SymbolName {
    param([string]$Name, [int]$LineNo)

    if ($Name.Length -lt 1 -or $Name.Length -gt 31) {
        Fail-AsmTest $LineNo "bad symbol length: $Name"
    }
    if ($Name[0] -match '[0-9]') {
        Fail-AsmTest $LineNo "symbol begins with digit: $Name"
    }
    if ($Name[0] -eq '.' -or $Name[0] -eq '?') {
        Fail-AsmTest $LineNo "LOCAL NYI: $Name"
    }
    if ($Name -notmatch '^[A-Z_][A-Z0-9_]*$') {
        Fail-AsmTest $LineNo "bad symbol characters: $Name"
    }
    if ($reservedSet.ContainsKey($Name)) {
        Fail-AsmTest $LineNo "reserved word used as symbol: $Name"
    }
}

function Add-Def {
    param([string]$Name, [int]$LineNo)

    if ($defs.ContainsKey($Name)) {
        Fail-AsmTest $LineNo "duplicate symbol: $Name"
    }
    $defs[$Name] = $LineNo
}

function Add-RefsFromTail {
    param([string]$Tail)

    foreach ($m in [regex]::Matches($Tail.ToUpperInvariant(), '[A-Z_][A-Z0-9_]*')) {
        $word = $m.Value
        if ($reservedSet.ContainsKey($word)) {
            continue
        }
        if (-not $refs.ContainsKey($word)) {
            $refs[$word] = 0
        }
        $refs[$word]++
    }
}

function Convert-DbItemToBytes {
    param([string]$Item, [int]$LineNo)

    $itemText = $Item.Trim().ToUpperInvariant()
    if ($itemText -match '^\$([0-9A-F]{1,2})$') {
        return @([Convert]::ToInt32($matches[1], 16))
    }
    if ($itemText -match '^\$([0-9A-F]{4})$') {
        $word = [Convert]::ToInt32($matches[1], 16)
        return @(($word -band 0xFF), (($word -shr 8) -band 0xFF))
    }
    if ($itemText -match '^[0-9]+$') {
        $value = [Convert]::ToInt32($itemText, 10)
        if ($value -lt 0 -or $value -gt 255) {
            Fail-AsmTest $LineNo "decimal DB byte out of range: $Item"
        }
        return @($value)
    }
    if ($itemText -match "^'(.)'$") {
        return @([int][char]$matches[1])
    }
    if ($itemText -eq "''''") {
        return @([int][char]"'")
    }

    Fail-AsmTest $LineNo "unsupported DB item in ASMTEST: $Item"
}

function Format-AsmAddress {
    param([int]$Value)

    '$' + ('{0:X4}' -f ($Value -band 0xFFFF))
}

function Format-HexByte {
    param([int]$Value)

    '$' + ('{0:X2}' -f ($Value -band 0xFF))
}

function Convert-AsmValue {
    param([string]$Text, [int]$LineNo)

    $valueText = $Text.Trim().ToUpperInvariant()
    if ($valueText -match '^\$([0-9A-F]{1,4})$') {
        return [Convert]::ToInt32($matches[1], 16)
    }
    if ($valueText -match '^[0-9]+$') {
        $value = [Convert]::ToInt32($valueText, 10)
        if ($value -lt 0 -or $value -gt 0xFFFF) {
            Fail-AsmTest $LineNo "numeric value out of range: $Text"
        }
        return $value
    }
    if ($symbolValues.ContainsKey($valueText)) {
        return [int]$symbolValues[$valueText]
    }

    Fail-AsmTest $LineNo "unresolved value in ASMTEST oracle: $Text"
}

function Set-SymbolValue {
    param([string]$Name, [int]$Value, [int]$LineNo)

    if ($symbolValues.ContainsKey($Name)) {
        Fail-AsmTest $LineNo "duplicate symbol value: $Name"
    }
    $symbolValues[$Name] = $Value -band 0xFFFF
}

function Start-ImageAt {
    param([int]$Address, [int]$LineNo)

    if ($null -ne $script:imageStart) {
        Fail-AsmTest $LineNo "ASMTEST image start is already set"
    }
    $script:imageStart = $Address -band 0xFFFF
    $script:pc = $script:imageStart
}

function Assert-ImageStarted {
    param([int]$LineNo)

    if ($null -eq $script:pc) {
        Fail-AsmTest $LineNo "emission before ORG"
    }
}

function Emit-AsmByte {
    param([int]$Value, [int]$LineNo)

    Assert-ImageStarted $LineNo
    if ($Value -lt 0 -or $Value -gt 0xFF) {
        Fail-AsmTest $LineNo "emitted byte out of range: $Value"
    }
    [void]$script:imageBytes.Add($Value -band 0xFF)
    $script:pc = ($script:pc + 1) -band 0xFFFF
}

function Emit-AsmWordLe {
    param([int]$Value, [int]$LineNo)

    Emit-AsmByte ($Value -band 0xFF) $LineNo
    Emit-AsmByte (($Value -shr 8) -band 0xFF) $LineNo
}

function Add-Fixup {
    param(
        [string]$Kind,
        [string]$Symbol,
        [int]$Site,
        [int]$Base,
        [int]$LineNo
    )

    [void]$script:fixups.Add([pscustomobject]@{
        Kind = $Kind
        Symbol = $Symbol
        Site = $Site -band 0xFFFF
        Base = $Base -band 0xFFFF
        LineNo = $LineNo
    })
}

function Patch-ImageByte {
    param([int]$Address, [int]$Value, [int]$LineNo)

    $offset = $Address - $script:imageStart
    if ($offset -lt 0 -or $offset -ge $script:imageBytes.Count) {
        $siteText = Format-AsmAddress $Address
        Fail-AsmTest $LineNo ("fixup site {0} outside emitted image" -f $siteText)
    }
    $script:imageBytes[$offset] = $Value -band 0xFF
}

function Resolve-Fixups {
    foreach ($fixup in $script:fixups) {
        if (-not $symbolValues.ContainsKey($fixup.Symbol)) {
            Fail-AsmTest $fixup.LineNo "unresolved sample fixup: $($fixup.Symbol)"
        }

        $target = [int]$symbolValues[$fixup.Symbol]
        switch ($fixup.Kind) {
            'ABS16' {
                Patch-ImageByte $fixup.Site ($target -band 0xFF) $fixup.LineNo
                $highSite = ($fixup.Site + 1) -band 0xFFFF
                $highByte = ($target -shr 8) -band 0xFF
                Patch-ImageByte $highSite $highByte $fixup.LineNo
            }
            'REL8' {
                $delta = $target - [int]$fixup.Base
                if ($delta -lt -128 -or $delta -gt 127) {
                    Fail-AsmTest $fixup.LineNo "relative fixup out of range: $($fixup.Symbol)"
                }
                Patch-ImageByte $fixup.Site ($delta -band 0xFF) $fixup.LineNo
            }
            default {
                Fail-AsmTest $fixup.LineNo "unknown ASMTEST fixup kind: $($fixup.Kind)"
            }
        }
    }
}

function Emit-AbsOperand {
    param([string]$Symbol, [int]$LineNo)

    $symbolName = $Symbol.ToUpperInvariant()
    if ($symbolValues.ContainsKey($symbolName)) {
        Emit-AsmWordLe ([int]$symbolValues[$symbolName]) $LineNo
        return
    }

    $site = $script:pc
    Emit-AsmWordLe 0xFFFF $LineNo
    Add-Fixup 'ABS16' $symbolName $site 0 $LineNo
}

function Emit-RelOperand {
    param([string]$Symbol, [int]$LineNo)

    $symbolName = $Symbol.ToUpperInvariant()
    $site = $script:pc
    $base = ($site + 1) -band 0xFFFF
    if ($symbolValues.ContainsKey($symbolName)) {
        $delta = [int]$symbolValues[$symbolName] - $base
        if ($delta -lt -128 -or $delta -gt 127) {
            Fail-AsmTest $LineNo "relative branch out of range: $Symbol"
        }
        Emit-AsmByte ($delta -band 0xFF) $LineNo
        return
    }

    Emit-AsmByte 0xFF $LineNo
    Add-Fixup 'REL8' $symbolName $site $base $LineNo
}

function Emit-AsmTestMnemonic {
    param([string]$Op, [string]$Tail, [int]$LineNo)

    $operand = $Tail.Trim().ToUpperInvariant()
    switch ($Op) {
        'LDX' {
            if ($operand -ne '#0') {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects LDX #0"
            }
            Emit-AsmByte 0xA2 $LineNo
            Emit-AsmByte 0x00 $LineNo
        }
        'STZ' {
            if ($operand -ne 'SUM') {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects STZ SUM"
            }
            Emit-AsmByte 0x9C $LineNo
            Emit-AbsOperand 'SUM' $LineNo
        }
        'LDA' {
            if ($operand -ne 'SEED,X') {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects LDA SEED,X"
            }
            Emit-AsmByte 0xBD $LineNo
            Emit-AbsOperand 'SEED' $LineNo
        }
        'STA' {
            if ($operand -eq 'OUT,X') {
                Emit-AsmByte 0x9D $LineNo
                Emit-AbsOperand 'OUT' $LineNo
            } elseif ($operand -eq 'SUM') {
                Emit-AsmByte 0x8D $LineNo
                Emit-AbsOperand 'SUM' $LineNo
            } else {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects STA OUT,X or STA SUM"
            }
        }
        'EOR' {
            if ($operand -ne 'SUM') {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects EOR SUM"
            }
            Emit-AsmByte 0x4D $LineNo
            Emit-AbsOperand 'SUM' $LineNo
        }
        'INX' {
            if ($operand.Length -ne 0) {
                Fail-AsmTest $LineNo "INX must not have an operand"
            }
            Emit-AsmByte 0xE8 $LineNo
        }
        'CPX' {
            if ($operand -ne '#COUNT') {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects CPX #COUNT"
            }
            Emit-AsmByte 0xE0 $LineNo
            Emit-AsmByte (Convert-AsmValue 'COUNT' $LineNo) $LineNo
        }
        'BNE' {
            if ($operand -ne 'LOOP') {
                Fail-AsmTest $LineNo "ASMTEST oracle only expects BNE LOOP"
            }
            Emit-AsmByte 0xD0 $LineNo
            Emit-RelOperand 'LOOP' $LineNo
        }
        'RTS' {
            if ($operand.Length -ne 0) {
                Fail-AsmTest $LineNo "RTS must not have an operand"
            }
            Emit-AsmByte 0x60 $LineNo
        }
        default {
            Fail-AsmTest $LineNo "ASMTEST oracle does not emit mnemonic: $Op"
        }
    }
}

function Compare-ByteList {
    param([object]$Actual, [object]$Expected, [string]$Name)

    if ($Actual.Count -ne $Expected.Count) {
        Fail-AsmTest 0 ("{0} byte count {1}, expected {2}" -f $Name, $Actual.Count, $Expected.Count)
    }

    for ($i = 0; $i -lt $Expected.Count; $i++) {
        $got = [int]$Actual[$i]
        $want = [int]$Expected[$i]
        if ($got -ne $want) {
            Fail-AsmTest 0 ("{0} byte {1} {2}, expected {3}" -f $Name, $i, (Format-HexByte $got), (Format-HexByte $want))
        }
    }
}

function Convert-S19Byte {
    param([string]$Text, [int]$LineNo, [string]$Context)

    if ($Text -notmatch '^[0-9A-Fa-f]{2}$') {
        Fail-AsmTest $LineNo "bad S19 byte in ${Context}: $Text"
    }

    [Convert]::ToInt32($Text, 16)
}

function Assert-S19Checksum {
    param([string]$Line, [int]$LineNo)

    $sum = 0
    for ($i = 2; $i -lt $Line.Length; $i += 2) {
        $sum = ($sum + (Convert-S19Byte $Line.Substring($i, 2) $LineNo 'checksum')) -band 0xFF
    }
    if ($sum -ne 0xFF) {
        Fail-AsmTest $LineNo "bad S19 checksum"
    }
}

function Read-S19Image {
    param([string]$Path)

    $bytes = @{}
    $start = $null
    $s19Lines = Get-Content -LiteralPath $Path

    for ($lineNo = 1; $lineNo -le $s19Lines.Count; $lineNo++) {
        $line = $s19Lines[$lineNo - 1].Trim()
        if ($line.Length -eq 0) {
            continue
        }
        if ($line -notmatch '^S[0-9][0-9A-Fa-f]+$') {
            Fail-AsmTest $lineNo "bad S19 record: $line"
        }

        $recordType = $line.Substring(1, 1)
        $count = Convert-S19Byte $line.Substring(2, 2) $lineNo 'count'
        $expectedLength = 4 + ($count * 2)
        if ($line.Length -ne $expectedLength) {
            Fail-AsmTest $lineNo ("S19 length {0}, expected {1}" -f $line.Length, $expectedLength)
        }
        Assert-S19Checksum $line $lineNo

        switch ($recordType) {
            '0' {
                continue
            }
            '1' {
                if ($count -lt 3) {
                    Fail-AsmTest $lineNo "S1 record count too short"
                }
                $address = [Convert]::ToInt32($line.Substring(4, 4), 16)
                $dataCount = $count - 3
                $dataOffset = 8
                for ($i = 0; $i -lt $dataCount; $i++) {
                    $byteText = $line.Substring($dataOffset + ($i * 2), 2)
                    $byte = Convert-S19Byte $byteText $lineNo 'data'
                    $bytes[($address + $i) -band 0xFFFF] = $byte
                }
            }
            '9' {
                if ($count -ne 3) {
                    Fail-AsmTest $lineNo "S9 record count must be 3"
                }
                $start = [Convert]::ToInt32($line.Substring(4, 4), 16)
            }
            default {
                Fail-AsmTest $lineNo "unsupported S19 record type: S$recordType"
            }
        }
    }

    [pscustomobject]@{
        Bytes = $bytes
        Start = $start
    }
}

function Compare-S19Image {
    param([string]$Path)

    $s19 = Read-S19Image $Path
    if ($null -eq $s19.Start) {
        Fail-AsmTest 0 "S19 start record is missing"
    }
    if ($s19.Start -ne $expectedImageStart) {
        $gotStart = Format-AsmAddress $s19.Start
        $wantStart = Format-AsmAddress $expectedImageStart
        Fail-AsmTest 0 ("S19 start {0}, expected {1}" -f $gotStart, $wantStart)
    }
    if ($s19.Bytes.Count -ne $expectedImageBytes.Count) {
        Fail-AsmTest 0 ("S19 data byte count {0}, expected {1}" -f `
            $s19.Bytes.Count, $expectedImageBytes.Count)
    }

    $actual = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $expectedImageBytes.Count; $i++) {
        $address = ($expectedImageStart + $i) -band 0xFFFF
        if (-not $s19.Bytes.ContainsKey($address)) {
            Fail-AsmTest 0 ("S19 missing byte at {0}" -f (Format-AsmAddress $address))
        }
        [void]$actual.Add([int]$s19.Bytes[$address])
    }

    Compare-ByteList $actual $expectedImageBytes 'WDC S19 image'

    $imageEnd = $expectedImageStart + $expectedImageBytes.Count - 1
    $startText = Format-AsmAddress $expectedImageStart
    $endText = Format-AsmAddress $imageEnd
    $entryText = Format-AsmAddress $s19.Start
    Write-Host ("wdc-s19={0}-{1} bytes={2} start={3}" -f `
        $startText, $endText, $expectedImageBytes.Count, $entryText)
}

$lines = Get-Content -LiteralPath $SourcePath
for ($lineNo = 1; $lineNo -le $lines.Count; $lineNo++) {
    $raw = $lines[$lineNo - 1]
    if ($raw.Length -gt $maxSeen) {
        $maxSeen = $raw.Length
    }
    if ($raw.Length -gt $lineMax) {
        Fail-AsmTest $lineNo ("line too long: {0} > {1}" -f $raw.Length, $lineMax)
    }

    $code = (Remove-AsmComment $raw).Trim()
    if ($code.Length -eq 0) {
        continue
    }

    if ($code -match '[()]') {
        Fail-AsmTest $lineNo "grouping/addressing parentheses are not expected in ASMTEST"
    }

    $head = Read-HeadToken $code
    $firstRaw = $head.Token.ToUpperInvariant()
    $first = $firstRaw
    $hasColon = $false
    if ($first.EndsWith(':')) {
        $hasColon = $true
        $first = $first.Substring(0, $first.Length - 1)
    }

    $label = $null
    $op = $null
    $tail = ''

    if ($hasColon) {
        Test-SymbolName $first $lineNo
        $label = $first
        Add-Def $label $lineNo
        if ($head.Rest.Length -eq 0) {
            if ($null -ne $script:pc) {
                Set-SymbolValue $label $script:pc $lineNo
            }
            continue
        }
        $next = Read-HeadToken $head.Rest
        $op = $next.Token.ToUpperInvariant()
        $tail = $next.Rest
    } elseif ($mnemonicSet.ContainsKey($first) -or $directiveSet.ContainsKey($first)) {
        $op = $first
        $tail = $head.Rest
    } else {
        Test-SymbolName $first $lineNo
        $label = $first
        if ($head.Rest.Length -eq 0) {
            Add-Def $label $lineNo
            if ($null -ne $script:pc) {
                Set-SymbolValue $label $script:pc $lineNo
            }
            continue
        }
        $next = Read-HeadToken $head.Rest
        $op = $next.Token.ToUpperInvariant()
        $tail = $next.Rest
        Add-Def $label $lineNo
    }

    if ($parkedSet.ContainsKey($op)) {
        Fail-AsmTest $lineNo "parked directive is not active: $op"
    }

    if (-not ($mnemonicSet.ContainsKey($op) -or $directiveSet.ContainsKey($op))) {
        Fail-AsmTest $lineNo "unknown operation: $op"
    }

    switch ($op) {
        'END' {
            if ($tail.Length -ne 0) {
                Fail-AsmTest $lineNo "END must not have an operand"
            }
        }
        'ORG' {
            if ($label) {
                Fail-AsmTest $lineNo "ORG must not have a label"
            }
            if ($tail -notmatch '^\$[0-9A-Fa-f]{4}$') {
                Fail-AsmTest $lineNo "ASMTEST ORG must be a four-digit hex address"
            }
            $orgText = $tail.ToUpperInvariant()
            if ($orgText -ne $expectedOrg) {
                Fail-AsmTest $lineNo ("ASMTEST ORG {0}, expected {1}" -f $orgText, $expectedOrg)
            }
            if ($orgSeen) {
                Fail-AsmTest $lineNo "ASMTEST must have only one ORG"
            }
            $orgSeen = $true
            Start-ImageAt (Convert-AsmValue $orgText $lineNo) $lineNo
        }
        'EQU' {
            if (-not $label) {
                Fail-AsmTest $lineNo "EQU requires a symbol name"
            }
            if ($tail.Length -eq 0) {
                Fail-AsmTest $lineNo "EQU requires an expression"
            }
            if ($expectedEqu.ContainsKey($label)) {
                $equText = $tail.ToUpperInvariant()
                if ($equText -ne $expectedEqu[$label]) {
                    Fail-AsmTest $lineNo ("{0} EQU {1}, expected {2}" -f $label, $equText, $expectedEqu[$label])
                }
            }
            Set-SymbolValue $label (Convert-AsmValue $tail $lineNo) $lineNo
        }
        'DB' {
            if ($tail.Length -eq 0) {
                Fail-AsmTest $lineNo "DB requires data"
            }
            if ($label) {
                Set-SymbolValue $label $script:pc $lineNo
            }
            foreach ($item in ($tail -split ',')) {
                foreach ($b in (Convert-DbItemToBytes $item $lineNo)) {
                    [void]$seedBytes.Add($b)
                    Emit-AsmByte $b $lineNo
                }
            }
        }
        default {
            if ($label) {
                Set-SymbolValue $label $script:pc $lineNo
            }
            Add-RefsFromTail $tail
            Emit-AsmTestMnemonic $op $tail $lineNo
        }
    }
}

if (-not $orgSeen) {
    Fail-AsmTest 0 "ASMTEST ORG is missing"
}

foreach ($name in $refs.Keys) {
    if (-not $defs.ContainsKey($name)) {
        Fail-AsmTest 0 "unresolved sample reference: $name"
    }
}

Resolve-Fixups

if ($seedBytes.Count -ne $expectedSeedBytes) {
    Fail-AsmTest 0 ("seed byte count {0}, expected {1}" -f $seedBytes.Count, $expectedSeedBytes)
}

$checksum = 0
foreach ($b in $seedBytes) {
    $checksum = $checksum -bxor $b
}

if ($checksum -ne $expectedChecksum) {
    $gotText = '$' + ('{0:X2}' -f $checksum)
    $expectedText = '$' + ('{0:X2}' -f $expectedChecksum)
    Fail-AsmTest 0 ("seed checksum {0}, expected {1}" -f $gotText, $expectedText)
}

if ($null -eq $script:imageStart) {
    Fail-AsmTest 0 "ASMTEST image start is missing"
}
if ($script:imageStart -ne $expectedImageStart) {
    $gotStart = Format-AsmAddress $script:imageStart
    $wantStart = Format-AsmAddress $expectedImageStart
    Fail-AsmTest 0 ("image start {0}, expected {1}" -f $gotStart, $wantStart)
}
if ($script:pc -ne $expectedEndPc) {
    $gotPc = Format-AsmAddress $script:pc
    $wantPc = Format-AsmAddress $expectedEndPc
    Fail-AsmTest 0 ("end PC {0}, expected {1}" -f $gotPc, $wantPc)
}
Compare-ByteList $script:imageBytes $expectedImageBytes 'image'

$outputBytes = New-Object System.Collections.Generic.List[int]
foreach ($b in $seedBytes) {
    [void]$outputBytes.Add($b)
}
[void]$outputBytes.Add($checksum)
Compare-ByteList $outputBytes $expectedOutputBytes 'runtime output'

$defsText = ($defs.Keys | Sort-Object) -join ','
$refsText = ($refs.Keys | Sort-Object) -join ','
$checksumText = '$' + ('{0:X2}' -f $checksum)
$imageEnd = $script:imageStart + $script:imageBytes.Count - 1
$outputEnd = $expectedOutputStart + $expectedOutputBytes.Count - 1
Write-Host ("ASMTEST_3000 OK org={0} lines={1} max={2} seed={3} checksum={4}" -f $expectedOrg, $lines.Count, $maxSeen, $seedBytes.Count, $checksumText)
Write-Host ("defs={0}" -f $defsText)
Write-Host ("refs={0}" -f $refsText)
$imageStartText = Format-AsmAddress $script:imageStart
$imageEndText = Format-AsmAddress $imageEnd
$outputStartText = Format-AsmAddress $expectedOutputStart
$outputEndText = Format-AsmAddress $outputEnd
$imageText = "image={0}-{1} bytes={2} output={3}-{4}" -f `
    $imageStartText, $imageEndText, $script:imageBytes.Count, `
    $outputStartText, $outputEndText
Write-Host $imageText

if (-not [string]::IsNullOrWhiteSpace($S19Path)) {
    Compare-S19Image $S19Path
}
