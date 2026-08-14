param(
    [string]$OutPath,

    [string]$AsmOutPath,

    [string]$SourcePath,

    [string]$SvgPath,

    [string]$Stamp = (Get-Date -Format 'MMdd(HHmm)')
)

$mmddMatch = [regex]::Match($Stamp, '^(?<MMDD>\d{4})')
if (-not $mmddMatch.Success) {
    throw "Stamp must begin with MMDD: $Stamp"
}
$mmdd = $mmddMatch.Groups['MMDD'].Value
$displayVersion = "HIMON V 00.$Stamp"
$sourceStamp = if ($Stamp.EndsWith(')')) { $Stamp.Substring(0, $Stamp.Length - 1) } else { $Stamp }
$sourceVersion = "HIMON V 00.$sourceStamp"
$hashVersion = "HIMON: V 00.$sourceStamp"
$asmDisplayVersion = "ASM-F2 00.$Stamp"
$asmSourceVersion = "ASM-F2 00.$sourceStamp"

$lines = @(
    'MSG_HIMON_VERSION_TEXT:  DB              "' + $sourceVersion + '",('')''+$80)'
    'MSG_HIMON_VERSION_HASH_TEXT:'
    '                        DB              "' + $hashVersion + '",('')''+$80)'
)
$block = [string]::Join([Environment]::NewLine, $lines)

if ($OutPath) {
    $parent = Split-Path -Parent $OutPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($OutPath, $block + [Environment]::NewLine, [System.Text.Encoding]::ASCII)
}

if ($AsmOutPath) {
    $parent = Split-Path -Parent $AsmOutPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $asmLine = 'MSG_TITLE:              DB              "' + $asmSourceVersion + '",('')''+$80)'
    [System.IO.File]::WriteAllText($AsmOutPath, $asmLine + [Environment]::NewLine, [System.Text.Encoding]::ASCII)
}

if ($SourcePath) {
    $resolved = Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop
    $text = [System.IO.File]::ReadAllText($resolved)
    $pattern = 'MSG_HIMON_VERSION_TEXT:\s+DB\s+"HIMON V 00\.\d{4}\(\d{4}\)?",\(''\)''\+\$80\)(?:\r?\nMSG_HIMON_VERSION_HASH_TEXT:\r?\n\s+DB\s+"HIMON: V 00\.\d{4}\(\d{4}\)?",\(''\)''\+\$80\))?'
    if ($text -notmatch $pattern) {
        throw "MSG_HIMON_VERSION_TEXT stamp target not found in $SourcePath"
    }
    $updated = [regex]::Replace($text, $pattern, $block, 1)
    if ($updated -ne $text) {
        [System.IO.File]::WriteAllText($resolved, $updated, [System.Text.Encoding]::ASCII)
    }
}

if ($SvgPath) {
    $resolvedSvg = Resolve-Path -LiteralPath $SvgPath -ErrorAction Stop
    $svgText = [System.IO.File]::ReadAllText($resolvedSvg)
    $svgPattern = '(?s)(<text\b[^>]*\bid="ryors-version"[^>]*>)\s*VERSION\s+\.\d{4}\s*(</text>)'
    if ($svgText -notmatch $svgPattern) {
        throw "R-YORS SVG version target not found in $SvgPath"
    }
    $logoVersion = "VERSION .$mmdd"
    $updatedSvg = [regex]::Replace(
        $svgText,
        $svgPattern,
        { param($match) $match.Groups[1].Value + $logoVersion + $match.Groups[2].Value },
        1
    )
    if ($updatedSvg -ne $svgText) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($resolvedSvg, $updatedSvg, $utf8NoBom)
    }
}

if (-not $OutPath -and -not $AsmOutPath -and -not $SourcePath -and -not $SvgPath) {
    throw "Specify -OutPath, -AsmOutPath, -SourcePath, or -SvgPath"
}

if ($OutPath -or $SourcePath) {
    Write-Host ("HIMON visible version   = {0}" -f $displayVersion)
}
if ($AsmOutPath) {
    Write-Host ("ASM-F2 visible version  = {0}" -f $asmDisplayVersion)
}
if ($SvgPath) {
    Write-Host ("R-YORS logo version     = VERSION .{0}" -f $mmdd)
}
