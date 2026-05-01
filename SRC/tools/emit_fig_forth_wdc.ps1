param(
    [string]$SourcePath = "../LOCAL/fig-forth/source/ff6502.html",
    [string]$OutPath = "../LOCAL/fig-forth/generated/fig-forth.asm"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Line {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Text = ""
    )
    [void]$Lines.Add($Text)
}

function Strip-Listing-Comment {
    param([string]$Text)

    $Text = Remove-Semicolon-Comment $Text
    $Text = $Text.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    if ($Text -match "^(\.BYTE|\.WORD)\s+(.+)$") {
        return $matches[1] + " " + (Get-First-Operand-Token $matches[2])
    }

    if ($Text -match "^([A-Za-z][A-Za-z0-9]*)\s*(.*)$") {
        $op = $matches[1]
        $rest = $matches[2].TrimStart()
        $noOperand = @(
            "BRK", "CLC", "CLD", "CLI", "CLV", "DEX", "DEY", "INX", "INY",
            "NOP", "PHA", "PHP", "PLA", "PLP", "RTI", "RTS", "SEC", "SED",
            "SEI", "TAX", "TAY", "TSX", "TXA", "TXS", "TYA"
        )
        if ($noOperand -contains $op.ToUpperInvariant() -or [string]::IsNullOrWhiteSpace($rest)) {
            return $op
        }
        return $op + " " + (Get-First-Operand-Token $rest)
    }

    return Get-First-Operand-Token $Text
}

function Remove-Semicolon-Comment {
    param([string]$Text)

    $quote = [char]0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if (($ch -eq "'" -or $ch -eq '"') -and $quote -eq [char]0) {
            $quote = $ch
        } elseif ($ch -eq $quote) {
            $quote = [char]0
        } elseif ($ch -eq ";" -and $quote -eq [char]0) {
            return $Text.Substring(0, $i)
        }
    }
    return $Text
}

function Get-First-Operand-Token {
    param([string]$Text)

    $Text = $Text.TrimStart()
    $quote = [char]0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if (($ch -eq "'" -or $ch -eq '"') -and $quote -eq [char]0) {
            $quote = $ch
        } elseif ($ch -eq $quote) {
            $quote = [char]0
        } elseif ([char]::IsWhiteSpace($ch) -and $quote -eq [char]0) {
            return $Text.Substring(0, $i).TrimEnd()
        }
    }
    return $Text.TrimEnd()
}

function Convert-Db-Quotes {
    param([string]$Text)

    return [regex]::Replace($Text, "'([^']*)'", {
        param($m)
        $value = $m.Groups[1].Value
        if ($value.Length -le 1) {
            return $m.Value
        }
        return '"' + $value.Replace('"', '""') + '"'
    })
}

function Mangle-Expression {
    param([string]$Text)

    $Text = $Text -replace "\bORIG\b", "FORTH_ORIG"
    $Text = $Text -replace "\bFORTH\+6\b", "RAM_FORTH_LINK"
    $Text = $Text -replace "\bFORTH\+7\b", "RAM_FORTH_LINK+1"
    return $Text
}

function Emit-Asm {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Label,
        [string]$Body
    )

    $Body = Strip-Listing-Comment $Body
    if ([string]::IsNullOrWhiteSpace($Body) -and [string]::IsNullOrWhiteSpace($Label)) {
        return
    }

    if ($Label -eq ".FILE") {
        return
    }

    if ([string]::IsNullOrWhiteSpace($Label) -and ($Body -eq "JSR TRACE" -or $Body -eq "JSR TCOLON")) {
        Add-Line $Lines "                        NOP"
        Add-Line $Lines "                        NOP"
        Add-Line $Lines "                        NOP"
        return
    }

    if ($Body -eq ".END FOR1/1") {
        if (-not [string]::IsNullOrWhiteSpace($Label)) {
            Add-Line $Lines ("{0}:" -f $Label)
        }
        return
    }

    if ($Body -eq "*=ORIG") {
        return
    }

    if ($Body -match "^\.FILE\b") {
        return
    }

    if ($Body -eq "*=*+2") {
        Add-Line $Lines '                        DB              $00,$00'
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($Label) -and $Body.StartsWith("=")) {
        if ($Label -eq "ORIG") {
            return
        }
        $expr = Get-First-Operand-Token (Remove-Semicolon-Comment $Body.Substring(1))
        $expr = Mangle-Expression $expr
        Add-Line $Lines ("{0,-26} EQU             {1}" -f $Label, $expr)
        return
    }

    $Body = $Body -replace "^\s*\.BYTE\b", "DB"
    $Body = $Body -replace "^\s*\.WORD\b", "DW"
    $Body = $Body -replace "#':", "#':'"
    $Body = Convert-Db-Quotes $Body
    $Body = Mangle-Expression $Body

    if ($Body -match "^DB\s+") {
        $Body = "DB              " + $Body.Substring(3).Trim()
    } elseif ($Body -match "^DW\s+") {
        $Body = "DW              " + $Body.Substring(3).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($Label)) {
        Add-Line $Lines ("                        {0}" -f $Body)
    } elseif ([string]::IsNullOrWhiteSpace($Body)) {
        Add-Line $Lines ("{0}:" -f $Label)
    } else {
        Add-Line $Lines ("{0,-23} {1}" -f ($Label + ":"), $Body)
    }
}

function Emit-Xemit {
    param([System.Collections.Generic.List[string]]$Lines)
    Add-Line $Lines "XEMIT:                  TYA"
    Add-Line $Lines "                        SEC"
    Add-Line $Lines '                        LDY             #$1A'
    Add-Line $Lines "                        ADC             (UP),Y"
    Add-Line $Lines "                        STA             (UP),Y"
    Add-Line $Lines "                        INY"
    Add-Line $Lines "                        LDA             #0"
    Add-Line $Lines "                        ADC             (UP),Y"
    Add-Line $Lines "                        STA             (UP),Y"
    Add-Line $Lines "                        LDA             0,X"
    Add-Line $Lines "                        STX             XSAVE"
    Add-Line $Lines "                        JSR             HIMONIA_ABI_WRITE_BYTE"
    Add-Line $Lines "                        LDX             XSAVE"
    Add-Line $Lines "                        JMP             POP"
    Add-Line $Lines
}

function Emit-Xkey {
    param([System.Collections.Generic.List[string]]$Lines)
    Add-Line $Lines "XKEY:                   STX             XSAVE"
    Add-Line $Lines "                        JSR             HIMONIA_ABI_READ_BYTE"
    Add-Line $Lines "                        LDX             XSAVE"
    Add-Line $Lines "                        JMP             PUSH0A"
    Add-Line $Lines
}

function Emit-Xqter {
    param([System.Collections.Generic.List[string]]$Lines)
    Add-Line $Lines "XQTER:                  LDA             #0"
    Add-Line $Lines "                        JMP             PUSH0A"
    Add-Line $Lines
}

function Emit-Xcr {
    param([System.Collections.Generic.List[string]]$Lines)
    Add-Line $Lines "XCR:                    STX             XSAVE"
    Add-Line $Lines '                        LDA             #$0D'
    Add-Line $Lines "                        JSR             HIMONIA_ABI_WRITE_BYTE"
    Add-Line $Lines '                        LDA             #$0A'
    Add-Line $Lines "                        JSR             HIMONIA_ABI_WRITE_BYTE"
    Add-Line $Lines "                        LDX             XSAVE"
    Add-Line $Lines "                        JMP             NEXT"
    Add-Line $Lines
}

function Emit-Rslw {
    param([System.Collections.Generic.List[string]]$Lines)
    Add-Line $Lines "RSLW:                   DW              DOCOL"
    Add-Line $Lines "                        DW              ONE,CLIT"
    Add-Line $Lines '                        DB              $08'
    Add-Line $Lines "                        DW              QERR,SEMIS"
    Add-Line $Lines
}

function Emit-Mon {
    param([System.Collections.Generic.List[string]]$Lines)
    Add-Line $Lines "MON:                    DW              *+2"
    Add-Line $Lines "                        STX             XSAVE"
    Add-Line $Lines "                        JMP             HIMONIA_ABI_EXIT_APP"
    Add-Line $Lines
}

$html = [System.IO.File]::ReadAllText($SourcePath)
$html = [System.Net.WebUtility]::HtmlDecode($html)
$match = [regex]::Match($html, "<pre>(.*?)</pre>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $match.Success) {
    throw "Could not find listing <pre> in $SourcePath"
}

$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines "; ----------------------------------------------------------------------------"
Add-Line $lines "; fig-forth.asm"
Add-Line $lines "; FIG-Forth 6502 Release 1.1 adapted for Himonia-F flash command dispatch."
Add-Line $lines ("; Generated by tools/emit_fig_forth_wdc.ps1 from {0}." -f $SourcePath)
Add-Line $lines ";"
Add-Line $lines "; Public domain notice from the source:"
Add-Line $lines "; This public domain publication is provided through the courtesy"
Add-Line $lines "; of Forth Interest Group, P.O. Box 1105, San Carlos, CA 94070."
Add-Line $lines "; Further distribution must include this notice."
Add-Line $lines "; ----------------------------------------------------------------------------"
Add-Line $lines
Add-Line $lines "                        MODULE          FIG_FORTH_APP"
Add-Line $lines
Add-Line $lines "                        XDEF            START"
Add-Line $lines
$skipUntil = $null
$startedCode = $false
$insertedRamVoc = $false

foreach ($raw in ($match.Groups[1].Value -split "`r?`n")) {
    $m = [regex]::Match($raw, "^(\d{4})\s+[0-9A-F]{4}\s+")
    if (-not $m.Success) {
        continue
    }

    $lineNo = [int]$m.Groups[1].Value
    if ($raw.Length -lt 23) {
        continue
    }

    $source = $raw.Substring(22).TrimEnd()
    if ([string]::IsNullOrWhiteSpace($source) -or $source.TrimStart().StartsWith(";")) {
        continue
    }

    $label = ""
    if ($raw.Length -gt 22) {
        $labelLen = [Math]::Min(7, $raw.Length - 22)
        $label = $raw.Substring(22, $labelLen).Trim()
    }

    $body = ""
    if ($raw.Length -gt 29) {
        $body = $raw.Substring(29).TrimEnd()
    } elseif ($raw.Length -gt 22) {
        $body = $raw.Substring(22).TrimEnd()
    }

    if ($skipUntil) {
        if ($label -eq $skipUntil) {
            $skipUntil = $null
        } else {
            continue
        }
    }

    if ($label -eq "ENTER" -and -not $startedCode) {
        Add-Line $lines
        Add-Line $lines 'RAM_DICT                 EQU             $0300'
        Add-Line $lines "RAM_FORTH_LINK           EQU             UAREA-2"
        Add-Line $lines 'HIMONIA_ABI_WRITE_BYTE   EQU             $F00D'
        Add-Line $lines 'HIMONIA_ABI_READ_BYTE    EQU             $FEED'
        Add-Line $lines 'HIMONIA_ABI_EXIT_APP     EQU             $FADE'
        Add-Line $lines
        Add-Line $lines "                        CODE"
        Add-Line $lines
        Add-Line $lines "FIG_FORTH_FNV:"
        Add-Line $lines "                        DB              'F','N',('V'+`$80),`$2C,`$BE,`$EC,`$1C,`$00"
        Add-Line $lines "START:"
        Add-Line $lines "FORTH_ORIG:"
        $startedCode = $true
    }

    if ($label -eq "XEMIT") {
        Emit-Xemit $lines
        $skipUntil = "XKEY"
        continue
    }
    if ($label -eq "XKEY") {
        Emit-Xkey $lines
        $skipUntil = "XQTER"
        continue
    }
    if ($label -eq "XQTER") {
        Emit-Xqter $lines
        $skipUntil = "XCR"
        continue
    }
    if ($label -eq "XCR") {
        Emit-Xcr $lines
        $skipUntil = "L3030"
        continue
    }
    if ($label -eq "RSLW") {
        Emit-Rslw $lines
        $skipUntil = "L3202"
        continue
    }
    if ($label -eq "MON") {
        Emit-Mon $lines
        $skipUntil = "TOP"
        continue
    }

    if ($lineNo -eq 50) {
        $body = '=$7800'
    } elseif ($lineNo -eq 84 -or $lineNo -eq 85) {
        $body = ".WORD RAM_DICT"
    } elseif ($lineNo -eq 2574) {
        $body = ".WORD DOVOC_RAM"
    }

    Emit-Asm $lines $label $body

    if ($lineNo -eq 2566 -and -not $insertedRamVoc) {
        Add-Line $lines
        Add-Line $lines "DOVOC_RAM:              DW              DROP"
        Add-Line $lines "                        DW              LIT,RAM_FORTH_LINK"
        Add-Line $lines "                        DW              CON,STORE,SEMIS"
        Add-Line $lines
        $insertedRamVoc = $true
    }
}

Add-Line $lines
Add-Line $lines "                        END"

$outDir = Split-Path -Parent $OutPath
if ($outDir) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
[System.IO.File]::WriteAllLines($OutPath, $lines)
Write-Host ("Wrote {0} lines to {1}" -f $lines.Count, $OutPath)
