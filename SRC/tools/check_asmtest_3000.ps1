param(
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $SourcePath = Join-Path $repoRoot 'DOC\GUIDES\ASM\SAMPLES\ASMTEST_3000.asm'
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "ASMTEST source not found: $SourcePath"
}

$lineMax = 63
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
$directives = @('DC','DS','END','EQU','ORG')
$registers = @('A','X','Y')

$mnemonicSet = @{}
$directiveSet = @{}
$reservedSet = @{}
foreach ($m in $mnemonics) { $mnemonicSet[$m] = $true; $reservedSet[$m] = $true }
foreach ($d in $directives) { $directiveSet[$d] = $true; $reservedSet[$d] = $true }
foreach ($r in $registers) { $reservedSet[$r] = $true }

$defs = @{}
$refs = @{}
$seedBytes = New-Object System.Collections.Generic.List[int]
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

function Convert-DcItemToBytes {
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
            Fail-AsmTest $LineNo "decimal DC byte out of range: $Item"
        }
        return @($value)
    }
    if ($itemText -match "^'(.)'$") {
        return @([int][char]$matches[1])
    }
    if ($itemText -eq "''''") {
        return @([int][char]"'")
    }

    Fail-AsmTest $LineNo "unsupported DC item in ASMTEST: $Item"
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
            continue
        }
        $next = Read-HeadToken $head.Rest
        $op = $next.Token.ToUpperInvariant()
        $tail = $next.Rest
        Add-Def $label $lineNo
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
        }
        'EQU' {
            if (-not $label) {
                Fail-AsmTest $lineNo "EQU requires a symbol name"
            }
            if ($tail.Length -eq 0) {
                Fail-AsmTest $lineNo "EQU requires an expression"
            }
        }
        'DC' {
            if ($tail.Length -eq 0) {
                Fail-AsmTest $lineNo "DC requires data"
            }
            foreach ($item in ($tail -split ',')) {
                foreach ($b in (Convert-DcItemToBytes $item $lineNo)) {
                    [void]$seedBytes.Add($b)
                }
            }
        }
        default {
            Add-RefsFromTail $tail
        }
    }
}

foreach ($name in $refs.Keys) {
    if (-not $defs.ContainsKey($name)) {
        Fail-AsmTest 0 "unresolved sample reference: $name"
    }
}

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

$defsText = ($defs.Keys | Sort-Object) -join ','
$refsText = ($refs.Keys | Sort-Object) -join ','
$checksumText = '$' + ('{0:X2}' -f $checksum)
Write-Host ("ASMTEST_3000 OK lines={0} max={1} seed={2} checksum={3}" -f $lines.Count, $maxSeen, $seedBytes.Count, $checksumText)
Write-Host ("defs={0}" -f $defsText)
Write-Host ("refs={0}" -f $refsText)
