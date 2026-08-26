param(
    [string]$Vt102Path = "../DOC/GUIDES/ASM/SAMPLES/vt102-exerciser-7000.a",
    [string]$Vt525Path = "../DOC/GUIDES/ASM/SAMPLES/vt525-exerciser-7000.a"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Test-TerminalExerciser {
    param(
        [string]$Path,
        [string]$Name,
        [int]$ExpectedEnd,
        [int]$ExpectedWaitTokens
    )

    $lines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path))
    $maxLine = ($lines | ForEach-Object { $_.Length } |
        Measure-Object -Maximum).Maximum
    Assert-True ($maxLine -le 63) "$Name has a source line longer than 63 characters"

    $text = [string]::Join([Environment]::NewLine, $lines)
    $forbidden = '(?m)^\s*(ENTRY|EXPORT|IMPORT|PACKAGE|INSTALL|LOAD)\b'
    Assert-True ($text -notmatch $forbidden) "$Name contains AP metadata or package syntax"
    $oldAddress = '\$(3000|3030|3090|30D0|3200|4000|4030|4090|40D0|4200)'
    Assert-True ($text -notmatch $oldAddress) "$Name still contains an overlapping low-RAM address"

    $origins = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*ORG \$([0-9A-Fa-f]{4})') {
            $origins += [Convert]::ToInt32($Matches[1], 16)
        }
    }
    $expectedOrigins = @(0x7000, 0x7030, 0x7090, 0x70D0, 0x70F0, 0x7200)
    Assert-True (($origins -join ",") -eq ($expectedOrigins -join ",")) "$Name has an unexpected fixed-load ORG layout"

    $requiredEquates = @(
        'RUN\s+EQU\s+\$7030',
        'DRAIN\s+EQU\s+\$7090',
        'HEX\s+EQU\s+\$70D0',
        'WAIT\s+EQU\s+\$70F0',
        'SCRIPT\s+EQU\s+\$7200'
    )
    foreach ($pattern in $requiredEquates) {
        Assert-True ($text -match "(?m)^$pattern\s*$") "$Name is missing fixed equate $pattern"
    }

    $labelLines = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*([A-Za-z][A-Za-z0-9_]*)\s+(?!EQU\b)([A-Za-z]+)\b') {
            $labelLines[$Matches[1].ToUpperInvariant()] = $i
        }
    }

    $forwardBranches = 0
    $branch = '^\s*(?:[A-Za-z][A-Za-z0-9_]*\s+)?B(?:CC|CS|EQ|NE|RA)\s+([A-Za-z][A-Za-z0-9_]*)\s*$'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $branch) {
            $target = $Matches[1].ToUpperInvariant()
            Assert-True ($labelLines.ContainsKey($target)) "$Name branch target $target is undefined"
            if ($labelLines[$target] -gt $i) {
                $forwardBranches++
            }
        }
    }
    Assert-True ($forwardBranches -eq 11) "$Name uses $forwardBranches forward branch fixups; expected 11"

    $scriptStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*ORG \$7200\s*$') {
            $scriptStart = $i + 1
            break
        }
    }
    Assert-True ($scriptStart -ge 0) "$Name has no script origin"

    $scriptBytes = 0
    $tokens = @{ FC = 0; FD = 0; FE = 0; FF = 0 }
    $lastData = ""
    for ($i = $scriptStart; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*END\s*$') {
            break
        }
        if ($line -match '^\s*(?:;.*)?$') {
            continue
        }
        if ($line -match "^\s*DC\s+([CHP]?)'([^']*)'\s*(?:;.*)?$") {
            $size = $Matches[2].Length
            if ($Matches[1] -eq "C" -or $Matches[1] -eq "P") {
                $size++
            }
            $scriptBytes += $size
            $lastData = $line.Trim()
            continue
        }
        if ($line -match '^\s*DB\s+(.+?)(?:\s*;.*)?$') {
            $items = @($Matches[1] -split ",")
            $scriptBytes += $items.Count
            foreach ($item in $items) {
                $value = $item.Trim()
                if ($value -match '^\$(FC|FD|FE|FF)$') {
                    $tokens[$Matches[1]]++
                }
            }
            $lastData = $line.Trim()
            continue
        }
        throw "$Name has an unrecognized script line $($i + 1): $line"
    }

    $end = 0x7200 + $scriptBytes
    $rangeError = "{0} ends at {1:X4}; expected {2:X4}" -f $Name, $end, $ExpectedEnd
    Assert-True ($end -eq $ExpectedEnd) $rangeError
    Assert-True ($end -le 0x7C00) "$Name exceeds the terminal transient tray"
    Assert-True ($lastData -eq 'DB $0D,$0A,$00') "$Name script is not zero terminated"
    Assert-True ($tokens.FC -eq $ExpectedWaitTokens) "$Name has $($tokens.FC) reset-delay tokens; expected $ExpectedWaitTokens"
    Assert-True ($tokens.FD -eq 1) "$Name must contain one keyboard-test token"
    Assert-True ($tokens.FE -ge 1) "$Name must contain a reply-drain token"
    Assert-True ($tokens.FF -ge 1) "$Name must contain an interactive pause token"

    $result = "{0} OK range=7000-{1:X4} end={2:X4} fixups={3} line={4} waits={5}" -f $Name, ($end - 1), $end, $forwardBranches, $maxLine, $tokens.FC
    Write-Host $result
}

Test-TerminalExerciser -Path $Vt102Path -Name "VT102" -ExpectedEnd 0x79CE -ExpectedWaitTokens 2
Test-TerminalExerciser -Path $Vt525Path -Name "VT525" -ExpectedEnd 0x79B3 -ExpectedWaitTokens 3
