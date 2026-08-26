param(
  [Parameter(Mandatory = $true)][string]$SourcePath,
  [Parameter(Mandatory = $true)][string]$OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$source = (Resolve-Path -LiteralPath $SourcePath).Path
$lines = Get-Content -LiteralPath $source
$begin = [Array]::IndexOf($lines, "; BEGIN GENERATED STR8 MUTATION WORKER")
$end = [Array]::IndexOf($lines, "; END GENERATED STR8 MUTATION WORKER")
if ($begin -lt 0 -or $end -le $begin) {
  throw "STR8 mutation-worker markers not found in $source"
}

$db = @($lines[($begin + 1)..($end - 1)] | Where-Object {
  $_ -match '^\s*DB\s+' -or $_ -match '^\s+DB\s+'
})
if ($db.Count -eq 0) {
  throw "no worker DB rows found in $source"
}

$output = @(
  "; Generated from $source. Do not edit this BUILD file."
  "APMAN_WORKER_IMAGE:"
) + $db + @(
  "APMAN_WORKER_IMAGE_END:"
  "APMAN_WORKER_SIZE EQU APMAN_WORKER_IMAGE_END-APMAN_WORKER_IMAGE"
)

$parent = Split-Path -Parent $OutPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$text = ($output -join "`r`n") + "`r`n"
if ((Test-Path -LiteralPath $OutPath) -and ((Get-Content -LiteralPath $OutPath -Raw) -eq $text)) {
  Write-Host "APMAN worker include unchanged: $OutPath"
  exit 0
}
[System.IO.File]::WriteAllText($OutPath, $text, [System.Text.Encoding]::ASCII)
Write-Host "APMAN worker include updated: $OutPath"
