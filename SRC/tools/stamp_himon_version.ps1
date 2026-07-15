param(
    [string]$OutPath,

    [string]$AsmOutPath,

    [string]$SourcePath,

    [string]$Stamp = (Get-Date -Format 'MMdd(HHmm)')
)

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

if (-not $OutPath -and -not $AsmOutPath -and -not $SourcePath) {
    throw "Specify -OutPath, -AsmOutPath, or -SourcePath"
}

Write-Host ("HIMON visible version   = {0}" -f $displayVersion)
if ($AsmOutPath) {
    Write-Host ("ASM-F2 visible version  = {0}" -f $asmDisplayVersion)
}
