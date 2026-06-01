param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [string]$OutDir,

    [string]$Stamp = (Get-Date -Format "yyyy-MM-ddTHH:mmK")
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

$maxAttempts = 5
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        Copy-Item -LiteralPath $SourcePath -Destination $dest -Force -ErrorAction Stop
        break
    } catch [System.IO.IOException] {
        if ($attempt -eq $maxAttempts) {
            throw
        }
        Start-Sleep -Milliseconds (200 * $attempt)
    }
}
Write-Host ("STAMP BIN                 = {0}" -f $dest)
