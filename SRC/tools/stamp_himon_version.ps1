param(
    [string]$OutPath,

    [string]$SourcePath,

    [string]$Stamp = (Get-Date -Format 'MMdd(HHmm)')
)

$displayVersion = "HIMON V 00.$Stamp"
$sourceStamp = if ($Stamp.EndsWith(')')) { $Stamp.Substring(0, $Stamp.Length - 1) } else { $Stamp }
$sourceVersion = "HIMON V 00.$sourceStamp"

$line = 'MSG_HIMON_VERSION_TEXT:  DB              "' + $sourceVersion + '",('')''+$80)'

if ($OutPath) {
    $parent = Split-Path -Parent $OutPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($OutPath, $line + [Environment]::NewLine, [System.Text.Encoding]::ASCII)
}

if ($SourcePath) {
    $resolved = Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop
    $text = [System.IO.File]::ReadAllText($resolved)
    $pattern = 'MSG_HIMON_VERSION_TEXT:\s+DB\s+"HIMON V 00\.\d{4}\(\d{4}\)?",\(''\)''\+\$80\)'
    if ($text -notmatch $pattern) {
        throw "MSG_HIMON_VERSION_TEXT stamp target not found in $SourcePath"
    }
    $updated = [regex]::Replace($text, $pattern, $line, 1)
    if ($updated -ne $text) {
        [System.IO.File]::WriteAllText($resolved, $updated, [System.Text.Encoding]::ASCII)
    }
}

if (-not $OutPath -and -not $SourcePath) {
    throw "Specify -OutPath or -SourcePath"
}

Write-Host ("HIMON visible version   = {0}" -f $displayVersion)
