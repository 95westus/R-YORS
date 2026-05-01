param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [string]$OutDir,

    [string]$Stamp = (Get-Date -Format "yyyy-MM-ddTHH-mm")
)

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Source BIN not found: $SourcePath"
}

$safeStamp = $Stamp -replace ':','-'
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Split-Path -Parent $SourcePath
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$name = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
$ext = [System.IO.Path]::GetExtension($SourcePath)
$dest = Join-Path $OutDir ("{0}-{1}{2}" -f $name, $safeStamp, $ext)

Copy-Item -LiteralPath $SourcePath -Destination $dest -Force
Write-Host ("STAMP BIN                 = {0}" -f $dest)
