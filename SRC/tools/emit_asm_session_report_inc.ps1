param(
    [Parameter(Mandatory=$true)][string]$MapPath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [string]$AsmNativeFlashOut,
    [string]$AsmNativeRuntimeOut
)

$required = @(
    '_END_DATA',
    '_BEG_UDATA',
    '_END_UDATA',
    'ASM_WORKSPACE_END',
    'ASM_LOW_SYM_NAMES',
    'ASM_LOW_FIX_NAMES',
    'ASM_LOW_TABLE_END',
    'ASM_TARGET_LIMIT_HI',
    'ASM_PACKAGE_MAX_HI',
    'ASM_SESSION_STATE',
    'ASM_LAST_STATUS',
    'ASM_LINE_COUNT_LO',
    'ASM_LINE_COUNT_HI',
    'ASM_PC_LO',
    'ASM_PC_HI',
    'ASM_START_PC_LO',
    'ASM_START_PC_HI',
    'ASM_HIGH_PC_LO',
    'ASM_HIGH_PC_HI',
    'ASM_SEAL_FLAGS',
    'ASM_SEAL_BASE_LO',
    'ASM_SEAL_BASE_HI',
    'ASM_SEAL_END_LO',
    'ASM_SEAL_END_HI',
    'ASM_SEAL_LEN_LO',
    'ASM_SEAL_LEN_HI',
    'ASM_SEAL_FNV0',
    'ASM_SEAL_FNV1',
    'ASM_SEAL_FNV2',
    'ASM_SEAL_FNV3',
    'ASM_RELOC_COUNT',
    'ASM_RELOC_KIND',
    'ASM_RELOC_SITE_LO',
    'ASM_RELOC_SITE_HI',
    'ASM_RELOC_TARGET_LO',
    'ASM_RELOC_TARGET_HI',
    'ASM_EXPORT_REC_COUNT',
    'ASM_EXPORT_REC_LEN',
    'ASM_IMPORT_REC_COUNT',
    'ASM_IMPORT_REC_LEN',
    'ASM_IMPORT_RESOLVE_COUNT',
    'ASM_RELOCATE_BASE_LO',
    'ASM_RELOCATE_BASE_HI',
    'ASM_RELOCATE_COUNT',
    'ASM_PACKAGE_BASE_LO',
    'ASM_PACKAGE_BASE_HI',
    'ASM_PACKAGE_LEN_LO',
    'ASM_PACKAGE_LEN_HI',
    'ASM_PACKAGE_BODY_LEN_LO',
    'ASM_PACKAGE_BODY_LEN_HI',
    'ASM_INSTALL_BASE_LO',
    'ASM_INSTALL_BASE_HI',
    'ASM_REF_COUNT',
    'ASM_REPORT_FLAGS',
    'ASM_REPORTF_TRUNC',
    'ASM_SYMF_USED',
    'ASM_SYM_MAX',
    'ASM_FIX_MAX',
    'ASM_REF_MAX',
    'ASM_SYM_COUNT',
    'ASM_FIX_COUNT',
    'ASM_SYM_STATE',
    'ASM_SYM_FLAGS',
    'ASM_SYM_KIND',
    'ASM_SYM_WIDTH',
    'ASM_SYM_VAL_LO',
    'ASM_SYM_VAL_HI',
    'ASM_SYM_DEFLINE_LO',
    'ASM_SYM_DEFLINE_HI',
    'ASM_SYM_USECNT',
    'ASM_SYM_FIRSTREF_LO',
    'ASM_SYM_FIRSTREF_HI',
    'ASM_SYM_NAMES',
    'ASM_FIX_STATE',
    'ASM_FIX_MODE',
    'ASM_FIX_SEL',
    'ASM_FIX_SITE_LO',
    'ASM_FIX_SITE_HI',
    'ASM_FIX_BASE_LO',
    'ASM_FIX_BASE_HI',
    'ASM_FIX_NAME_TEXT',
    'ASM_RJ_WRITE_BYTE',
    'ASM_RJ_WRITE_CSTRING',
    'ASM_RJ_WRITE_HEX_BYTE',
    'ASM_RJ_WRITE_HEX_WORD_AX',
    'ASM_RJ_PRINT_CRLF'
)

if (-not (Test-Path -LiteralPath $MapPath)) {
    throw "Map not found: $MapPath"
}

$symbols = @{}
foreach ($line in Get-Content -LiteralPath $MapPath) {
    if ($line -match '^\s*([0-9A-Fa-f]{8})\s+([A-Za-z_][A-Za-z0-9_]*)\s*$') {
        $symbols[$matches[2]] = $matches[1].Substring(4).ToUpperInvariant()
    }
}

function Get-SymbolHex([string]$Name) {
    if (-not $symbols.ContainsKey($Name)) {
        throw "Required symbol missing from map: $Name"
    }
    $symbols[$Name]
}

function Get-Addr([string]$Name) {
    '$' + (Get-SymbolHex $Name)
}

function Get-AddrHi([string]$Name) {
    '$' + (Get-SymbolHex $Name).Substring(0, 2)
}

function Get-AddrLo([string]$Name) {
    '$' + (Get-SymbolHex $Name).Substring(2, 2)
}

function Write-AsciiLines([string]$Path, [string[]]$Lines) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Lines -Encoding ASCII
}

function Format-HexByte([int]$Value) {
    '$' + (($Value -band 0xff).ToString('X2'))
}

function Format-HexWord([int]$Value) {
    '$' + (($Value -band 0xffff).ToString('X4'))
}

function Test-AsmNativeMnemonic([string]$Token) {
    $t = $Token.ToUpperInvariant()
    return @(
        'ADC','AND','BEQ','BNE','BCC','BCS','BRA','CLC','CMP','CPX',
        'DEC','DEX','INC','INX','INY','JMP','JSR','LDA','LDX','LDY',
        'ORA','RTS','SBC','SEC','STA','STX','STZ','TXA',
        'DB','END','ENTRY','ORG'
    ) -contains $t
}

function Get-AsmNumberValue([string]$Text) {
    $t = $Text.Trim()
    if ($t -match '^\$([0-9A-Fa-f]{1,4})$') {
        return [Convert]::ToInt32($matches[1], 16)
    }
    if ($t -match '^[0-9]+$') {
        return [Convert]::ToInt32($t, 10)
    }
    return $null
}

function Get-AsmNativeLineSize([string]$Line) {
    $s = $Line.Trim()
    if ($s.Length -eq 0 -or $s.StartsWith(';')) {
        return 0
    }

    $parts = $s -split '\s+', 2
    $first = $parts[0].ToUpperInvariant()
    if (-not (Test-AsmNativeMnemonic $first)) {
        if ($parts.Count -lt 2) {
            return 0
        }
        $s = $parts[1].Trim()
        $parts = $s -split '\s+', 2
        $first = $parts[0].ToUpperInvariant()
    }

    $op = ''
    if ($parts.Count -gt 1) {
        $op = $parts[1].Trim()
    }

    if ($first -eq 'ORG' -or $first -eq 'END' -or $first -eq 'ENTRY') {
        return 0
    }
    if ($first -eq 'DB') {
        if ($op.Length -eq 0) {
            return 0
        }
        return (($op -split ',').Count)
    }

    if (@('RTS','CLC','SEC','INX','DEX','INY','TXA') -contains $first) {
        return 1
    }
    if (@('BEQ','BNE','BCC','BCS','BRA') -contains $first) {
        return 2
    }
    if (@('JSR','JMP') -contains $first) {
        return 3
    }
    if ($op.StartsWith('#')) {
        return 2
    }
    if ($op -match '^\(.+\),Y$') {
        return 2
    }

    $base = ($op -replace ',[XY]$','').Trim()
    $value = Get-AsmNumberValue $base
    if ($null -ne $value -and $value -lt 0x100) {
        return 2
    }
    return 3
}

function Get-AsmNativeLabelAddresses([string[]]$Lines, [string]$Org) {
    $pc = [Convert]::ToInt32($Org, 16)
    $labels = @{}
    foreach ($line in $Lines) {
        $s = $line.Trim()
        if ($s.Length -ne 0 -and -not $s.StartsWith(';')) {
            $parts = $s -split '\s+', 2
            $first = $parts[0].TrimEnd(':')
            if ($parts.Count -gt 1 -and -not (Test-AsmNativeMnemonic $first)) {
                $labels[$first.ToUpperInvariant()] = $pc
            }
        }
        $pc += Get-AsmNativeLineSize $line
    }
    return $labels
}

function Convert-AsmNativeInternalCallTargets([string]$Line, [hashtable]$Labels) {
    if ($Line -match '^(?<pre>\s*(?:(?:[A-Za-z_][A-Za-z0-9_]*:?)\s+)?(?:JSR|JMP)\s+)(?<target>[A-Za-z_][A-Za-z0-9_]*)\s*$') {
        $target = $matches['target'].ToUpperInvariant()
        if ($Labels.ContainsKey($target)) {
            return $matches['pre'] + (Format-HexWord $Labels[$target])
        }
    }
    return $Line
}

function ConvertTo-DbCharAtom([int]$Code) {
    if ($Code -ge 0x20 -and $Code -le 0x7e -and $Code -ne 0x27) {
        return "'" + [char]$Code + "'"
    }
    return Format-HexByte $Code
}

function ConvertTo-DbCharLines([string]$Text) {
    $atoms = @()
    foreach ($ch in $Text.ToCharArray()) {
        $atoms += ConvertTo-DbCharAtom ([int][char]$ch)
    }
    $atoms += '$00'

    $lines = @()
    for ($i = 0; $i -lt $atoms.Count; $i += 12) {
        $end = [Math]::Min($i + 11, $atoms.Count - 1)
        $lines += ('        DB ' + (($atoms[$i..$end]) -join ','))
    }
    return $lines
}

function ConvertTo-CompactAsmNativeReport([string[]]$Native, [string]$Org) {
    $messages = [ordered]@{}
    $msgStart = -1
    for ($i = 0; $i -lt $Native.Count; $i++) {
        if ($Native[$i] -match '^(M[0-9]+)\s+DB\s+"([^"]*)",0$') {
            if ($msgStart -lt 0) {
                $msgStart = $i
            }
            $messages[$matches[1]] = $matches[2]
        }
    }
    if ($msgStart -lt 0) {
        return $Native
    }

    $prefix = @()
    if ($msgStart -gt 0) {
        $prefix = $Native[0..($msgStart - 1)]
    }

    $labelAddrs = Get-AsmNativeLabelAddresses -Lines $prefix -Org $Org

    $pc = [Convert]::ToInt32($Org, 16)
    foreach ($line in $prefix) {
        $pc += Get-AsmNativeLineSize $line
    }

    $addrs = @{}
    foreach ($name in $messages.Keys) {
        $addrs[$name] = $pc
        $pc += $messages[$name].Length + 1
    }

    $orderedNames = @($messages.Keys) | Sort-Object @{Expression={$_.Length};Descending=$true}, @{Expression={$_};Descending=$false}
    $resolved = @()
    foreach ($line in $prefix) {
        $out = $line
        foreach ($name in $orderedNames) {
            $addr = $addrs[$name]
            $out = $out.Replace("#<$name", ('#' + (Format-HexByte $addr)))
            $out = $out.Replace("#>$name", ('#' + (Format-HexByte ($addr -shr 8))))
        }
        $out = Convert-AsmNativeInternalCallTargets -Line $out -Labels $labelAddrs
        $resolved += $out
    }

    $resolved += '; MESSAGE TEXT USES LITERAL ADDRESSES TO SAVE SYMBOLS.'
    foreach ($name in $messages.Keys) {
        $resolved += ('; {0} {1}' -f $name, (Format-HexWord $addrs[$name]))
        $resolved += ConvertTo-DbCharLines $messages[$name]
    }
    $resolved += ''
    $resolved += '; FIXED-ADDRESS AP ENTRY; LOAD/RUN AT THE SAME ORG.'
    $resolved += '        ENTRY START'
    $resolved += '        END'
    return $resolved
}

$lines = @(
    '; -------------------------------------------------------------------------',
    '; asm-session-report.inc',
    '; AUTO-GENERATED by tools/emit_asm_session_report_inc.ps1.',
    ('; Source map: {0}' -f $MapPath),
    '; -------------------------------------------------------------------------',
    ''
)

foreach ($name in $required) {
    $lines += ('{0,-24} EQU             ${1}' -f $name, (Get-SymbolHex $name))
}

$lines += @(
    '',
    'ASM_REPORT_SYM_NAME_MAX EQU         $20',
    'ASM_REPORT_FIX_NAME_MAX EQU         $20'
)

Write-AsciiLines -Path $OutPath -Lines $lines

function New-AsmNativeReport([string]$OutFile, [string]$Org, [string[]]$Header) {
    $char = Get-Addr 'ASM_RJ_WRITE_BYTE'
    $cstr = Get-Addr 'ASM_RJ_WRITE_CSTRING'
    $hexb = Get-Addr 'ASM_RJ_WRITE_HEX_BYTE'
    $hexw = Get-Addr 'ASM_RJ_WRITE_HEX_WORD_AX'
    $crlf = Get-Addr 'ASM_RJ_PRINT_CRLF'

    $native = @()
    $native += $Header
    $native += @(
        '; AUTO-GENERATED by tools/emit_asm_session_report_inc.ps1.',
        ('; Source map: {0}' -f $MapPath),
        ('; LOW TABLES {0}-{1}; UDATA {2}-{3}; flash DATA end {4}.' -f (Get-Addr 'ASM_LOW_SYM_NAMES'), (Get-Addr 'ASM_LOW_TABLE_END'), (Get-Addr '_BEG_UDATA'), (Get-Addr '_END_UDATA'), (Get-Addr '_END_DATA')),
        '',
        ('        ORG ${0}' -f $Org),
        '',
        '; ZP: $00/$01 PTR, $02 SLOT, $03 COUNT, $04 TMP.',
        ('; FLASH ASM OUTPUT HELPERS: {0} BYTE, {1} CSTR, {2} HEXB,' -f $char, $cstr, $hexb),
        ('; {0} HEXW AX, {1} CRLF.' -f $hexw, $crlf),
        '',
        'START   JMP MAIN',
        '',
        ('PRC     JMP {0}' -f $cstr),
        '',
        'PL      JSR PRC',
        ('        JMP {0}' -f $crlf),
        '',
        ('PBF     JSR {0}' -f $hexb),
        "SP      LDA #' '",
        ('        JMP {0}' -f $char),
        '',
        ('PWF     JSR {0}' -f $hexw),
        '        BRA SP',
        '',
        ('PW      JMP {0}' -f $hexw),
        '',
        "PLIM    LDA #'/'",
        ('        JSR {0}' -f $char),
        "        LDA #'$'",
        ('        JMP {0}' -f $char),
        '',
        'PPL     LDX $00',
        '        LDY $01',
        ('        JSR {0}' -f $cstr),
        ('        JMP {0}' -f $crlf),
        '',
        'SSYM    STX $03',
        ('        LDA #{0}' -f (Get-AddrLo 'ASM_SYM_NAMES')),
        '        STA $00',
        ('        LDA #{0}' -f (Get-AddrHi 'ASM_SYM_NAMES')),
        '        STA $01',
        '        LDX $03',
        '        BRA SADD',
        '',
        'SFIX    STX $03',
        ('        LDA #{0}' -f (Get-AddrLo 'ASM_FIX_NAME_TEXT')),
        '        STA $00',
        ('        LDA #{0}' -f (Get-AddrHi 'ASM_FIX_NAME_TEXT')),
        '        STA $01',
        '        LDX $03',
        'SADD    BEQ SADDD',
        'SADDL   CLC',
        '        LDA $00',
        '        ADC #$20',
        '        STA $00',
        '        LDA $01',
        '        ADC #$00',
        '        STA $01',
        '        DEX',
        '        BNE SADDL',
        'SADDD   RTS',
        '',
        'MAIN    LDX #<M0',
        '        LDY #>M0',
        '        JSR PL',
        '        JSR PCMP',
        '        JSR PMAP',
        '        JSR PSES',
        '        JSR PUSED',
        '        JSR PUNUS',
        '        JSR PSYM',
        '        JSR PFIX',
        '        JSR PREL',
        '        LDX #<M15',
        '        LDY #>M15',
        '        JSR PL',
        ('        LDA {0}' -f (Get-Addr 'ASM_LAST_STATUS')),
        '        BEQ MAINOK',
        '        CLC',
        '        RTS',
        'MAINOK  SEC',
        '        RTS',
        '',
        'PCMP    JSR PSTAT',
        '        JSR PERRL',
        '        JSR PSTRT',
        '        JSR PPC',
        '        JSR PHIGH',
        '        JSR PBYTS',
        '        JSR PLINS',
        '        JSR PSYMC',
        '        JSR PFIXC',
        '        JSR PREFC',
        '        JMP PTRNC',
        '',
        'PSTAT   LDX #<M16',
        '        LDY #>M16',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_LAST_STATUS')),
        '        BEQ PSTOK',
        "        LDA #'$'",
        ('        JSR {0}' -f $char),
        ('        LDA {0}' -f (Get-Addr 'ASM_LAST_STATUS')),
        ('        JSR {0}' -f $hexb),
        ('        JMP {0}' -f $crlf),
        'PSTOK   LDX #<M17',
        '        LDY #>M17',
        '        JMP PL',
        '',
        'PERRL   LDX #<M18',
        '        LDY #>M18',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_LAST_STATUS')),
        '        BEQ PERR0',
        ('        LDA {0}' -f (Get-Addr 'ASM_LINE_COUNT_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_LINE_COUNT_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        'PERR0   LDA #$00',
        '        LDX #$00',
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PSTRT   LDX #<M19',
        '        LDY #>M19',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_START_PC_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_START_PC_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PPC     LDX #<M20',
        '        LDY #>M20',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_PC_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_PC_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PHIGH   LDX #<M21',
        '        LDY #>M21',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_HIGH_PC_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_HIGH_PC_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PBYTS   LDX #<M22',
        '        LDY #>M22',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_HIGH_PC_LO')),
        '        SEC',
        ('        SBC {0}' -f (Get-Addr 'ASM_START_PC_LO')),
        '        STA $04',
        ('        LDA {0}' -f (Get-Addr 'ASM_HIGH_PC_HI')),
        ('        SBC {0}' -f (Get-Addr 'ASM_START_PC_HI')),
        '        LDX $04',
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PLINS   LDX #<M23',
        '        LDY #>M23',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_LINE_COUNT_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_LINE_COUNT_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PSYMC   LDX #<M24',
        '        LDY #>M24',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        ('        JSR {0}' -f $hexb),
        '        JSR PLIM',
        ('        LDA #{0}' -f (Get-AddrLo 'ASM_SYM_MAX')),
        ('        JSR {0}' -f $hexb),
        ('        JMP {0}' -f $crlf),
        '',
        'PFIXC   LDX #<M25',
        '        LDY #>M25',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_FIX_COUNT')),
        ('        JSR {0}' -f $hexb),
        '        JSR PLIM',
        ('        LDA #{0}' -f (Get-AddrLo 'ASM_FIX_MAX')),
        ('        JSR {0}' -f $hexb),
        ('        JMP {0}' -f $crlf),
        '',
        'PREFC   LDX #<M26',
        '        LDY #>M26',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_REF_COUNT')),
        ('        JSR {0}' -f $hexb),
        '        JSR PLIM',
        ('        LDA #{0}' -f (Get-AddrLo 'ASM_REF_MAX')),
        ('        JSR {0}' -f $hexb),
        ('        JMP {0}' -f $crlf),
        '',
        ('PTRNC   LDA {0}' -f (Get-Addr 'ASM_REPORT_FLAGS')),
        ('        AND #{0}' -f (Get-AddrLo 'ASM_REPORTF_TRUNC')),
        '        BEQ PTRN0',
        '        LDX #<M27',
        '        LDY #>M27',
        '        JMP PL',
        'PTRN0   LDX #<M28',
        '        LDY #>M28',
        '        JMP PL',
        '',
        'PMAP    LDX #<M1',
        '        LDY #>M1',
        '        JSR PRC',
        ('        LDA #{0}' -f (Get-AddrHi '_END_DATA')),
        ('        LDX #{0}' -f (Get-AddrLo '_END_DATA')),
        '        JSR PW',
        '        LDX #<M2',
        '        LDY #>M2',
        '        JSR PRC',
        ('        LDA #{0}' -f (Get-AddrHi '_BEG_UDATA')),
        ('        LDX #{0}' -f (Get-AddrLo '_BEG_UDATA')),
        '        JSR PW',
        "        LDA #'-'",
        ('        JSR {0}' -f $char),
        ('        LDA #{0}' -f (Get-AddrHi '_END_UDATA')),
        ('        LDX #{0}' -f (Get-AddrLo '_END_UDATA')),
        '        JSR PW',
        ('        JSR {0}' -f $crlf),
        '        LDX #<M34',
        '        LDY #>M34',
        '        JSR PRC',
        ('        LDA #{0}' -f (Get-AddrHi 'ASM_LOW_SYM_NAMES')),
        ('        LDX #{0}' -f (Get-AddrLo 'ASM_LOW_SYM_NAMES')),
        '        JSR PW',
        "        LDA #'-'",
        ('        JSR {0}' -f $char),
        ('        LDA #{0}' -f (Get-AddrHi 'ASM_LOW_TABLE_END')),
        ('        LDX #{0}' -f (Get-AddrLo 'ASM_LOW_TABLE_END')),
        '        JSR PW',
        '        LDX #<M35',
        '        LDY #>M35',
        '        JSR PRC',
        ('        LDA #{0}' -f (Get-AddrHi 'ASM_WORKSPACE_END')),
        ('        LDX #{0}' -f (Get-AddrLo 'ASM_WORKSPACE_END')),
        '        JSR PW',
        "        LDA #'-'",
        ('        JSR {0}' -f $char),
        ('        LDA #{0}' -f (Get-AddrLo 'ASM_TARGET_LIMIT_HI')),
        '        LDX #$00',
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PSES    LDX #<M3',
        '        LDY #>M3',
        '        JSR PL',
        '        LDX #<M4',
        '        LDY #>M4',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_SESSION_STATE')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_LAST_STATUS')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_LINE_COUNT_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_LINE_COUNT_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_START_PC_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_START_PC_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_PC_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_PC_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_HIGH_PC_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_HIGH_PC_LO')),
        '        JSR PW',
        ('        JSR {0}' -f $crlf),
        '        LDX #<M5',
        '        LDY #>M5',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_SEAL_FLAGS')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_SEAL_BASE_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_SEAL_BASE_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_SEAL_END_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_SEAL_END_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_SEAL_LEN_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_SEAL_LEN_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_SEAL_FNV3')),
        ('        LDX {0}' -f (Get-Addr 'ASM_SEAL_FNV2')),
        '        JSR PW',
        ('        LDA {0}' -f (Get-Addr 'ASM_SEAL_FNV1')),
        ('        LDX {0}' -f (Get-Addr 'ASM_SEAL_FNV0')),
        '        JSR PW',
        ('        JSR {0}' -f $crlf),
        '        LDX #<M6',
        '        LDY #>M6',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_FIX_COUNT')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_RELOC_COUNT')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_EXPORT_REC_COUNT')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_IMPORT_REC_COUNT')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_IMPORT_RESOLVE_COUNT')),
        '        JSR PBF',
        ('        LDA {0}' -f (Get-Addr 'ASM_RELOCATE_COUNT')),
        '        JSR PBF',
        ('        JSR {0}' -f $crlf),
        '        LDX #<M13',
        '        LDY #>M13',
        '        JSR PRC',
        ('        LDA {0}' -f (Get-Addr 'ASM_PACKAGE_BASE_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_PACKAGE_BASE_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_PACKAGE_LEN_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_PACKAGE_LEN_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_PACKAGE_BODY_LEN_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_PACKAGE_BODY_LEN_LO')),
        '        JSR PWF',
        ('        LDA {0}' -f (Get-Addr 'ASM_INSTALL_BASE_HI')),
        ('        LDX {0}' -f (Get-Addr 'ASM_INSTALL_BASE_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PUSED   LDX #$00',
        ('PUSHL   CPX {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        '        BEQ PUSEDN',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_FLAGS')),
        ('        AND #{0}' -f (Get-AddrLo 'ASM_SYMF_USED')),
        '        BNE PUSEDY',
        '        INX',
        '        BRA PUSHL',
        'PUSEDN  RTS',
        'PUSEDY  LDX #<M29',
        '        LDY #>M29',
        '        JSR PL',
        '        LDX #$00',
        ('PUSL    CPX {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        '        BEQ PUSEDN',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_FLAGS')),
        ('        AND #{0}' -f (Get-AddrLo 'ASM_SYMF_USED')),
        '        BEQ PUSNX',
        '        JSR PUSR',
        '        LDX $02',
        'PUSNX   INX',
        '        BRA PUSL',
        '',
        'PUSR    STX $02',
        '        JSR PNM',
        '        JSR PDEF',
        '        LDX #<M32',
        '        LDY #>M32',
        '        JSR PRC',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_USECNT')),
        ('        JSR {0}' -f $hexb),
        '        LDX #<M33',
        '        LDY #>M33',
        '        JSR PRC',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_SYM_FIRSTREF_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_SYM_FIRSTREF_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'PUNUS   LDX #$00',
        ('PUNHL   CPX {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        '        BEQ PUNUSD',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_FLAGS')),
        ('        AND #{0}' -f (Get-AddrLo 'ASM_SYMF_USED')),
        '        BEQ PUNUSY',
        '        INX',
        '        BRA PUNHL',
        'PUNUSD  RTS',
        'PUNUSY  LDX #<M30',
        '        LDY #>M30',
        '        JSR PL',
        '        LDX #$00',
        ('PUNL    CPX {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        '        BEQ PUNUSD',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_FLAGS')),
        ('        AND #{0}' -f (Get-AddrLo 'ASM_SYMF_USED')),
        '        BNE PUNNX',
        '        JSR PUNR',
        '        LDX $02',
        'PUNNX   INX',
        '        BRA PUNL',
        '',
        'PUNR    STX $02',
        '        JSR PNM',
        '        JSR PDEF',
        ('        JMP {0}' -f $crlf),
        '',
        'PNM     JSR SSYM',
        '        LDX $00',
        '        LDY $01',
        ('        JSR {0}' -f $cstr),
        '        JMP SP',
        '',
        'PDEF    LDX #<M31',
        '        LDY #>M31',
        '        JSR PRC',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_SYM_DEFLINE_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_SYM_DEFLINE_LO')),
        '        JMP PW',
        '',
        'PSYM    LDX #<M7',
        '        LDY #>M7',
        '        JSR PL',
        '        LDX #<M8',
        '        LDY #>M8',
        '        JSR PL',
        '        LDX #$00',
        ('PSYML   CPX {0}' -f (Get-Addr 'ASM_SYM_COUNT')),
        '        BEQ PSYMD',
        '        JSR PSYMR',
        '        LDX $02',
        '        INX',
        '        BRA PSYML',
        'PSYMD   RTS',
        '',
        'PSYMR   STX $02',
        '        TXA',
        '        JSR PBF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_STATE')),
        '        JSR PBF',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_SYM_VAL_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_SYM_VAL_LO')),
        '        JSR PWF',
        '        JSR SP',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_KIND')),
        '        JSR PBF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_WIDTH')),
        '        JSR PBF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_FLAGS')),
        '        JSR PBF',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_SYM_DEFLINE_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_SYM_DEFLINE_LO')),
        '        JSR PWF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_SYM_USECNT')),
        '        JSR PBF',
        '        JSR SP',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_SYM_FIRSTREF_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_SYM_FIRSTREF_LO')),
        '        JSR PWF',
        '        JSR SP',
        '        LDX $02',
        '        JSR SSYM',
        '        JMP PPL',
        '',
        'PFIX    LDX #<M9',
        '        LDY #>M9',
        '        JSR PL',
        '        LDX #<M10',
        '        LDY #>M10',
        '        JSR PL',
        '        LDX #$00',
        ('PFIXL   CPX {0}' -f (Get-Addr 'ASM_FIX_COUNT')),
        '        BEQ PFIXD',
        '        JSR PFIXR',
        '        LDX $02',
        '        INX',
        '        BRA PFIXL',
        'PFIXD   RTS',
        '',
        'PFIXR   STX $02',
        '        TXA',
        '        JSR PBF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_FIX_STATE')),
        '        JSR PBF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_FIX_MODE')),
        '        JSR PBF',
        '        JSR SP',
        '        JSR SP',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_FIX_SEL')),
        '        JSR PBF',
        '        JSR SP',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_FIX_SITE_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_FIX_SITE_LO')),
        '        JSR PWF',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_FIX_BASE_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_FIX_BASE_LO')),
        '        JSR PWF',
        '        LDX $02',
        '        JSR SFIX',
        '        JMP PPL',
        '',
        'PREL    LDX #<M11',
        '        LDY #>M11',
        '        JSR PL',
        '        LDX #<M12',
        '        LDY #>M12',
        '        JSR PL',
        '        LDX #$00',
        ('PRELL   CPX {0}' -f (Get-Addr 'ASM_RELOC_COUNT')),
        '        BEQ PRELD',
        '        JSR PRELR',
        '        LDX $02',
        '        INX',
        '        BRA PRELL',
        'PRELD   RTS',
        '',
        'PRELR   STX $02',
        '        TXA',
        '        JSR PBF',
        '        LDX $02',
        ('        LDA {0},X' -f (Get-Addr 'ASM_RELOC_KIND')),
        '        JSR PBF',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_RELOC_SITE_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_RELOC_SITE_LO')),
        '        JSR PWF',
        '        LDY $02',
        ('        LDA {0},Y' -f (Get-Addr 'ASM_RELOC_TARGET_HI')),
        ('        LDX {0},Y' -f (Get-Addr 'ASM_RELOC_TARGET_LO')),
        '        JSR PW',
        ('        JMP {0}' -f $crlf),
        '',
        'M0      DB "ASM REPORT",0',
        'M1      DB "MAP END=$",0',
        'M2      DB " UDATA=$",0',
        'M3      DB "SESSION",0',
        'M4      DB "ST LAST LINES START PC HIGH ",0',
        'M5      DB "SEAL FL BASE END LEN FNV ",0',
        'M6      DB "COUNTS SYM FIX REL EXP IMP IMPRES RELCNT ",0',
        'M7      DB "SYMBOLS",0',
        'M8      DB "SL ST VALUE K  W  FL DEF  USE FIRST NAME",0',
        'M9      DB "FIXUPS",0',
        'M10     DB "SL ST MODE SEL SITE BASE NAME",0',
        'M11     DB "RELOCS",0',
        'M12     DB "SL K  SITE TARG",0',
        'M13     DB "PKG @ LEN BODY INST ",0',
        'M15     DB "ASM REPORT OK",0',
        'M16     DB "STATUS=",0',
        'M17     DB "OK",0',
        'M18     DB "ERRLINE=$",0',
        'M19     DB "START=$",0',
        'M20     DB "PC=$",0',
        'M21     DB "HIGH=$",0',
        'M22     DB "BYTES=$",0',
        'M23     DB "LINES=$",0',
        'M24     DB "SYMS=$",0',
        'M25     DB "FIXUPS=$",0',
        'M26     DB "REFS=$",0',
        'M27     DB "TRUNC=YES",0',
        'M28     DB "TRUNC=NO",0',
        'M29     DB "USED",0',
        'M30     DB "UNUSED",0',
        'M31     DB "DEF=$",0',
        'M32     DB " REFS=$",0',
        'M33     DB " FIRST=$",0',
        'M34     DB "LOW=$",0',
        'M35     DB " UPPER=$",0',
        '',
        '        END'
    )

    $native = ConvertTo-CompactAsmNativeReport -Native $native -Org $Org
    Write-AsciiLines -Path $OutFile -Lines $native
}

if ($AsmNativeFlashOut) {
    New-AsmNativeReport -OutFile $AsmNativeFlashOut -Org '4800' -Header @(
        '; ASM-NATIVE SESSION REPORTER SNAPSHOT FOR FLASH ASM.',
        '; REBUILD/REINSTALL AFTER ASM-F2 CODE/MAP CHANGES.',
        '; KEEP THIS AT $4800 BEFORE THE SESSION YOU WANT TO INSPECT.',
        '; AFTER THAT SESSION, EXIT WITH ''.'' AND RUN G 4800.',
        '; PACKAGE $3000, THEN STORE WITH BANK0AP-PUT-TRANSIENT-2000.A.',
        '; LOAD FROM B0 BEFORE THE TARGET SESSION; DO NOT AP AFTER IT.'
    )
}

if ($AsmNativeRuntimeOut) {
    New-AsmNativeReport -OutFile $AsmNativeRuntimeOut -Org '7000' -Header @(
        '; ASM-SESSION-REPORT-TRANSIENT-7000.A',
        '; ASM-NATIVE SESSION REPORTER FOR RUNTIME-PASTE ASM.',
        '; FLASH ASM ALSO ALLOWS THIS AFTER LOW-TABLE RELOCATION.',
        '; USE THE $4800 FILE FOR A HIMON-LOADABLE BANK AP.',
        '; ASSEMBLE THIS BEFORE THE SESSION YOU WANT TO INSPECT.',
        '; THEN RUN ASM, EXIT WITH ''.'', AND RUN G 7000.'
    )
}
